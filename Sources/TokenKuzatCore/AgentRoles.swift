import Foundation

/// Agent turlari: bosh agent (rahbar) ishni rejalaydi va tekshiradi, og'ir o'qishni yordamchilarga beradi.
/// Token Kuzatuv plagini `izlovchi`, `bajaruvchi`, `tekshiruvchi`, `sinovchi` agentlarini o'rnatadi; Claude Code'ning o'z turlari ham tanildi
public enum AgentRole: String, CaseIterable, Sendable {
    case lead, explorer, builder, reviewer, tester, other

    public var title: String {
        switch self {
        case .lead: return tr("Rahbar", "Lead")
        case .explorer: return tr("Izlovchi", "Explorer")
        case .builder: return tr("Bajaruvchi", "Builder")
        case .reviewer: return tr("Tekshiruvchi", "Reviewer")
        case .tester: return tr("Sinovchi", "Tester")
        case .other: return tr("Boshqa yordamchi", "Other helpers")
        }
    }

    /// `kind` — Claude Code yozuvidagi agentType («Explore», «tokenkuzat:izlovchi» …)
    public static func of(_ a: AgentSnap) -> AgentRole {
        if a.isMain { return .lead }
        let k = a.kind.lowercased()
        let name = k.split(separator: ":").last.map(String.init) ?? k
        if name == "izlovchi" || name == "explore" || name.contains("search") { return .explorer }
        if name == "bajaruvchi" { return .builder }
        if name == "sinovchi" || name == "qa" || name.contains("test") { return .tester }
        if name == "tekshiruvchi" || name.contains("review") || name.contains("verif") { return .reviewer }
        return .other
    }

    /// Rahbar o'zi shuncha faylni o'qisa (yordamchisiz) — izlash ishini izlovchiga berish mumkin edi
    public static let heavyLeadReads = 30
}

public enum AgentRoleUsage {
    public struct Row: Sendable {
        public let role: AgentRole
        public var tokens = TokenCounts()
        public var agents = 0
        public var calls = 0
    }

    public struct Summary: Sendable {
        public var rows: [Row] = []
        /// Rahbar ko'p faylni o'zi o'qigan va yordamchi ishlatmagan sessiyalar
        public var heavyLeadSessions = 0
        public var sessions = 0
        public var helpersUsed: Bool { rows.contains { $0.role != .lead && $0.agents > 0 } }
    }

    public static func summary(_ sessions: [SessionSnap], since: Date) -> Summary {
        var rows = Dictionary(uniqueKeysWithValues: AgentRole.allCases.map { ($0, Row(role: $0)) })
        var out = Summary()
        for s in sessions where (s.lastActivity ?? .distantPast) >= since {
            out.sessions += 1
            for a in s.agents {
                let r = AgentRole.of(a)
                var row = rows[r] ?? Row(role: r)
                row.tokens = row.tokens + a.tokens
                row.agents += 1
                row.calls += a.calls
                rows[r] = row
            }
            let reads = s.main?.topTools.first { $0.name == "Read" }?.count ?? 0
            if reads >= AgentRole.heavyLeadReads, s.helperCount == 0 { out.heavyLeadSessions += 1 }
        }
        out.rows = AgentRole.allCases.compactMap { rows[$0] }.filter { $0.agents > 0 }
        return out
    }
}
