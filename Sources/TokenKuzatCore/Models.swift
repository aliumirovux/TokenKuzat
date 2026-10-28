import Foundation

public enum AgentState: Int, Comparable, Sendable {
    case idle = 0, waiting = 1, running = 2

    public static func < (a: AgentState, b: AgentState) -> Bool { a.rawValue < b.rawValue }

    public var title: String {
        switch self {
        case .running: return "Ishlayapti"
        case .waiting: return "Asbob natijasini kutyapti"
        case .idle: return "Tugagan / tinch"
        }
    }
}

public struct AgentSnap: Identifiable, Sendable {
    public let id: String
    public let title: String
    /// Asosiy agentda — model, yordamchida — agent turi (Explore, Plan…)
    public let subtitle: String
    public let kind: String
    public let isMain: Bool
    public let tokens: TokenCounts
    public let calls: Int
    public let topTools: [(name: String, count: Int)]
    public let lastAction: String
    public let state: AgentState
    public let lastActivity: Date?
    public let firstActivity: Date?
    /// Asbob chaqiruvlari, eskidan yangiga (oxirgi 80 tasi)
    public let steps: [StepSnap]
    /// Agent nimalarga kirdi — tur bo'yicha guruhlangan, eng so'nggi faol guruh birinchi
    public let resources: [ResourceGroup]

    public var toolsLine: String {
        topTools.prefix(3).map { "\($0.name) \($0.count)" }.joined(separator: " · ")
    }
}

public enum StepStatus: Sendable {
    case running, done, failed
}

/// Bitta asbob chaqiruvi: qachon boshlandi, qancha davom etdi, natijasi
public struct StepSnap: Identifiable, Sendable {
    public let id: String
    public let date: Date
    public let symbol: String
    public let text: String
    public let category: ToolCategory
    public let targetName: String
    public let access: ToolAccess
    public let duration: TimeInterval?
    public let status: StepStatus
    /// Qaysi so'rov ichida bajarilgan (`TurnSnap.id`); birinchi so'rovdan oldingi qadamlar — nil
    public let turn: Int?
}

/// Bitta so'rov va unga javob jarayoni: siz yozgan paytdan keyingi so'rovgacha
public struct TurnSnap: Identifiable, Sendable {
    /// 1 dan boshlanadigan tartib raqami
    public let id: Int
    public let prompt: String
    public let start: Date
    /// Oxirgi harakat vaqti
    public let end: Date
    public let tokens: TokenCounts
    public let steps: Int
    public let errors: Int
    /// Hozir shu so'rov ustida ishlanyapti
    public let active: Bool

    public var duration: TimeInterval { max(0, end.timeIntervalSince(start)) }
}

public struct ResourceItem: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let detail: String
    public let calls: Int
    public let reads: Int
    public let writes: Int
    public let errors: Int
    public let lastActivity: Date?
}

public struct ResourceGroup: Identifiable, Sendable {
    public var id: String { category.rawValue }
    public let category: ToolCategory
    public let calls: Int
    public let errors: Int
    public let lastActivity: Date?
    /// Eng so'nggi ishlatilgani birinchi
    public let items: [ResourceItem]
    /// Hozir shu yerda biror qadam bajarilyapti
    public let busy: Bool
}

public struct SessionSnap: Identifiable, Sendable {
    public let id: String
    public let project: String
    public let title: String
    public let model: String
    public let contextTokens: Int
    public let tokens: TokenCounts
    public let mainTokens: TokenCounts
    public let agentTokens: TokenCounts
    public let agents: [AgentSnap]
    public let lastActivity: Date?
    public let state: AgentState
    /// So'rovlar, eskidan yangiga
    public let turns: [TurnSnap]

    public var main: AgentSnap? { agents.first(where: \.isMain) }
    public var helperCount: Int { agents.filter { !$0.isMain }.count }
}

public struct MinutePoint: Identifiable, Sendable {
    public let id: Int
    public let date: Date
    public let main: TokenCounts
    public let agents: TokenCounts
}

public struct DayPoint: Identifiable, Sendable {
    public var id: Date { date }
    public let date: Date
    public let tokens: TokenCounts
}

public struct FeedEvent: Identifiable, Sendable {
    public let id: String
    public let date: Date
    public let sessionId: String
    public let project: String
    public let agentTitle: String
    public let isMain: Bool
    public let symbol: String
    public let text: String
}

public struct SourceInfo: Identifiable, Sendable {
    public var id: String { path }
    public let path: String
    public let exists: Bool
    public var total = 0
    public var today = 0
    public var recent = 0
    public var lines = 0
    public var usage = 0
    public var latest: Date?
}

public struct Snapshot: Sendable {
    public var sessions: [SessionSnap] = []
    public var today = TokenCounts()
    /// Oxirgi 5 soat — Claude obunasi limiti shu oyna bo'yicha hisoblanadi
    public var lastFiveHours = TokenCounts()
    public var minutes: [MinutePoint] = []
    /// Eskidan yangiga, bugun — oxirgisi
    public var days: [DayPoint] = []
    public var feed: [FeedEvent] = []
    public var rateRaw: Double = 0
    public var rateWeighted: Double = 0
    public var runningAgents = 0
    public var activeSessions = 0
    public var filesWatched = 0
    public var sources: [SourceInfo] = []
    public var updatedAt = Date()
    public var initialScanDone = false

    public init() {}

    public func rate(_ mode: CountMode) -> Double { mode == .weighted ? rateWeighted : rateRaw }
}
