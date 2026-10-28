import Foundation

/// Transcript'ning bitta qatori — Engine uchun kerakli qismi.
public struct TranscriptEvent {
    public enum Kind {
        case assistant(Assistant)
        case user(User)
        /// Sessiyaga foydalanuvchi bergan nom («custom-title»)
        case title(String)
    }

    public enum Item: Equatable {
        case tool(id: String, name: String, description: ToolDescriber.Description, target: ToolTarget)
        case text
        case thinking
    }

    public struct Assistant {
        public var model: String?
        public var stopReason: String?
        public var items: [Item] = []
        public var usage: TokenCounts?
        /// Bitta javob bir necha qatorga bo'linadi va har birida usage takrorlanadi — shu kalit bilan bir marta sanaladi
        public var usageKey: String?
    }

    public struct User {
        /// Foydalanuvchining haqiqiy so'rovlari (tizim eslatmalari va meta qatorlarsiz)
        public var prompts: [String] = []
        public var hasToolResult = false
        /// Tugagan asbob chaqiruvlari: tool_use id → xato bo'ldimi
        public var results: [(id: String, isError: Bool)] = []
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
                                     target: ToolDescriber.target(name, input)))
            case "text":
                if let t = b["text"] as? String, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    a.items.append(.text)
                }
            case "thinking", "redacted_thinking":
                a.items.append(.thinking)
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
                let mid = msg["id"] as? String ?? ""
                let rid = obj["requestId"] as? String ?? ""
                a.usageKey = mid.isEmpty ? obj["uuid"] as? String : mid + "|" + rid
            }
        }
        return a
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
                        u.results.append((id: id, isError: (b["is_error"] as? Bool) == true))
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
    static func prompt(_ raw: String) -> String? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
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
        return isoFrac.date(from: s) ?? isoPlain.date(from: s)
    }

    private static func int(_ v: Any?) -> Int { (v as? NSNumber)?.intValue ?? 0 }
}
