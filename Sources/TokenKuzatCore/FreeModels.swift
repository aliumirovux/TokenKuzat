import Foundation

/// Bepul modellar — FreeLLMAPI orqali (github.com/tashfeenahmed/freellmapi: o'nlab kompaniyalarning bepul tariflarini
/// bitta mahalliy manzilga yig'adigan server). Ikki ish:
/// 1) Claude limiti tugaganda — terminalda Claude Code shu server orqali (bepul modellarda) ochiladi, limit tiklanganda ish Claude'ga qaytadi;
/// 2) MCP `ask_free_model` — Claude mayda, mustaqil ishlarni (tarjima, uzun logni qisqartirish) bepul modelga beradi.
/// Serverni foydalanuvchi o'zi o'rnatadi; Token Kuzatuv faqat manzil va kalitni saqlaydi.
public enum FreeModels {
    public static let defaultURL = "http://localhost:3001"
    /// Model nomi o'rniga — server o'zi eng yaxshi bo'sh modelni tanlaydi
    public static let autoModel = "auto"
    /// Bepul modellarning ko'pi 128K kontekstli: Claude Code shundan oldin qisqartirsin (eng kichik ruxsat etilgan qiymat)
    public static let compactWindow = 100_000

    public struct Config: Codable, Equatable, Sendable {
        public var url: String
        public var key: String
        public init(url: String, key: String) {
            self.url = url
            self.key = key
        }
    }

    /// Manzil va kalit — faqat shu foydalanuvchi o'qiy oladigan faylda (0600). Ilova ham, `--mcp` jarayoni ham, terminal skripti ham shundan o'qiydi
    public static var configURL: URL {
        HistoryStore.defaultURL.deletingLastPathComponent().appendingPathComponent("free-models.json")
    }

    public static func load(from url: URL = configURL) -> Config? {
        guard let d = try? Data(contentsOf: url), let c = try? JSONDecoder().decode(Config.self, from: d),
              !c.key.isEmpty else { return nil }
        return c
    }

