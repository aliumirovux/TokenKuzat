import Foundation

// Eski sessiyadan yo'naltirish: avtomatik yangi sessiya ochilgandan keyin foydalanuvchi eski sessiyada yozishda davom etsa,
// Claude Code «UserPromptSubmit» hook'i birinchi xabarni to'xtatadi va uni xulosa bilan birga yangi sessiyaga olib o'tadi.
// Xuddi shu sessiyada qayta yozilsa — endi to'xtatilmaydi (foydalanuvchi shu yerda qolishni tanlagan).

public struct PendingRedirect: Codable, Equatable, Sendable {
    public let summary: String
    public let previousContext: Int
    public let created: Date
    public var used: Bool
    /// Suhbat tili (eski yozuvlarda yo'q — ilova tili ishlatiladi)
    public var english: Bool?
    /// Yangi sessiya ochiladigan loyiha papkasi (eski yozuvlarda yo'q — hook bergan papka ishlatiladi)
    public var folder: String?

    public init(summary: String, previousContext: Int, created: Date, used: Bool = false, english: Bool? = nil, folder: String? = nil) {
        self.summary = summary
        self.previousContext = previousContext
        self.created = created
        self.used = used
        self.english = english
        self.folder = folder
    }
}

public enum RedirectStore {
    /// Shu vaqtdan keyin yo'naltirilmaydi — sessiya eskirgan
    public static let lifetime: TimeInterval = 24 * 3600

    public static var defaultURL: URL {
        RateLimitsReader.defaultDirectory.deletingLastPathComponent().appendingPathComponent("redirects.json")
    }

    public static func load(at url: URL = defaultURL) -> [String: PendingRedirect] {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .secondsSince1970
        guard let d = try? Data(contentsOf: url) else { return [:] }
        return (try? dec.decode([String: PendingRedirect].self, from: d)) ?? [:]
    }

    static func save(_ all: [String: PendingRedirect], at url: URL) {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .secondsSince1970
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? enc.encode(all).write(to: url, options: .atomic)
    }

    /// Sessiya yangi sessiyaga ko'chirildi — keyingi xabari yo'naltiriladi (eskirganlari tozalanadi)
    /// `replace` — sessiya qayta ko'chirilganda: avvalgi (ishlatilgan) yo'naltirish yangisi bilan almashtiriladi
    public static func add(session: String, summary: String, previousContext: Int, english: Bool? = nil, folder: String? = nil,
                           replace: Bool = false, at url: URL = defaultURL, now: Date = Date()) {
        var all = load(at: url).filter { now.timeIntervalSince($0.value.created) < lifetime }
        guard replace || all[session] == nil else { return }
        all[session] = PendingRedirect(summary: summary, previousContext: previousContext, created: now, english: english, folder: folder)
        save(all, at: url)
    }

    public static func contains(_ session: String, at url: URL = defaultURL) -> Bool { load(at: url)[session] != nil }

    public struct Decision: Equatable, Sendable {
        /// Claude Code'ga qaytariladigan JSON (xabar to'xtatiladi, sababi ko'rsatiladi)
        public let output: String
        /// Yangi sessiyaning birinchi xabari: xulosa + foydalanuvchining yangi so'rovi
        public let message: String
        public let cwd: String?
    }

    /// UserPromptSubmit kiritmasi → yo'naltirish (yoki nil — xabar odatdagidek ketadi)
    /// `needsEnter` — yangi sessiya Claude ilovasida ochiladi: xabar u yerda faqat yozib qo'yiladi, Enter foydalanuvchida
    public static func handlePrompt(input: Data, needsEnter: Bool = false, at url: URL = defaultURL, now: Date = Date()) -> Decision? {
        guard let o = (try? JSONSerialization.jsonObject(with: input)) as? [String: Any],
              let sid = o["session_id"] as? String else { return nil }
        var all = load(at: url)
        guard var r = all[sid], !r.used, now.timeIntervalSince(r.created) < lifetime else { return nil }
        // Claude ilovasi xabarga qo'shadigan «<system-reminder>» bloklari yangi sessiyaga o'tkazilmaydi
        let prompt = (o["prompt"] as? String ?? "")
            .replacingOccurrences(of: #"<system-reminder>[\s\S]*?</system-reminder>"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // Slash-buyruqlar (/compact, /clear…) shu sessiyaga tegishli — to'xtatilmaydi
        guard !prompt.isEmpty, !prompt.hasPrefix("/") else { return nil }
        r.used = true
        all[sid] = r
        save(all, at: url)
        return Lang.with(english: r.english ?? Lang.isEnglish) { decision(r, prompt: prompt, cwd: o["cwd"] as? String, needsEnter: needsEnter) }
    }

    private static func decision(_ r: PendingRedirect, prompt: String, cwd: String?, needsEnter: Bool) -> Decision? {
        var message = AutoHandoffRule.firstMessage(summary: r.summary, previousContext: r.previousContext)
        message += "\n\n" + tr("Yangi so'rovim (oldingi sessiyada yozgan edim) — shuni bajar:",
                               "My new request (I typed it in the old session) — do this:") + "\n" + prompt
        let reason = tr("Token Kuzatuv: bu sessiya konteksti katta (\(Fmt.tokens(r.previousContext))) — ish yangi sessiyaga ko'chirilgan. "
                        + (needsEnter
                           ? "Xabaringiz xulosa bilan birga yangi sessiyaga yozib qo'yildi — u yerda Enter bosing va davom eting (kontekst kichik, limit kam ketadi). "
                           : "Xabaringiz xulosa bilan birga yangi sessiyaga yuborildi, u yerda davom eting (kontekst kichik, limit kam ketadi). ")
                        + "Shu yerda qolmoqchi bo'lsangiz — xabarni qayta yuboring.",
                        "Token Kuzatuv: this session's context is large (\(Fmt.tokens(r.previousContext))) — the work moved to a new session. "
                        + (needsEnter
                           ? "Your message is filled in there together with the summary — press Enter there and continue (smaller context, less of your limit). "
                           : "Your message was sent there together with the summary; continue there (smaller context, less of your limit). ")
                        + "To stay here, send the message again.")
        let out: [String: Any] = ["decision": "block", "reason": reason]
        guard let d = try? JSONSerialization.data(withJSONObject: out), let s = String(data: d, encoding: .utf8) else { return nil }
        return Decision(output: s, message: message, cwd: r.folder ?? cwd)
    }
}
