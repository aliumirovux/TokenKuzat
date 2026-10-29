import Foundation

/// Transcript'ning bitta qatori — Engine uchun kerakli qismi.
public struct TranscriptEvent {
    public enum Kind {
        case assistant(Assistant)
        case user(User)
        /// Sessiyaga foydalanuvchi bergan nom («custom-title»)
        case title(String)
        /// Suhbat qisqartirildi («compact_boundary»): trigger va oldingi/keyingi kontekst
        case compact(auto: Bool, before: Int, after: Int)
    }

    public enum Item: Equatable {
        /// `input` — asbobga berilgan parametrlar (JSON, ko'pi bilan `ioLimit` belgi)
        case tool(id: String, name: String, description: ToolDescriber.Description, target: ToolTarget, input: String)
        /// Javob matni (ko'pi bilan `noteLimit` belgi; uzuni — boshi va oxiri)
        case text(String)
        /// O'ylash matni; shifrlangan bo'lsa — bo'sh
        case thinking(String)
    }

    /// Saqlanadigan matn uzunligi — uzun sessiyalarda xotira o'smasin
    /// Uzun javobning oxiri ko'chirish eslatmasi bilan birga sig'sin
    public static let noteLimit = 3000
    /// Qadam kirishi va chiqishidan saqlanadigan qism (xaritadagi tafsilot uchun)
    public static let inputLimit = 1200
    public static let outputLimit = 1500

    public struct Assistant {
        public var model: String?
        public var stopReason: String?
        public var items: [Item] = []
        public var usage: TokenCounts?
        /// Bitta javob bir necha qatorga bo'linadi va har birida usage takrorlanadi — shu kalit bilan bir marta sanaladi
        public var usageKey: String?
        /// Kesh qaysi muddatga yozilgan: true — 1 soat, false — 5 daqiqa, nil — bu javobda yozilmagan
        public var longCache: Bool?
    }

    public struct User {
        /// Foydalanuvchining haqiqiy so'rovlari (tizim eslatmalari va meta qatorlarsiz)
        public var prompts: [String] = []
        public var hasToolResult = false
        /// Tugagan asbob chaqiruvlari: tool_use id → xato bo'ldimi, natija hajmi (taxminiy token), natija matni boshi
        public var results: [(id: String, isError: Bool, tokens: Int, text: String)] = []
    }

    public var kind: Kind
    public var timestamp: Date?
    public var cwd: String?
    public var uuid: String?
    /// Asosiy fayl ichidagi yordamchi agent qatori (eski formatlar)
    public var sidechainAgentId: String?
}

