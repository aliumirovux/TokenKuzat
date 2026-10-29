import Foundation

// «Loyihalar»: har loyiha (papka) — bitta karta. Oxirgi sessiyadan ish nomi, qolgan ish va javobsiz savol,
// loyiha git'idan saqlanmagan/yuborilmagan o'zgarishlar. Hammasi sessiya yozuvlari va git'dan — Claude'ga token sarflanmaydi.

public struct ProjectGit: Equatable, Sendable {
    /// Commit qilinmagan fayllar
    public var dirty: Int
    /// Yuborilmagan commit'lar (upstream bo'lmasa — nil)
    public var ahead: Int?

    public init(dirty: Int, ahead: Int?) {
        self.dirty = dirty
        self.ahead = ahead
    }
}

public struct ProjectCard: Identifiable, Equatable, Sendable {
    public var id: String { folder }
    public let folder: String
    public let name: String
    /// Loyihadagi eng oxirgi sessiya
    public let sessionId: String
    public let lastActivity: Date
    /// Qayerda ochilgan: «cli» (Terminal), «claude-desktop» (Claude ilovasi) va h.k.
    public let origin: String?
    public let task: String?
    /// Claude'ning ko'chirish eslatmasidagi «Qolgan» (eslatma bo'lmasa — nil)
    public let remaining: String?
    /// Oxirgi javobda foydalanuvchiga berilgan va javobsiz qolgan savol
    public let question: String?
    public let running: Bool
    /// Shu davrdagi sessiyalar soni
    public let sessions: Int
    public var git: ProjectGit?

    public enum Status: Int, Comparable, Sendable {
        case running, waiting, unsaved, calm
        public static func < (a: Status, b: Status) -> Bool { a.rawValue < b.rawValue }
    }

    public var status: Status {
        if running { return .running }
        if question != nil { return .waiting }
        if let g = git, g.dirty > 0 || (g.ahead ?? 0) > 0 { return .unsaved }
        return .calm
    }

    public var isTerminal: Bool { origin == "cli" }
}

public enum ProjectBoard {
    /// Ichki ishlar uchun ochilgan sessiyalar (`claude -p`, SDK) — foydalanuvchi ishi emas
    public static func isUserSession(_ s: SessionSnap) -> Bool {
        !(s.origin ?? "").hasPrefix("sdk") && !s.turns.isEmpty
    }

    /// Kartalar, eng oxirgi ishlangan loyiha tepada. `folder` — sessiyaning loyiha papkasi (nil — tashlab ketiladi)
    public static func cards(_ sessions: [SessionSnap],
                             folder: (SessionSnap) -> String? = { SavingsAdvisor.projectFolder(for: $0) }) -> [ProjectCard] {
        var groups: [String: [SessionSnap]] = [:]
        for s in sessions where isUserSession(s) && s.lastActivity != nil {
            // Vaqtinchalik papkalar (/tmp, scratchpad) — loyiha emas
            guard let f = folder(s), !SavingsAdvisor.isTemporary(f + "/") else { continue }
            groups[URL(fileURLWithPath: f).standardizedFileURL.path, default: []].append(s)
        }
        return groups.compactMap { dir, list -> ProjectCard? in
            guard let s = list.max(by: { ($0.lastActivity ?? .distantPast) < ($1.lastActivity ?? .distantPast) }),
                  let la = s.lastActivity else { return nil }
            let note = SavingsAdvisor.handoffNote(s)?.note
            return ProjectCard(folder: dir, name: URL(fileURLWithPath: dir).lastPathComponent, sessionId: s.id,
                               lastActivity: la, origin: s.origin, task: SavingsAdvisor.handoffTask(s, note: note),
                               remaining: note.flatMap { HandoffNote.field($0, ["Qolgan", "Remaining"]) }.flatMap(nonEmpty),
                               question: SavingsAdvisor.pendingQuestion(s), running: s.state != .idle,
                               sessions: list.count, git: nil)
        }
        .sorted { $0.lastActivity > $1.lastActivity }
    }

    /// «yo'q» / «none» — bo'sh
    static func nonEmpty(_ v: String) -> String? {
        let l = v.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: " .—-"))
        return ["yo'q", "yoq", "none", "no", "-"].contains(l) ? nil : v
    }

    /// Papkaning git holati (git repo bo'lmasa — nil). Sekin bo'lishi mumkin — asosiy oqimda chaqirilmasin
    public static func git(_ folder: String) -> ProjectGit? {
        guard let status = GitState.git(folder, ["status", "--porcelain"]) else { return nil }
        let dirty = status.split(separator: "\n").count
        let ahead = GitState.git(folder, ["rev-list", "--count", "@{u}..HEAD"]).flatMap { Int($0) }
        return ProjectGit(dirty: dirty, ahead: ahead)
    }
}

// MARK: - Avtomatik davom

// Terminal yopilib, shu papkada keyin yangi `claude` ochilsa — oldingi sessiya xulosasi SessionStart hook orqali
// o'zi beriladi. Ilova har loyihaning oxirgi sessiyasi uchun xulosani resume/ papkasiga yozib boradi, hook o'qiydi.
public enum ResumeStore {
    /// Shundan eski sessiya davom ettirilmaydi
    public static let lifetime: TimeInterval = 24 * 3600

    public static var directory: URL {
        RateLimitsReader.defaultDirectory.deletingLastPathComponent().appendingPathComponent("resume")
    }

