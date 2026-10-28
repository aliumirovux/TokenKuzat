import Foundation

// Claude Code «Notification» hook'i: ruxsat so'raganda («Claude needs your permission to use Bash») yoki
// javob kutib qolganda chaqiriladi va stdin'ga JSON beradi. Token Kuzatuv'ning `--hook` rejimi uni
// ~/Library/Application Support/TokenKuzat/hooks/<session_id>.json ga yozadi, bu yerda o'qiladi.

public struct HookNotice: Equatable, Sendable {
    public enum Kind: String, Sendable {
        /// Asbob uchun ruxsat kutyapti
        case permission
        /// Javobingizni kutyapti (uzoq vaqt jim)
        case idle
        case other
    }

    public let sessionId: String
    public let kind: Kind
    public let message: String
    public let date: Date

    public init(sessionId: String, kind: Kind, message: String, date: Date) {
        self.sessionId = sessionId
        self.kind = kind
        self.message = message
        self.date = date
    }

    /// Hook JSON'idan; `date` — qabul qilingan payt
    public static func parse(_ data: Data, date: Date) -> HookNotice? {
        guard let o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let sid = o["session_id"] as? String, !sid.isEmpty else { return nil }
        let message = o["message"] as? String ?? ""
        let type = (o["notification_type"] as? String ?? "").lowercased()
        let m = message.lowercased()
        let kind: Kind
        if type.contains("permission") || m.contains("permission") { kind = .permission }
        else if type.contains("idle") || m.contains("waiting for your input") { kind = .idle }
        else { kind = .other }
        return HookNotice(sessionId: sid, kind: kind, message: message, date: date)
    }

    /// Ruxsat hali ham kutilyaptimi: xabardan keyin sessiyada yangi harakat bo'lmagan bo'lsa.
    /// Claude Code asbob chaqiruvini transkriptga ruxsat so'rashdan oldin yozadi — 2 s chegara shuning uchun.
    public func isPending(lastActivity: Date?, now: Date) -> Bool {
        guard kind == .permission, now.timeIntervalSince(date) < 6 * 3600 else { return false }
        return lastActivity.map { $0 <= date.addingTimeInterval(2) } ?? true
    }
}

public enum HookEvents {
    public static var defaultDirectory: URL {
        RateLimitsReader.defaultDirectory.deletingLastPathComponent().appendingPathComponent("hooks")
    }

    /// Har sessiyaning eng so'nggi xabari
    public static func read(_ dir: URL = defaultDirectory) -> [String: HookNotice] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) else { return [:] }
        var out: [String: HookNotice] = [:]
        for f in files where f.pathExtension == "json" {
            guard let d = try? Data(contentsOf: f),
                  let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any],
                  let ts = (o["received_at"] as? NSNumber)?.doubleValue,
                  let n = HookNotice.parse(d, date: Date(timeIntervalSince1970: ts)) else { continue }
            out[n.sessionId] = n
        }
        return out
    }
}
