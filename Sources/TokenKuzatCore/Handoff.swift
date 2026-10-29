import Foundation

// Avtomatik davom ettirish: foydalanuvchi «Yangi sessiyada davom ettirish»ni bosganda xulosa diskka yoziladi.
// Claude Code yangi sessiya ochganda SessionStart hook'i chaqiriladi — xulosa bir marta kontekstga qo'shiladi
// (additionalContext) va fayl o'chiriladi. Hech narsa nusxalab qo'yish shart emas, sifat — oldingi sessiya bilan bir xil.

public struct PendingHandoff: Codable, Equatable, Sendable {
    public let text: String
    public let sourceSession: String
    public let cwd: String?
    public let created: Date
    /// Suhbat tili (eski yozuvlarda yo'q — ilova tili ishlatiladi)
    public var english: Bool?

    public init(text: String, sourceSession: String, cwd: String?, created: Date, english: Bool? = nil) {
        self.text = text
        self.sourceSession = sourceSession
        self.cwd = cwd
        self.created = created
        self.english = english
    }
}

public enum HandoffStore {
    /// Shu vaqt ichida yangi sessiya ochilmasa — xulosa eskirgan, berilmaydi
    public static let lifetime: TimeInterval = 2 * 3600

    public static var defaultURL: URL {
        RateLimitsReader.defaultDirectory.deletingLastPathComponent().appendingPathComponent("handoff.json")
    }

    public static func arm(_ h: PendingHandoff, at url: URL = defaultURL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .secondsSince1970
        try enc.encode(h).write(to: url, options: .atomic)
    }

    /// Kutilayotgan xulosa (eskirgani — nil)
    public static func pending(at url: URL = defaultURL, now: Date = Date()) -> PendingHandoff? {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .secondsSince1970
        guard let d = try? Data(contentsOf: url), let h = try? dec.decode(PendingHandoff.self, from: d),
              now.timeIntervalSince(h.created) < lifetime else { return nil }
        return h
    }

    public static func cancel(at url: URL = defaultURL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// Shu yangi sessiyaga berilsinmi: yangi ochilgan (davom ettirilgan yoki /compact emas), boshqa sessiya,
    /// muddati o'tmagan; ikkala papka ham haqiqiy loyiha bo'lsa — bir xil papka.
    public static func shouldDeliver(_ h: PendingHandoff, sessionId: String, cwd: String?, source: String?, now: Date) -> Bool {
        if let source, source != "startup", source != "clear" { return false }
        guard sessionId != h.sourceSession, now.timeIntervalSince(h.created) < lifetime else { return false }
        if let a = h.cwd, let b = cwd, !isScratch(a), !isScratch(b) {
            return URL(fileURLWithPath: a).standardizedFileURL.path == URL(fileURLWithPath: b).standardizedFileURL.path
        }
        return true
    }

    /// Claude ilovasining vaqtinchalik ish papkalari — har sessiyada yangisi, papka bo'yicha solishtirib bo'lmaydi
    static func isScratch(_ path: String) -> Bool {
        path.contains("/scratch-workspaces/") || path.contains("/claude-code-sessions/")
    }

    public static func context(for h: PendingHandoff) -> String {
        Lang.with(english: h.english ?? Lang.isEnglish) {
            tr("Token Kuzatuv: foydalanuvchi oldingi sessiyani shu yangi sessiyada davom ettirishni tanladi. "
               + "Quyidagi xulosa — o'sha sessiyadan. Foydalanuvchining birinchi xabari shu ishga tegishli bo'lsa, unga tayan; "
               + "boshqa mavzu bo'lsa, e'tiborsiz qoldir.",
               "Token Kuzatuv: the user chose to continue the previous session in this new one. "
               + "The summary below is from that session. If the user's first message is about this work, rely on it; "
               + "if it's a different topic, ignore it.")
        } + "\n\n" + h.text
    }

    /// SessionStart hook kiritmasi → Claude Code'ga qaytariladigan JSON (yoki nil). Berilgan xulosa o'chiriladi.
    public static func handleSessionStart(input: Data, at url: URL = defaultURL, now: Date = Date()) -> String? {
        guard let h = pending(at: url, now: now) else {
            if FileManager.default.fileExists(atPath: url.path) { cancel(at: url) }
            return nil
        }
        guard let o = (try? JSONSerialization.jsonObject(with: input)) as? [String: Any],
              let sid = o["session_id"] as? String,
              shouldDeliver(h, sessionId: sid, cwd: o["cwd"] as? String, source: o["source"] as? String, now: now)
        else { return nil }
        cancel(at: url)
        let out: [String: Any] = ["hookSpecificOutput": ["hookEventName": "SessionStart",
                                                         "additionalContext": context(for: h)]]
        guard let d = try? JSONSerialization.data(withJSONObject: out) else { return nil }
        return String(data: d, encoding: .utf8)
    }
}