    /// Papka yo'li → fayl nomi (Claude Code'ning loyiha papkalari kabi: «/» va «.» → «-»)
    public static func key(_ folder: String) -> String {
        URL(fileURLWithPath: folder).standardizedFileURL.path
            .map { $0.isLetter || $0.isNumber ? String($0) : "-" }.joined() + ".json"
    }

    public static func url(for folder: String, in dir: URL = directory) -> URL {
        dir.appendingPathComponent(key(folder))
    }

    /// `created` — oldingi sessiyaning oxirgi harakati
    public static func save(_ h: PendingHandoff, in dir: URL = directory) throws {
        guard let folder = h.cwd else { return }
        try HandoffStore.arm(h, at: url(for: folder, in: dir))
    }

    public static func load(folder: String, in dir: URL = directory) -> PendingHandoff? {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .secondsSince1970
        guard let d = try? Data(contentsOf: url(for: folder, in: dir)) else { return nil }
        return try? dec.decode(PendingHandoff.self, from: d)
    }

    /// Muddati o'tgan (yoki `keep` da yo'q papkalarning) xulosalarini o'chiradi
    public static func prune(keep: Set<String>? = nil, in dir: URL = directory, now: Date = Date()) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        let keys = keep.map { Set($0.map(key)) }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .secondsSince1970
        for f in files {
            let h = (try? Data(contentsOf: f)).flatMap { try? dec.decode(PendingHandoff.self, from: $0) }
            if h == nil || now.timeIntervalSince(h!.created) >= lifetime || keys.map({ !$0.contains(f.lastPathComponent) }) == true {
                try? fm.removeItem(at: f)
            }
        }
    }

    /// Ilova o'zi xulosa bilan ochgan sessiyada shu o'zgaruvchi bor — hook avtomatik xulosani qo'shmaydi
    public static let skipVariable = "TOKENKUZAT_NO_RESUME"

    public static func remove(folder: String, in dir: URL = directory) {
        try? FileManager.default.removeItem(at: url(for: folder, in: dir))
    }

    public static func clear(in dir: URL = directory) {
        try? FileManager.default.removeItem(at: dir)
    }

    /// Faqat yangi ochilgan sessiya (`/clear`, davom ettirilgan yoki qisqartirilgan emas), boshqa sessiya, muddati o'tmagan
    public static func shouldDeliver(_ h: PendingHandoff, sessionId: String, source: String?, now: Date) -> Bool {
        (source == nil || source == "startup") && sessionId != h.sourceSession && now.timeIntervalSince(h.created) < lifetime
    }

    public static func context(for h: PendingHandoff, now: Date = Date()) -> String {
        Lang.with(english: h.english ?? Lang.isEnglish) {
            let ago = Fmt.ago(h.created, now: now)
            return tr("Token Kuzatuv: shu papkadagi oldingi Claude Code sessiyasi \(ago) to'xtagan (oyna yopilgan yoki tashlab ketilgan). "
               + "Quyidagi xulosa — o'sha sessiyadan. Foydalanuvchining birinchi xabari shu ishni davom ettirish, holatni so'rash "
               + "yoki salomlashish bo'lsa — javobing boshida 1–2 jumlada qayerda qolganini ayt (nima qilindi, nima qoldi, "
               + "sizdan nima kutilyapti), keyin xabariga javob ber. O'zing hech narsa boshlama. Boshqa mavzu bo'lsa — xulosani "
               + "e'tiborsiz qoldir va u haqida gapirma.",
               "Token Kuzatuv: the previous Claude Code session in this folder stopped \(ago) (window closed or left). "
               + "The summary below is from that session. If the user's first message continues that work, asks for the status "
               + "or is a greeting — open your reply with 1–2 sentences on where things stopped (what was done, what's left, "
               + "what's pending from the user), then answer. Don't start anything on your own. If it's a different topic, "
               + "ignore the summary and don't mention it.")
        } + "\n\n" + h.text + "\n\n" + Lang.with(english: h.english ?? Lang.isEnglish) {
            // Xulosadagi «davom ettir» ko'rsatmalari ko'chirish uchun yozilgan — bu yerda foydalanuvchi so'ramaguncha ish boshlanmaydi
            tr("Eslatma: xulosadagi «davom ettir» ko'rsatmalari faqat foydalanuvchi ishni davom ettirishni so'rasa amal qiladi.",
               "Note: the summary's «continue» instructions apply only if the user asks to continue the work.")
        }
    }

    /// SessionStart hook kiritmasi → Claude Code'ga qaytariladigan JSON (yoki nil). Xulosa o'chirilmaydi:
    /// yangi sessiyada hech narsa yozilmay yopilsa, keyingisi ham oladi; yozilsa — ilova uni yangisi bilan almashtiradi
    public static func handleSessionStart(input: Data, in dir: URL = directory, now: Date = Date()) -> String? {
        guard let o = (try? JSONSerialization.jsonObject(with: input)) as? [String: Any],
              let sid = o["session_id"] as? String, let cwd = o["cwd"] as? String,
              let h = load(folder: cwd, in: dir),
              shouldDeliver(h, sessionId: sid, source: o["source"] as? String, now: now) else { return nil }
        let out: [String: Any] = ["hookSpecificOutput": ["hookEventName": "SessionStart",
                                                         "additionalContext": context(for: h, now: now)]]
        guard let d = try? JSONSerialization.data(withJSONObject: out) else { return nil }
        return String(data: d, encoding: .utf8)
    }
}
