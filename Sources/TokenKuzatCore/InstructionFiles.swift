import Foundation

// Claude Code «InstructionsLoaded» hook'i: CLAUDE.md yoki .claude/rules/*.md kontekstga yuklanganda chaqiriladi
// (sessiya boshida, ichki papkaga kirilganda, qoida mos kelganda, @import va qisqartirishdan keyin).
// Hajm kelmaydi — fayl yuklangan paytda o'zimiz o'lchaymiz. Sessiya bo'yicha instructions/<session_id>.json ga yoziladi.

public struct InstructionFile: Codable, Equatable, Sendable {
    public let path: String
    /// User, Project, Local, Managed
    public let type: String
    /// session_start, nested_traversal, path_glob_match, include, compact
    public let reason: String
    public let bytes: Int

    /// Taxminiy token (~4 bayt = 1 token)
    public var tokens: Int { bytes / 4 }

    public init(path: String, type: String, reason: String, bytes: Int) {
        self.path = path
        self.type = type
        self.reason = reason
        self.bytes = bytes
    }
}

public enum InstructionFiles {
    public static let event = "InstructionsLoaded"

    public static var defaultDirectory: URL {
        RateLimitsReader.defaultDirectory.deletingLastPathComponent().appendingPathComponent("instructions")
    }

    /// Hook kiritmasini yozadi. InstructionsLoaded emas bo'lsa — false (chaqiruvchi uni boshqa hodisa sifatida yozadi)
    @discardableResult
    public static func record(_ o: [String: Any], dir: URL = defaultDirectory, fm: FileManager = .default) -> Bool {
        guard o["hook_event_name"] as? String == event else { return false }
        guard let sid = o["session_id"] as? String, !sid.isEmpty, !sid.contains("/"),
              let path = o["file_path"] as? String, !path.isEmpty else { return true }
        let bytes = ((try? fm.attributesOfItem(atPath: path))?[.size] as? NSNumber)?.intValue ?? 0
        let f = InstructionFile(path: path, type: o["memory_type"] as? String ?? "",
                                reason: o["load_reason"] as? String ?? "", bytes: bytes)
        // Qisqartirishdan keyin qayta yuklangan fayl — yangi yozuv emas, faqat hajmi yangilanadi
        var all = read(sid, dir: dir).filter { $0.path != path }
        all.append(f)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try? JSONEncoder().encode(all).write(to: dir.appendingPathComponent(sid + ".json"), options: .atomic)
        return true
    }

    public static func read(_ sessionId: String, dir: URL = defaultDirectory) -> [InstructionFile] {
        guard let d = try? Data(contentsOf: dir.appendingPathComponent(sessionId + ".json")) else { return [] }
        return (try? JSONDecoder().decode([InstructionFile].self, from: d)) ?? []
    }

    /// Ro'yxat uchun qisqa nom: ~/.claude/CLAUDE.md, loyiha/CLAUDE.md, rules/swift.md
    public static func shortName(_ path: String, home: String = NSHomeDirectory()) -> String {
        let parts = path.split(separator: "/").map(String.init)
        if let i = parts.lastIndex(of: "rules"), i < parts.count - 1 { return "rules/" + parts[(i + 1)...].joined(separator: "/") }
        if path.hasPrefix(home + "/.claude/") { return "~" + path.dropFirst(home.count) }
        return parts.suffix(2).joined(separator: "/")
    }
}
