import Foundation

public enum AgentState: Int, Comparable, Sendable {
    case idle = 0, waiting = 1, running = 2

    public static func < (a: AgentState, b: AgentState) -> Bool { a.rawValue < b.rawValue }

    public var title: String {
        switch self {
        case .running: return tr("Ishlayapti", "Working")
        case .waiting: return tr("Asbob natijasini kutyapti", "Waiting for tool result")
        case .idle: return tr("Tugagan / tinch", "Done / idle")
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
    /// Har bir sanalgan javob: vaqti va tokenlari (replay uchun), eskidan yangiga
    public let usage: [UsagePoint]
    /// Kontekstga tushgan katta asbob natijalari (≥ `BigResult.threshold`), eskidan yangiga
    public var bigResults: [BigResult] = []
    /// Terminal buyruqlarida tilga olingan rasm/HTML/PDF yo'llari → oxirgi marta («Natijalar»)
    public var outputs: [String: Date] = [:]
    /// Birinchi chaqiruvdagi kontekst. `usage` uzun sessiyada boshidan kesiladi — bu qiymat saqlanib qoladi
    public var startContext: Int?
    /// O'qish/qidirish chaqiruvlari soni: Read, Grep, Glob va Bash orqali cat/grep/sed -n… (`ReadCounter`)
    public var reads: Int = 0

    public var toolsLine: String {
        topTools.prefix(3).map { "\($0.name) \($0.count)" }.joined(separator: " · ")
    }
}

public struct UsagePoint: Sendable {
    public let date: Date
    public let tokens: TokenCounts
    /// Kesh muddati: true — 1 soat, false — 5 daqiqa, nil — bu javobda kesh yozilmagan
    public var longCache: Bool? = nil

    /// Shu chaqiruvda o'qilgan butun kontekst
    public var context: Int { tokens.input + tokens.cacheRead + tokens.cacheWrite }
}

/// Katta asbob natijasi: sessiya oxirigacha (yoki /compact gacha) kontekstda qoladi va har chaqiruvda qayta o'qiladi
public struct BigResult: Sendable {
    public static let threshold = 5_000
    public let date: Date
    public let tokens: Int
    /// Qadam matni («O'qiyapti · GraphScreen.swift»)
    public let label: String
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
    /// Nishonning to'liq kaliti («files|/to'liq/yo'l», «shell|git» …)
    public let targetKey: String
    /// Nishon tafsiloti (fayl uchun — papka)
    public let targetDetail: String
    public let access: ToolAccess
    public let duration: TimeInterval?
    public let status: StepStatus
    /// Qaysi so'rov ichida bajarilgan (`TurnSnap.id`); birinchi so'rovdan oldingi qadamlar — nil
    public let turn: Int?
    /// Asbobga berilgan parametrlar (JSON) va natija matnining boshi — sessiyaning oxirgi qadamlari uchun saqlanadi
    public var input: String? = nil
    public var output: String? = nil
    /// Natija kontekstga qo'shgan taxminiy token (keyingi har chaqiruvda qayta o'qiladi)
    public var resultTokens: Int? = nil
}

/// Claude'ning o'ylashi yoki yozgan javobi — xaritadagi qadamlar zanjirida ko'rsatiladi
public struct NoteSnap: Identifiable, Sendable {
    public enum Kind: Sendable { case thinking, reply }
    public let id: String
    public let date: Date
    public let kind: Kind
    /// O'ylash shifrlangan bo'lsa — bo'sh
    public let text: String
    /// O'ylash qancha davom etgani (oldingi hodisadan beri, taxminiy)
    public let duration: TimeInterval?
    public let turn: Int?
    /// Yordamchi agent nomi (asosiy agentda nil)
    public let agent: String?

    public init(id: String, date: Date, kind: Kind, text: String, duration: TimeInterval?, turn: Int?, agent: String?) {
        self.id = id
        self.date = date
        self.kind = kind
        self.text = text
        self.duration = duration
        self.turn = turn
        self.agent = agent
    }
}

/// Bitta so'rov va unga javob jarayoni: siz yozgan paytdan keyingi so'rovgacha
public struct TurnSnap: Identifiable, Sendable {
    /// 1 dan boshlanadigan tartib raqami
    public let id: Int
    /// Birinchi qatori (ko'pi bilan 160 belgi) — ro'yxat va sarlavhalar uchun
    public let prompt: String
    /// To'liq matni (ko'pi bilan `TurnSnap.textLimit` belgi) — ko'chirish xulosasi uchun
    public let text: String
    public static let textLimit = 2000
    public let start: Date
    /// Oxirgi harakat vaqti
    public let end: Date
    public let tokens: TokenCounts
    public let steps: Int
    public let errors: Int
    /// Hozir shu so'rov ustida ishlanyapti
    public let active: Bool
    /// So'rov ichida qaysi asbob turlari ishlatildi (barcha qadamlar bo'yicha, ko'pidan oziga)
    public var tools: [TurnTool] = []
    /// So'rov ichida ishlagan yordamchi agentlar
    public var helpers: [String] = []
    /// Suhbat qisqartirilgan joy (`isContinuation` so'rovida): qancha kontekst qancha bo'ldi
    public var compaction: Compaction? = nil

    public init(id: Int, prompt: String, text: String? = nil, start: Date, end: Date, tokens: TokenCounts, steps: Int, errors: Int,
                active: Bool, tools: [TurnTool] = [], helpers: [String] = [], compaction: Compaction? = nil) {
        self.id = id
        self.prompt = prompt
        self.text = text ?? prompt
        self.start = start
        self.end = end
        self.tokens = tokens
        self.steps = steps
        self.errors = errors
        self.active = active
        self.tools = tools
        self.helpers = helpers
        self.compaction = compaction
    }

    public var duration: TimeInterval { max(0, end.timeIntervalSince(start)) }

    /// Kontekst tugab, suhbat xulosa bilan davom ettirilgan joy — bu foydalanuvchi so'rovi emas
    public var isContinuation: Bool { TurnSnap.isContinuation(prompt) }

    public static func isContinuation(_ prompt: String) -> Bool {
        prompt.hasPrefix("This session is being continued from a previous conversation")
    }
}

/// Claude Code suhbatni qisqartirgani (transkriptdagi «compact_boundary»)
public struct Compaction: Equatable, Sendable {
    public let date: Date
    /// true — kontekst to'lib, Claude Code o'zi qisqartirdi; false — /compact
    public let auto: Bool
    public let before: Int
    public let after: Int

    public init(date: Date, auto: Bool, before: Int, after: Int) {
        self.date = date
        self.auto = auto
        self.before = before
        self.after = after
    }

    /// «968K → 36K»
    public var change: String { Fmt.tokens(before) + " → " + Fmt.tokens(after) }
}

/// So'rov ichidagi bitta asbob turi: nechta chaqiruv, xato va eng ko'p ishlatilgan nishon
public struct TurnTool: Identifiable, Sendable {
    public var id: String { category.rawValue }
    public let category: ToolCategory
    public let calls: Int
    public let errors: Int
    public let top: String
    /// Hozir shu turda qadam bajarilyapti
    public let busy: Bool

    public init(category: ToolCategory, calls: Int, errors: Int, top: String, busy: Bool) {
        self.category = category
        self.calls = calls
        self.errors = errors
        self.top = top
        self.busy = busy
    }
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
    /// Kontekst oynasi hajmi: 200K yoki (sessiyada 200K dan oshgan bo'lsa) 1M
    public var contextWindow: Int = 200_000
    /// O'ylash va javob matnlari, eskidan yangiga (oxirgi 400 tasi)
    public var notes: [NoteSnap] = []
    /// Ish papkasi (oxirgi ko'ringani)
    public var cwd: String? = nil
    /// Asosiy agent Claude modelida ishlaydi (yo'q — bepul model, FreeLLMAPI orqali: Claude limitiga kirmaydi)
    public var isClaude = true
    /// Asosiy agent javobni tugatgan: oxirgi qadam asbob chaqiruvi, asbob natijasi yoki yangi so'rov emas
    public var turnEnded = true
    /// Qayerda ochilgan: «cli» (Terminal), «claude-desktop» (Claude ilovasi), «sdk-cli» (dastur ichidan) …
    public var origin: String? = nil

    public var main: AgentSnap? { agents.first(where: \.isMain) }
    /// Kontekst qanchalik to'lgan (0…1)
    public var contextFraction: Double { contextWindow > 0 ? min(1, Double(contextTokens) / Double(contextWindow)) : 0 }
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

extension Snapshot {
    /// Status line bergan haqiqiy kontekst oynasi — transkriptdagi eng katta kontekstdan qilingan taxmin o'rniga
    /// (1M modelda kontekst hali 200K dan oshmagan bo'lsa ham to'g'ri foiz chiqadi)
    public mutating func applyContextWindows(_ windows: [String: Int]) {
        for i in sessions.indices {
            if let w = windows[sessions[i].id], w > 0 { sessions[i].contextWindow = w }
        }
    }
}

public struct Snapshot: Sendable {
    public var sessions: [SessionSnap] = []
    public var today = TokenCounts()
    /// Oxirgi 5 soat — Claude obunasi limiti shu oyna bo'yicha hisoblanadi
    public var lastFiveHours = TokenCounts()
    public var minutes: [MinutePoint] = []
    /// Oxirgi 6 soat daqiqama-daqiqa (360 ta, eskidan yangiga) — limit oynasini soatma-soat ko'rsatish uchun
    public var recentMinutes: [MinutePoint] = []
    /// Bugun soat bo'yicha (24 ta, 00:00 dan)
    public var todayHours: [TokenCounts] = Array(repeating: TokenCounts(), count: 24)
    /// Bugun token sarflangan daqiqalar soni (faol vaqt)
    public var activeMinutesToday = 0
    /// Bugun birinchi faollik vaqti
    public var firstActivityToday: Date?
    /// Eskidan yangiga, bugun — oxirgisi
    public var days: [DayPoint] = []
    public var feed: [FeedEvent] = []
    public var rateRaw: Double = 0
    public var rateWeighted: Double = 0
    public var runningAgents = 0
    public var activeSessions = 0
    /// Hozir ishlayotgan (kamida bitta agenti ishlayotgan) sessiyalar — «N sessiya ishlayapti» shu son
    public var runningSessions = 0
    public var filesWatched = 0
    public var sources: [SourceInfo] = []
    public var updatedAt = Date()
    public var initialScanDone = false
    /// Claude Code status line'dan kelgan haqiqiy limitlar (ulangan bo'lsa)
    public var limits: RateLimits?
    public var fiveHourForecast: LimitForecast.Outcome = .unknown
    /// Haftalik oyna: shu sur'atda tiklanishdan oldin tugaydimi
    public var weekForecast: LimitForecast.Outcome = .unknown
    /// Limitning Mac'dan tashqariga (chat, bulut) ketgan qismi — hisob limiti ulangan bo'lsa
    public var outside: OutsideUsage?
    /// Ruxsatingizni kutayotgan sessiyalar (Claude Code hook'idan): sessiya id → xabar
    public var permissionWaits: [String: HookNotice] = [:]
    /// Javobi API xatosi bilan uzilgan sessiyalar (StopFailure), xatodan keyin hali harakat yo'q
    public var failures: [String: HookNotice] = [:]

    public init() {}

    public func rate(_ mode: CountMode) -> Double { mode == .weighted ? rateWeighted : rateRaw }
}
