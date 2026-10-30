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

    /// Fayllar bilan birga promptga qo'shiladigan qoida: qator raqami bilan iqtibos — javobni tekshirsa bo'lsin.
    /// Sinovda bepul model topish, ro'yxat va qisqartirishda aniq, sanash/eng katta va ikki joyni bog'lashda adashdi
    public static let fileRules = """
        Rules for the files below: each line starts with its line number as "N| " (not part of the text). \
        For every claim give the line number as L<N> and quote the exact text from that line in double quotes, without the "N| " prefix. \
        Quote one line per quote; never join pieces from different lines into one quote. \
        If the answer isn't in the files, say so instead of guessing.
        """

    /// Fayllarni o'qib, promptga qo'shiladigan matnga aylantiradi: har biri «--- file: yo'l ---» sarlavhasi bilan,
    /// har qator «N| » raqami bilan (bepul model javobda qatorni ko'rsatadi, Claude o'sha qatorni o'zi tekshira oladi)
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
            parts.append("--- file: \(path) ---\n\(numbered(text))")
        }
        return .success(parts.joined(separator: "\n\n"))
    }

    static func numbered(_ text: String) -> String {
        var lines = text.components(separatedBy: "\n")
        if lines.last == "" { lines.removeLast() }
        return lines.enumerated().map { "\($0.offset + 1)| \($0.element)" }.joined(separator: "\n") + "\n"
    }

    /// Javob talab qilinmagan uzunlikka cheklansa, o'ylaydigan model butun chegarani o'ylashga sarflab, javobsiz qoladi
    public static let minAnswerTokens = 1500

    /// Javobdagi iqtiboslar (qo'shtirnoq, «», > qatori; 12 belgidan uzun) — fayllarda topilmaganlari.
    /// Sinovda bepul model xato xulosani o'zgartirilgan iqtibos bilan berdi — shu tekshiruv ushlaydi
    public static func missingQuotes(in answer: String, files: String) -> (checked: Int, missing: [String]) {
        let source = normalize(files.replacingOccurrences(of: #"(?m)^\d+\| "#, with: "", options: .regularExpression))
        var quotes: [String] = []
        for pattern in [#""((?:[^"\\\n]|\\.){12,})""#, #"“([^”\n]{12,})”"#, #"«([^»\n]{12,})»"#, #"(?m)^\s*>\s*(.{12,})$"#] {
            let re = try! NSRegularExpression(pattern: pattern)
            let ns = answer as NSString
            for m in re.matches(in: answer, range: NSRange(location: 0, length: ns.length)) {
                var q = ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces)
                // «> "…"» — tashqi qo'shtirnoq va oxirgi nuqta iqtibosga kirmaydi
                q = q.trimmingCharacters(in: CharacterSet(charactersIn: "\"“”`")).trimmingCharacters(in: .whitespaces)
                q = q.replacingOccurrences(of: #"^L?\d+\|?\s*"#, with: "", options: .regularExpression)
                if q.hasSuffix(".") && !source.contains(normalize(q)) { q.removeLast() }
                if q.count >= 12, !quotes.contains(q) { quotes.append(q) }
            }
        }
        // «> "…"» ham, ichidagi «"…"» ham bir iqtibos — ichma-ich takrorlar bir marta sanaladi
        quotes = quotes.filter { q in !quotes.contains { $0 != q && $0.contains(q) } }
        // Faqat bo'shliq, tinish belgisi yoki «+++---» chizig'i farq qilsa — iqtibos to'g'ri (sinovda git diffstat chizig'i
        // bitta «-» ga farq qilib, bekorga belgilangan edi). Harf yoki raqam farq qilsa — baribir belgilanadi
        let loose = letters(source)
        let missing = quotes.filter { q in
            if source.contains(normalize(q)) { return false }
            let l = letters(q)
            return l.count < 8 || !loose.contains(l)
        }
        return (quotes.count, missing)
    }

    /// Faqat harf va raqamlar, kichik harfda
    static func letters(_ s: String) -> String {
        String(normalize(s).lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(Character.init))
    }

    static func normalize(_ s: String) -> String {
        var t = s
        for (a, b) in [("’", "'"), ("‘", "'"), ("ʻ", "'"), ("ʼ", "'"), ("`", ""), ("\\\"", "\"")] { t = t.replacingOccurrences(of: a, with: b) }
        return t.split(whereSeparator: \.isWhitespace).joined(separator: " ")
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
