import Foundation

// «Natijalar»: sessiya davomida yaratilgan yoki ko'rilgan rasm, HTML, PDF va videolar.
// Manba — fayl asboblari (Write/Edit/Read) va terminal buyruqlarida tilga olingan to'liq yo'llar.

public struct OutputFile: Identifiable, Equatable, Sendable {
    public enum Kind: String, Sendable {
        case image, web, pdf, video

        public var title: String {
            switch self {
            case .image: return "Rasm"
            case .web: return "HTML"
            case .pdf: return "PDF"
            case .video: return "Video"
            }
        }
    }

    public var id: String { path }
    public let path: String
    public let kind: Kind
    /// Claude yozgan yoki tahrirlagan (aks holda — faqat o'qigan yoki buyruqda tilga olingan)
    public let written: Bool
    public let lastActivity: Date?

    public var name: String { (path as NSString).lastPathComponent }
    public var folder: String { (path as NSString).deletingLastPathComponent }

    public static func kind(of path: String) -> Kind? {
        switch (path as NSString).pathExtension.lowercased() {
        case "png", "jpg", "jpeg", "gif", "webp", "heic", "tiff", "bmp": return .image
        case "html", "htm", "svg": return .web
        case "pdf": return .pdf
        case "mp4", "mov", "m4v": return .video
        default: return nil
        }
    }
}

public enum SessionOutputs {
    /// Eng so'nggisi birinchi; `exists` — diskda bor-yo'qligini tekshirish (testlarda almashtiriladi)
    public static func collect(_ s: SessionSnap,
                               exists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }) -> [OutputFile] {
        var byPath: [String: OutputFile] = [:]
        func add(_ path: String, written: Bool, at: Date?) {
            guard path.hasPrefix("/"), let kind = OutputFile.kind(of: path) else { return }
            if let old = byPath[path] {
                let last = [old.lastActivity, at].compactMap { $0 }.max()
                byPath[path] = OutputFile(path: path, kind: kind, written: old.written || written, lastActivity: last)
            } else {
                byPath[path] = OutputFile(path: path, kind: kind, written: written, lastActivity: at)
            }
        }
        for a in s.agents {
            for g in a.resources where g.category == .files {
                for item in g.items where item.id.hasPrefix("files|") {
                    add(String(item.id.dropFirst(6)), written: item.writes > 0, at: item.lastActivity)
                }
            }
            // Terminal: «… --snapshot-map /tmp/x.png», «open report.html» — to'liq yo'llar
            for (p, at) in a.outputs { add(p, written: true, at: at) }
        }
        return byPath.values.filter { exists($0.path) }
            .sorted { ($0.lastActivity ?? .distantPast) > ($1.lastActivity ?? .distantPast) }
    }

    static func paths(in text: String) -> [String] {
        let text = expandVariables(text)
        let ext = #"\.(?:png|jpe?g|gif|webp|heic|tiff|bmp|html?|svg|pdf|mp4|mov|m4v)"#
        // Qo'shtirnoq ichidagi yo'l (bo'shliq bo'lishi mumkin) yoki bo'shliq/«=» dan keyin boshlanadigan yo'l
        let pattern = #"(?:"(/[^"]+"# + ext + #")"|'(/[^']+"# + ext + #")'|(?:^|[\s=(])(/[^\s"'`<>|;()]+"# + ext + #"))(?![\w.])"#
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let ns = text as NSString
        return re.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap { m in
            (1...3).lazy.map { m.range(at: $0) }.first { $0.location != NSNotFound }.map { ns.substring(with: $0) }
        }
    }

    /// Buyruq ichida berilgan oddiy o'zgaruvchilar ochiladi: «SP=/tmp/x; app --out $SP/a.png» → «/tmp/x/a.png»
    static func expandVariables(_ cmd: String) -> String {
        guard cmd.contains("$"),
              let re = try? NSRegularExpression(pattern: #"(?:^|[\s;&(])([A-Za-z_][A-Za-z0-9_]*)=("[^"$`]*"|'[^']*'|[^\s;&|"'`$]+)"#)
        else { return cmd }
        let ns = cmd as NSString
        var vars: [String: String] = [:]
        for m in re.matches(in: cmd, range: NSRange(location: 0, length: ns.length)) {
            var v = ns.substring(with: m.range(at: 2))
            if v.count >= 2, let f = v.first, f == "\"" || f == "'", v.last == f { v = String(v.dropFirst().dropLast()) }
            vars[ns.substring(with: m.range(at: 1))] = v
        }
        if let home = ProcessInfo.processInfo.environment["HOME"] { vars["HOME"] = vars["HOME"] ?? home }
        var out = cmd
        for (k, v) in vars.sorted(by: { $0.key.count > $1.key.count }) {
            out = out.replacingOccurrences(of: "${\(k)}", with: v).replacingOccurrences(of: "$\(k)", with: v)
        }
        return out
    }
}