public enum TranscriptParser {
    public static func parse(_ line: Data) -> TranscriptEvent? {
        guard let obj = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any] else { return nil }
        return parse(obj)
    }

    public static func parse(_ obj: [String: Any]) -> TranscriptEvent? {
        guard let type = obj["type"] as? String else { return nil }
        let kind: TranscriptEvent.Kind
        switch type {
        case "assistant":
            kind = .assistant(assistant(obj))
        case "user":
            kind = .user(user(obj))
        case "custom-title":
            guard let t = obj["customTitle"] as? String, !t.isEmpty else { return nil }
            kind = .title(t)
        case "system":
            guard obj["subtype"] as? String == "compact_boundary" else { return nil }
            let m = obj["compactMetadata"] as? [String: Any] ?? [:]
            kind = .compact(auto: m["trigger"] as? String != "manual", before: int(m["preTokens"]), after: int(m["postTokens"]))
        default:
            return nil
        }
        var ev = TranscriptEvent(kind: kind)
        ev.timestamp = date(obj["timestamp"])
        if let cwd = obj["cwd"] as? String, !cwd.isEmpty { ev.cwd = cwd }
        ev.uuid = obj["uuid"] as? String
        if (obj["isSidechain"] as? Bool) == true, let aid = obj["agentId"] as? String, !aid.isEmpty {
            ev.sidechainAgentId = aid
        }
        return ev
    }

    // MARK: - Qismlar

    private static func assistant(_ obj: [String: Any]) -> TranscriptEvent.Assistant {
        let msg = obj["message"] as? [String: Any] ?? [:]
        var a = TranscriptEvent.Assistant()
        if let m = msg["model"] as? String, !m.isEmpty, m != "<synthetic>" { a.model = m }
        a.stopReason = msg["stop_reason"] as? String

        for b in msg["content"] as? [[String: Any]] ?? [] {
            switch b["type"] as? String {
            case "tool_use":
                guard let id = b["id"] as? String else { continue }
                let name = b["name"] as? String ?? "?"
                let input = b["input"] as? [String: Any] ?? [:]
                a.items.append(.tool(id: id, name: name, description: ToolDescriber.describe(name, input),
                                     target: ToolDescriber.target(name, input), input: inputText(input)))
            case "text":
                if let t = b["text"] as? String {
                    let s = t.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !s.isEmpty { a.items.append(.text(clipMiddle(s, TranscriptEvent.noteLimit))) }
                }
            case "thinking", "redacted_thinking":
                let s = (b["thinking"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                a.items.append(.thinking(String(s.prefix(TranscriptEvent.noteLimit))))
            default:
                break
            }
        }

        if let u = msg["usage"] as? [String: Any] {
            let cc = u["cache_creation"] as? [String: Any]
            let details = u["output_tokens_details"] as? [String: Any]
            var c = TokenCounts(input: int(u["input_tokens"]),
                                output: int(u["output_tokens"]),
                                thinking: int(details?["thinking_tokens"]),
                                cacheWrite: int(u["cache_creation_input_tokens"]),
                                cacheRead: int(u["cache_read_input_tokens"]))
            c.weighted = Pricing.weigh(input: c.input, output: c.output, cacheRead: c.cacheRead,
                                       cacheWrite: c.cacheWrite,
                                       write1h: int(cc?["ephemeral_1h_input_tokens"]),
                                       write5m: int(cc?["ephemeral_5m_input_tokens"]))
            if c.total > 0 {
                a.usage = c
                let w1h = int(cc?["ephemeral_1h_input_tokens"]), w5m = int(cc?["ephemeral_5m_input_tokens"])
                if w1h + w5m > 0 { a.longCache = w1h > 0 }
                let mid = msg["id"] as? String ?? ""
                let rid = obj["requestId"] as? String ?? ""
                a.usageKey = mid.isEmpty ? obj["uuid"] as? String : mid + "|" + rid
            }
        }
        return a
    }

    /// Asbob natijasining kontekstdagi taxminiy hajmi: matn ≈ 4 belgi/token, rasm ≈ 1600 token
    static func resultTokens(_ content: Any?) -> Int {
        if let s = content as? String { return s.utf8.count / 4 }
        guard let arr = content as? [[String: Any]] else { return 0 }
        return arr.reduce(0) { sum, b in
            switch b["type"] as? String {
            case "text": return sum + (b["text"] as? String ?? "").utf8.count / 4
            case "image": return sum + 1_600
            default: return sum
            }
        }
    }

    /// Asbob parametrlari — o'qiladigan JSON (kalitlar tartiblangan), uzun bo'lsa qisqartiriladi
    static func inputText(_ input: [String: Any]) -> String {
        guard !input.isEmpty else { return "" }
        guard let d = try? JSONSerialization.data(withJSONObject: input, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]) else {
            return ""
        }
        return clip(String(decoding: d, as: UTF8.self), TranscriptEvent.inputLimit)
    }

    /// Asbob natijasi matni: matn bloklari birlashtiriladi, rasm — «[rasm]»
    static func resultText(_ content: Any?) -> String {
        if let s = content as? String { return clip(s, TranscriptEvent.outputLimit) }
        guard let arr = content as? [[String: Any]] else { return "" }
        var parts: [String] = []
        var len = 0
        for b in arr where len < TranscriptEvent.outputLimit {
            switch b["type"] as? String {
            case "text":
                let t = b["text"] as? String ?? ""
                parts.append(t)
                len += t.count
            case "image": parts.append("[rasm]")
            default: break
            }
        }
        return clip(parts.joined(separator: "\n"), TranscriptEvent.outputLimit)
    }

    /// Belgilar bo'yicha qisqartirish; kesilgan bo'lsa oxirida «…»
    /// Uzun javobning boshi va oxiri: savol va kutilayotgan qaror odatda oxirida bo'ladi
    static func clipMiddle(_ s: String, _ limit: Int) -> String {
        guard s.count > limit else { return s }
        let head = limit * 3 / 10
        return String(s.prefix(head)) + "\n…\n" + String(s.suffix(limit - head))
    }

    static func clip(_ s: String, _ limit: Int) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.count > limit ? String(t.prefix(limit)) + "…" : t
    }

    private static func user(_ obj: [String: Any]) -> TranscriptEvent.User {
        var u = TranscriptEvent.User()
        let isMeta = (obj["isMeta"] as? Bool) == true
        let msg = obj["message"] as? [String: Any] ?? [:]
        if let s = msg["content"] as? String {
            if !isMeta, let p = prompt(s) { u.prompts.append(p) }
        } else if let arr = msg["content"] as? [[String: Any]] {
            for b in arr {
                switch b["type"] as? String {
                case "tool_result":
                    u.hasToolResult = true
                    if let id = b["tool_use_id"] as? String {
                        u.results.append((id: id, isError: (b["is_error"] as? Bool) == true, tokens: resultTokens(b["content"]),
                                          text: resultText(b["content"])))
                    }
                case "text":
                    if !isMeta, let s = b["text"] as? String, let p = prompt(s) { u.prompts.append(p) }
                default:
                    break
                }
            }
        }
        return u
    }

    /// Tizim qo'shgan matnlar («<system-reminder>…», «[Request interrupted…]») so'rov hisoblanmaydi.
    /// Boshidagi «<system-reminder>» bloklari olib tashlanadi: boshqa sessiyadan ochilgan sessiyada haqiqiy topshiriq
    /// ular ortidan keladi (aks holda sessiyada birorta so'rov qolmay, xarita bo'sh chiqardi).
    static func prompt(_ raw: String) -> String? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while s.hasPrefix("<system-reminder>"), let end = s.range(of: "</system-reminder>") {
            s = String(s[end.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !s.isEmpty, !s.hasPrefix("<"), !s.hasPrefix("[Request interrupted") else { return nil }
        return s
    }

    // MARK: - Yordamchilar

    private static let isoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoPlain = ISO8601DateFormatter()

    static func date(_ v: Any?) -> Date? {
        guard let s = v as? String else { return nil }
        return fastISO(s) ?? isoFrac.date(from: s) ?? isoPlain.date(from: s)
    }

    /// «2026-10-29T22:01:15.031Z» (yoki «+05:00» bilan) — formatter'dan o'nlab marta tez; har qatorda chaqiriladi.
    /// Boshqa ko'rinishdagi sana — nil (formatter o'qiydi)
    static func fastISO(_ string: String) -> Date? {
        var str = string
        return str.withUTF8 { b -> Date? in
            guard b.count >= 20, b[4] == 0x2D, b[7] == 0x2D, b[10] == 0x54 || b[10] == 0x74, b[13] == 0x3A, b[16] == 0x3A
            else { return nil }
            func num(_ from: Int, _ len: Int) -> Int? {
                var v = 0
                for i in from..<from + len {
                    let d = Int(b[i]) - 48
                    guard d >= 0, d <= 9 else { return nil }
                    v = v * 10 + d
                }
                return v
            }
            guard let y = num(0, 4), let mo = num(5, 2), let d = num(8, 2), let h = num(11, 2), let mi = num(14, 2),
                  let sec = num(17, 2), (1...12).contains(mo), (1...31).contains(d), h < 24, mi < 60, sec < 61 else { return nil }
            var i = 19
            var frac = 0.0
            if b[i] == 0x2E {
                i += 1
                var scale = 1.0, v = 0.0
                while i < b.count, b[i] >= 48, b[i] <= 57 {
                    if scale < 1e9 { v = v * 10 + Double(b[i] - 48); scale *= 10 }
                    i += 1
                }
                guard scale > 1 else { return nil }
                frac = v / scale
            }
            guard i < b.count else { return nil }
            var offset = 0
            switch b[i] {
            case 0x5A, 0x7A:
                guard i + 1 == b.count else { return nil }
            case 0x2B, 0x2D:
                let colon = i + 3 < b.count && b[i + 3] == 0x3A
                guard b.count == i + (colon ? 6 : 5), let oh = num(i + 1, 2), let om = num(i + (colon ? 4 : 3), 2),
                      oh < 24, om < 60 else { return nil }
                offset = (oh * 3600 + om * 60) * (b[i] == 0x2D ? -1 : 1)
            default:
                return nil
            }
            // Kunlar soni 1970-01-01 dan (proleptik Grigorian kalendari)
            let yy = mo <= 2 ? y - 1 : y
            let era = (yy >= 0 ? yy : yy - 399) / 400
            let yoe = yy - era * 400
            let doy = (153 * (mo > 2 ? mo - 3 : mo + 9) + 2) / 5 + d - 1
            let days = era * 146_097 + yoe * 365 + yoe / 4 - yoe / 100 + doy - 719_468
            let t = Double(days * 86_400 + h * 3600 + mi * 60 + sec - offset) + frac
            return Date(timeIntervalSince1970: t)
        }
    }

    private static func int(_ v: Any?) -> Int { (v as? NSNumber)?.intValue ?? 0 }
}
