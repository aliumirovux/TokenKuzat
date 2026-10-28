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

    public var toolsLine: String {
        topTools.prefix(3).map { "\($0.name) \($0.count)" }.joined(separator: " · ")
    }
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
