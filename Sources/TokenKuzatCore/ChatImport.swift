import Foundation

// Bulutdagi chat yozuvlari: claude.ai / desktop chatdagi ishlar Anthropic bulutidagi kompyuterda bajariladi
// va Mac diskiga yozilmaydi. Ularning transcript'i (Claude Code bilan bir xil .jsonl) qo'lda qo'shiladi:
// ilova faylni ixchamlab o'z papkasiga ko'chiradi, Engine esa uni oddiy sessiya kabi o'qiydi.
//
// Ixchamlash: xaritaga keraksiz og'ir qismlar (rasm baytlari, uzun asbob natijalari) qisqartiriladi —
// tokenlar (usage), vaqtlar, asboblar va ularning boshi saqlanadi. Loyiha nomi «Claude chat» bo'ladi.

public enum ChatImport {
    public static let projectName = "Claude chat"
    /// Saqlanadigan matn bo'laklari (parser undan ham kamini oladi)
    static let textLimit = 3000

    public static var directory: URL {
        HistoryStore.defaultURL.deletingLastPathComponent().appendingPathComponent("chats")
    }

    /// Transcript'ni ixchamlaydi. Bitta ham tanilgan qator bo'lmasa — nil.
    public static func prepare(_ data: Data) -> Data? {
        var out = Data()
        var known = 0
        for raw in data.split(separator: 0x0A, omittingEmptySubsequences: true) {
            guard var o = (try? JSONSerialization.jsonObject(with: Data(raw))) as? [String: Any],
                  let type = o["type"] as? String else { continue }
            guard ["assistant", "user", "custom-title"].contains(type) else { continue }
            if type != "custom-title" {
                known += 1
                o["cwd"] = "/" + projectName
                if var msg = o["message"] as? [String: Any] {
                    if let arr = msg["content"] as? [[String: Any]] { msg["content"] = arr.map(slim) }
                    else if let s = msg["content"] as? String { msg["content"] = clip(s) }
                    o["message"] = msg
                }
                o.removeValue(forKey: "toolUseResult")
            }
            guard let line = try? JSONSerialization.data(withJSONObject: o, options: [.withoutEscapingSlashes]) else { continue }
            out.append(line)
            out.append(0x0A)
        }
        return known > 0 ? out : nil
    }

    /// Faylni qo'shadi: ixchamlab `directory` ga yozadi (bir xil nom — yangilanadi). Yozilgan fayl yo'li.
    @discardableResult
    public static func importFile(_ url: URL, into dir: URL = ChatImport.directory) throws -> URL {
        let data = try Data(contentsOf: url)
        guard let slim = prepare(data) else { throw ImportError.notTranscript }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var name = url.deletingPathExtension().lastPathComponent
        if name.isEmpty { name = UUID().uuidString }
        let dest = dir.appendingPathComponent(name + ".jsonl")
        try slim.write(to: dest, options: .atomic)
        return dest
    }

    public enum ImportError: LocalizedError {
        case notTranscript
        public var errorDescription: String? { "Bu fayl Claude yozuviga (.jsonl transcript) o'xshamaydi." }
    }

    // MARK: - Ixchamlash

    static func slim(_ b: [String: Any]) -> [String: Any] {
        var b = b
        switch b["type"] as? String {
        case "text":
            if let t = b["text"] as? String { b["text"] = clip(t) }
        case "thinking":
            if let t = b["thinking"] as? String { b["thinking"] = clip(t) }
            b.removeValue(forKey: "signature")
        case "redacted_thinking":
            b.removeValue(forKey: "data")
        case "image":
            // Natija hajmi hisobi uchun rasm bloki qoladi, baytlari tashlanadi
            b["source"] = [String: Any]()
        case "tool_use":
            if let input = b["input"] as? [String: Any] { b["input"] = input.mapValues(slimValue) }
        case "tool_result":
            if let s = b["content"] as? String { b["content"] = clip(s) }
            else if let arr = b["content"] as? [[String: Any]] { b["content"] = arr.map(slim) }
        default:
            break
        }
        return b
    }

    static func slimValue(_ v: Any) -> Any {
        if let s = v as? String { return clip(s) }
        if let d = v as? [String: Any] { return d.mapValues(slimValue) }
        if let a = v as? [Any] { return a.prefix(200).map(slimValue) }
        return v
    }

    static func clip(_ s: String) -> String {
        s.count > textLimit ? String(s.prefix(textLimit)) + "…" : s
    }
}
