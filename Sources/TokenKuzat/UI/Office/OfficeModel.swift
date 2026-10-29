import Foundation
import TokenKuzatCore

// «Ofis» ma'lumoti: xona = loyiha, robot = agent. Har bir ko'rinish haqiqiy holatdan keladi —
// sahnada bo'lmayotgan narsa ko'rsatilmaydi.

enum OfficeState: Int, Comparable {
    /// Tartib — e'tibor navbati: kutayotgan birinchi, uxlayotgan oxirida
    case waiting = 0, error, working, thinking, idle, sleeping
    static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }

    var busy: Bool { self == .working || self == .thinking }
    /// Stolda o'tiradi (kutayotgani turib qo'l silkitadi)
    var atDesk: Bool { self == .working || self == .thinking || self == .error }

    var title: String {
        switch self {
        case .waiting: return tr("Ruxsat kutyapti", "Waiting for permission")
        case .error: return tr("Xato", "Error")
        case .working: return tr("Ishlayapti", "Working")
        case .thinking: return tr("O'ylayapti", "Thinking")
        case .idle: return tr("Bo'sh", "Idle")
        case .sleeping: return tr("Uxlayapti", "Sleeping")
        }
    }
}

/// Monitorda ko'rinadigan asbob belgisi
enum OfficeTool: Equatable {
    case terminal, file, web, plug, agent, wrench

    init(_ c: ToolCategory) {
        switch c {
        case .shell: self = .terminal
        case .files: self = .file
        case .web: self = .web
        case .mcp: self = .plug
        case .agent: self = .agent
        case .other: self = .wrench
        }
    }
}

struct OfficeAgent: Identifiable, Equatable {
    /// sessiya/agent — sessiyalar orasida takrorlanmaydi
    let id: String
    let sessionId: String
    let name: String
    let isMain: Bool
    let state: OfficeState
    let tool: OfficeTool?
    let what: String
    let last: Date?
}

struct OfficeRoom: Identifiable, Equatable {
    /// Loyiha nomi
    let id: String
    let sessions: Int
    let tokens: Int
    let agents: [OfficeAgent]

    var state: OfficeState { agents.map(\.state).min() ?? .sleeping }

    /// Xona yorlig'idagi holat
    var status: String {
        let s = agents.map(\.state)
        if s.contains(.waiting) { return tr("Sizni kutyapti", "Waiting for you") }
        if s.contains(.error) { return tr("Xato", "Error") }
        let busy = s.filter(\.busy).count
        if busy > 0 { return tr("\(busy) ishlayapti", busy == 1 ? "1 working" : "\(busy) working") }
        if s.allSatisfy({ $0 == .sleeping }) { return tr("Uxlayapti", "Sleeping") }
        return tr("Dam olyapti", "Resting")
    }
}

enum OfficeModel {
    /// Xonalar soni — bino 6 joyli
    static let slots = 6
    /// Bir xonada ko'pi bilan shuncha robot (2 stol, divanda 2 joy)
    static let perRoom = 4
    /// Shundan uzoq tinch turgan agent uxlaydi
    static let sleepAfter: TimeInterval = 30 * 60
    /// Tugagan yordamchi shuncha vaqt xonada qoladi
    static let helperStays: TimeInterval = 10 * 60
    /// Bugungi kun ichida faol bo'lgan loyihalar ofisda
    static let roomStays: TimeInterval = 24 * 3600

    static func rooms(_ snap: Snapshot) -> [OfficeRoom] {
        let now = snap.updatedAt
        let recent = snap.sessions.filter { s in
            s.state != .idle || snap.permissionWaits[s.id] != nil
                || (s.lastActivity.map { now.timeIntervalSince($0) < roomStays } ?? false)
        }
        let rooms = Dictionary(grouping: recent, by: \.project).map { project, sessions -> OfficeRoom in
            let agents = sessions.flatMap { agents(of: $0, notice: snap.permissionWaits[$0.id], now: now) }
                .sorted { ($0.state, $0.isMain ? 0 : 1, -($0.last?.timeIntervalSince1970 ?? 0))
                    < ($1.state, $1.isMain ? 0 : 1, -($1.last?.timeIntervalSince1970 ?? 0)) }
            return OfficeRoom(id: project, sessions: sessions.count,
                              tokens: sessions.reduce(0) { $0 + $1.tokens.total },
                              agents: Array(agents.prefix(perRoom)))
        }
        return rooms
            .sorted { ($0.state, -(latest($0)?.timeIntervalSince1970 ?? 0)) < ($1.state, -(latest($1)?.timeIntervalSince1970 ?? 0)) }
            .prefix(slots).map { $0 }
    }

    private static func latest(_ r: OfficeRoom) -> Date? { r.agents.compactMap(\.last).max() }

    /// Sessiyaning asosiy agenti va hozir ishlayotgan yoki yaqinda tugagan yordamchilari
    private static func agents(of s: SessionSnap, notice: HookNotice?, now: Date) -> [OfficeAgent] {
        s.agents.compactMap { a in
            if !a.isMain && a.state == .idle && !(a.lastActivity.map { now.timeIntervalSince($0) < helperStays } ?? false) { return nil }
            let st = state(of: a, waiting: a.isMain && notice != nil, now: now)
            let running = a.steps.last(where: { $0.status == .running })
            let what: String = {
                if a.isMain, let notice, !notice.message.isEmpty { return notice.message }
                return a.lastAction
            }()
            return OfficeAgent(id: "\(s.id)/\(a.id)", sessionId: s.id, name: a.isMain ? tr("Asosiy agent", "Main agent") : a.title,
                               isMain: a.isMain, state: st, tool: running.map { OfficeTool($0.category) },
                               what: what, last: a.lastActivity)
        }
    }

    static func state(of a: AgentSnap, waiting: Bool, now: Date) -> OfficeState {
        if waiting { return .waiting }
        if a.steps.contains(where: { $0.status == .running }) { return .working }
        if a.state != .idle {
            // Xato bo'lgan qadamdan keyin bir oz — o'girilib boshini qashiydi
            if let last = a.steps.max(by: { $0.date < $1.date }), last.status == .failed, now.timeIntervalSince(last.date) < 20 {
                return .error
            }
            return .thinking
        }
        guard let la = a.lastActivity else { return .sleeping }
        return now.timeIntervalSince(la) < sleepAfter ? .idle : .sleeping
    }
}