    public static func save(_ c: Config, to url: URL = configURL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let fresh = Config(url: rootURL(c.url), key: c.key.trimmingCharacters(in: .whitespacesAndNewlines))
        try JSONEncoder().encode(fresh).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    public static func remove(at url: URL = configURL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// Claude modelimi. Bo'sh (hali noma'lum) — Claude deb olinadi. Bepul modellar (gemini-…, deepseek-…, auto)
    /// Claude limitiga kirmaydi: kunlik va 5 soatlik sarfga qo'shilmaydi, avtomatik ko'chirish ularga qo'llanmaydi
    public static func isClaude(_ model: String) -> Bool {
        model.isEmpty || model.lowercased().contains("claude")
    }

    /// Server ildizi: bo'shliqlar, oxiridagi «/» va «/v1» olib tashlanadi (Claude Code Anthropic yo'lini o'zi qo'shadi)
    public static func rootURL(_ s: String) -> String {
        var u = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if u.isEmpty { return defaultURL }
        while u.hasSuffix("/") { u.removeLast() }
        if u.hasSuffix("/v1") { u.removeLast(3) }
        return u
    }

    /// Terminal skriptining qatorlari: Claude Code shu server orqali ishlaydi. Kalit skriptga yozilmaydi —
    /// ishga tushganda sozlama faylidan o'qiladi. Claude ilovasidan meros qolgan CLAUDE_* o'zgaruvchilari avval tozalanadi
    public static func shellPrelude(url: String, configPath: String) -> String {
        func quote(_ s: String) -> String { "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }
        var lines = [
            "unset ANTHROPIC_API_KEY",
            "export ANTHROPIC_BASE_URL=\(quote(rootURL(url)))",
            "export ANTHROPIC_AUTH_TOKEN=\"$(/usr/bin/plutil -extract key raw -o - \(quote(configPath)))\"",
        ]
        for name in ["ANTHROPIC_MODEL", "ANTHROPIC_DEFAULT_OPUS_MODEL", "ANTHROPIC_DEFAULT_SONNET_MODEL", "ANTHROPIC_DEFAULT_HAIKU_MODEL"] {
            lines.append("export \(name)=\(autoModel)")
        }
        lines.append("export CLAUDE_CODE_AUTO_COMPACT_WINDOW=\(compactWindow)")
        lines.append("export CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1")
        return lines.joined(separator: "\n")
    }

    /// `GET /v1/models` javobidagi modellar soni (server ishlayapti va kalit to'g'ri)
    public static func modelCount(_ data: Data) -> Int? {
        guard let o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let list = o["data"] as? [Any] else { return nil }
        return list.count
    }

    /// `POST /v1/chat/completions` tanasi
    public static func chatRequest(prompt: String, system: String?, model: String?, maxTokens: Int?) -> [String: Any] {
        var messages: [[String: Any]] = []
        if let system, !system.isEmpty { messages.append(["role": "system", "content": system]) }
        messages.append(["role": "user", "content": prompt])
        var o: [String: Any] = ["model": model.flatMap { $0.isEmpty ? nil : $0 } ?? autoModel, "messages": messages]
        if let maxTokens, maxTokens > 0 { o["max_tokens"] = maxTokens }
        return o
    }

    public struct Reply: Equatable, Sendable {
        public var text: String
        public var model: String?
        public var tokens: Int?
    }

    /// Javob matni, javob bergan model va jami tokenlar. Server xato qaytarsa — nil
    public static func chatReply(_ data: Data) -> Reply? {
        guard let o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let choices = o["choices"] as? [[String: Any]], let msg = choices.first?["message"] as? [String: Any],
              let text = msg["content"] as? String else { return nil }
        let usage = o["usage"] as? [String: Any]
        return Reply(text: text, model: o["model"] as? String, tokens: (usage?["total_tokens"] as? NSNumber)?.intValue)
    }

    /// Server xatosining matni (`{"error": {"message": …}}` yoki oddiy matn)
    public static func errorText(_ data: Data) -> String? {
        if let o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            if let e = o["error"] as? [String: Any], let m = e["message"] as? String { return m }
            if let m = o["error"] as? String { return m }
        }
        let s = String(data: data.prefix(300), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return s?.isEmpty == false ? s : nil
    }

    /// Bepul modelda ochilgan sessiyaning birinchi xabari: nima uchun shu yerda, ehtiyotkorlik qoidalari va xulosa
    public static func fallbackMessage(summary: String, resetsAt: Date?, english: Bool? = nil, limit: Int = 8000) -> String {
        if let english { return Lang.with(english: english) { fallbackMessage(summary: summary, resetsAt: resetsAt, limit: limit) } }
        let when = resetsAt.map { tr(" Claude \(Fmt.hourMinute.string(from: $0)) da qaytadi.", " Claude is back at \(Fmt.hourMinute.string(from: $0)).") } ?? ""
        let head = tr("Token Kuzatuv: Claude limiti tugadi, ish vaqtincha bepul modelga (FreeLLMAPI) ko'chirildi.\(when) "
                      + "Quyidagi xulosaga tayan va tugallanmagan ishni kichik, tekshiriladigan qadamlar bilan davom ettir. "
                      + "Katta o'zgarish, fayl o'chirish, commit yoki push qilishdan oldin mendan so'ra. "
                      + "Ish tugagan yoki keyingi qadam men qaror qilishim kerak bo'lsa — hech narsa boshlamay, 2–3 jumlada holatni ayt va kut.",
                      "Token Kuzatuv: the Claude limit ran out, so the work moved to a free model (FreeLLMAPI) for now.\(when) "
                      + "Rely on the summary below and continue unfinished work in small, verifiable steps. "
                      + "Ask me before large changes, deleting files, committing or pushing. "
                      + "If the work is done or the next step is my decision, don't start anything — state where things stand in 2–3 sentences and wait.")
        return compose(head: head, summary: summary, limit: limit)
    }

    /// Limit tiklanganda Claude'da ochiladigan sessiyaning birinchi xabari: bepul modeldagi ishni tekshirib davom ettirish
    public static func returnMessage(summary: String, english: Bool? = nil, limit: Int = 8000) -> String {
        if let english { return Lang.with(english: english) { returnMessage(summary: summary, limit: limit) } }
        let head = tr("Token Kuzatuv: Claude limiti tiklandi. Limit tugagan paytda ish bepul modelda davom etgan edi — quyida o'sha sessiya xulosasi. "
                      + "Bepul model xato qilgan bo'lishi mumkin: avval u o'zgartirgan joylarni (git diff) ko'rib chiq, keyin ishni davom ettir. "
                      + "Ish tugagan yoki keyingi qadam men qaror qilishim kerak bo'lsa — hech narsa boshlamay, 2–3 jumlada holatni ayt va kut.",
                      "Token Kuzatuv: the Claude limit has reset. While it was out, the work continued on a free model — that session's summary is below. "
                      + "The free model may have made mistakes: first review what it changed (git diff), then continue the work. "
                      + "If the work is done or the next step is my decision, don't start anything — state where things stand in 2–3 sentences and wait.")
        return compose(head: head, summary: summary, limit: limit)
    }

    /// «↪ Loyiha — ish» sarlavhasi bo'lsa — eng tepaga (sessiya nomi shundan), keyin tizim matni va xulosa
    private static func compose(head: String, summary: String, limit: Int) -> String {
        var headline: String?
        var rest = summary
        if summary.hasPrefix("↪ ") {
            let parts = summary.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
            headline = String(parts[0])
            rest = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .newlines) : ""
        }
        let body = rest.count > limit ? String(rest.prefix(limit)) + "…" : rest
        return (headline.map { $0 + "\n\n" } ?? "") + head + (body.isEmpty ? "" : "\n\n" + body)
    }
}
