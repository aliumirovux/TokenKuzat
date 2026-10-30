import Foundation

/// MCP `ask_free_model` ning fayllari va hisobi.
/// Fayllarni MCP server o'zi o'qiydi — uzun log Claude kontekstiga umuman kirmaydi, tejash shu yerda.
/// Har chaqiruv `free-model-calls.jsonl` ga yoziladi: «Tejash» sahifasi necha marta ish berilgani va
/// taxminan qancha Claude tokeni tejalganini shundan ko'rsatadi.
public enum FreeModelLog {
    /// Bitta chaqiruvga beriladigan fayllar chegarasi: bepul modellarning ko'pi 128K kontekstli
    public static let maxFileBytes = 400_000

    public struct Call: Codable, Equatable, Sendable {
        public var date: Date
        public var model: String
        /// Claude yozgan prompt (fayllarsiz)
        public var promptTokens: Int
        /// MCP server o'qib qo'shgan fayllar — Claude ularni ko'rmadi
        public var fileTokens: Int
        /// Bepul model javobi — Claude buni o'zi yozmadi
        public var replyTokens: Int
        public init(date: Date, model: String, promptTokens: Int, fileTokens: Int, replyTokens: Int) {
            self.date = date
            self.model = model
            self.promptTokens = promptTokens
            self.fileTokens = fileTokens
            self.replyTokens = replyTokens
        }
        /// Taxminiy tejash: Claude o'qimagan fayl matni + o'zi yozmagan javob
        public var savedTokens: Int { fileTokens + replyTokens }
    }

    public static var defaultURL: URL {
        FreeModels.configURL.deletingLastPathComponent().appendingPathComponent("free-model-calls.jsonl")
    }

    /// Taxminiy token soni (4 bayt ≈ 1 token — loyihaning boshqa joylaridagidek)
    public static func tokens(_ s: String) -> Int { s.utf8.count / 4 }

    // MARK: Fayllar

    /// Maxfiy bo'lishi mumkin bo'lgan fayllar — bepul provayderga hech qachon yuborilmaydi
    public static func isSecret(_ path: String) -> Bool {
        let name = (path as NSString).lastPathComponent.lowercased()
        if name.hasPrefix(".env") || name.hasPrefix("id_rsa") || name.hasPrefix("id_ed25519") || name.hasPrefix("id_ecdsa")
            || name.hasPrefix("credentials") || name.hasPrefix("secrets") { return true }
        if [".netrc", ".npmrc", ".pypirc", "free-models.json", "known_hosts"].contains(name) { return true }
        let ext = (name as NSString).pathExtension
        if ["pem", "key", "p12", "pfx", "keychain", "keystore", "jks", "asc", "gpg"].contains(ext) { return true }
        let parts = (path as NSString).pathComponents
        return parts.contains(".ssh") || parts.contains(".gnupg") || parts.contains(".aws")
    }

    public enum FileError: Error, Equatable, CustomStringConvertible {
        case notAbsolute(String), secret(String), unreadable(String), binary(String), tooLarge(Int)
        public var description: String {
            switch self {
            case .notAbsolute(let p): return "Use an absolute path: \(p)"
            case .secret(let p): return "Refused: \(p) may contain secrets — free providers may log inputs"
            case .unreadable(let p): return "Can't read file: \(p)"
            case .binary(let p): return "Not a UTF-8 text file: \(p)"
            case .tooLarge(let n): return "Files are too large (\(n / 1000) KB, limit \(maxFileBytes / 1000) KB) — pass fewer or smaller files"
            }
        }
    }

    /// Fayllarni o'qib, promptga qo'shiladigan matnga aylantiradi: har biri «--- file: yo'l ---» sarlavhasi bilan
    public static func readFiles(_ paths: [String], limit: Int = maxFileBytes) -> Result<String, FileError> {
        var parts: [String] = []
        var total = 0
        for raw in paths {
            let path = (raw.trimmingCharacters(in: .whitespacesAndNewlines) as NSString).expandingTildeInPath
            guard path.hasPrefix("/") else { return .failure(.notAbsolute(raw)) }
            let resolved = (path as NSString).resolvingSymlinksInPath
            if isSecret(path) || isSecret(resolved) { return .failure(.secret(raw)) }
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: resolved, isDirectory: &isDir), !isDir.boolValue,
                  let data = FileManager.default.contents(atPath: resolved) else { return .failure(.unreadable(raw)) }
            total += data.count
            if total > limit { return .failure(.tooLarge(total)) }
            guard let text = String(data: data, encoding: .utf8), !text.contains("\0") else { return .failure(.binary(raw)) }
            parts.append("--- file: \(path) ---\n\(text)")
        }
        return .success(parts.joined(separator: "\n\n"))
    }

    // MARK: Hisob

    public static func append(_ call: Call, to url: URL = defaultURL) {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        guard var line = try? enc.encode(call) else { return }
        line.append(0x0A)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let h = try? FileHandle(forWritingTo: url) {
            h.seekToEndOfFile()
            h.write(line)
            try? h.close()
        } else {
            try? line.write(to: url, options: .atomic)
        }
    }

    public static func load(from url: URL = defaultURL) -> [Call] {
        guard let d = try? Data(contentsOf: url), let s = String(data: d, encoding: .utf8) else { return [] }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return s.split(separator: "\n").compactMap { try? dec.decode(Call.self, from: Data($0.utf8)) }
    }

    public struct Summary: Equatable, Sendable {
        public var calls = 0
        public var withFiles = 0
        public var fileTokens = 0
        public var savedTokens = 0
    }

    public static func summary(_ calls: [Call], since: Date) -> Summary {
        calls.filter { $0.date >= since }.reduce(into: Summary()) { s, c in
            s.calls += 1
            if c.fileTokens > 0 { s.withFiles += 1 }
            s.fileTokens += c.fileTokens
            s.savedTokens += c.savedTokens
        }
    }
}
