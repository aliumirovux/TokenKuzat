import Foundation

/// Asbob chaqiruvi «o'qish/qidirish»mi: `Read`/`Grep`/`Glob` va Bash orqali `cat`, `grep`, `sed -n`… —
/// rahbar fayllarni Bash bilan o'qisa ham yordamchiga berish kerakligini bilish uchun
public enum ReadCounter {
    private static let readTools: Set<String> = ["Read", "Grep", "Glob", "NotebookRead"]
    private static let readPrograms: Set<String> = [
        "cat", "head", "tail", "less", "grep", "rg", "egrep", "fgrep", "find", "fd", "ls", "tree", "wc", "sed", "awk", "jq",
    ]
    /// Zararsiz yordamchi dasturlar: yolg'iz o'qish emas, lekin o'qish bilan birga chaqiruvni rad etmaydi
    private static let neutralPrograms: Set<String> = [
        "sort", "uniq", "cut", "tr", "echo", "printf", "true", "false", "column", "nl", "basename", "dirname", "pwd", "which",
        "file", "stat", "du", "diff", "cmp", "sha256sum", "shasum", "md5", "md5sum", "test", "[", "cd", ":",
    ]
    private static let readGit: Set<String> = ["show", "diff", "log", "grep", "status", "branch", "rev-parse", "ls-files", "blame", "cat-file"]
    private static let execReaders: Set<String> = ["grep", "egrep", "fgrep", "rg", "cat", "head", "tail", "wc", "ls", "file", "stat"]
    private static let xargsValueOptions: Set<String> = ["-I", "-n", "-P", "-L", "-d", "-E", "-s", "-a"]

    private enum Kind { case read, neutral, other }

    public static func isRead(tool: String, input: [String: Any]?) -> Bool {
        if readTools.contains(tool) { return true }
        guard tool == "Bash", let command = input?["command"] as? String else { return false }
        return isReadCommand(command)
    }

    /// Bitta Bash chaqiruvi = 1 o'qish: hech bo'lmasa bitta o'qish bo'lagi bor, qolganlari zararsiz (cd, sort, echo…)
    static func isReadCommand(_ command: String) -> Bool {
        var reads = 0
        for part in split(command) where !part.isEmpty {
            let t = tokens(part)
            var words = t.words
            while let f = words.first, f == "(" || f == "{" { words.removeFirst() }
            while let l = words.last, l == ")" || l == "}" { words.removeLast() }
            if let f = words.first, f.count > 1, f.hasPrefix("(") { words[0] = String(f.dropFirst()) }
            if let l = words.last, l.count > 1, l.hasSuffix(")") { words[words.count - 1] = String(l.dropLast()) }
            guard let i = words.firstIndex(where: { !isAssignment($0) }) else { continue }
            if t.writes { return false }
            switch kind(Array(words[i...])) {
            case .read: reads += 1
            case .neutral: break
            case .other: return false
            }
        }
        return reads > 0
    }

    private static func kind(_ words: [String]) -> Kind {
        let prog = (words[0] as NSString).lastPathComponent
        let args = Array(words.dropFirst())
        switch prog {
        case "sed":
            for a in args {
                if a.hasPrefix("--") { if a.hasPrefix("--in-place") { return .other }; continue }
                if a.hasPrefix("-") { if a.dropFirst().contains("i") { return .other }; continue }
                if a.range(of: #"(^|[/;{}0-9$,])\s*w\s*\S"#, options: .regularExpression) != nil { return .other }
            }
            return .read
        case "awk":
            let bad = args.contains { $0.contains(">") || $0.contains("system(") || $0.range(of: #"print[^|]*\|"#, options: .regularExpression) != nil }
            return bad ? .other : .read
        case "find":
            if args.contains(where: { ["-delete", "-fprint", "-fprint0", "-fprintf", "-fls"].contains($0) }) { return .other }
            var i = 0
            while i < args.count {
                if args[i] == "-exec" || args[i] == "-execdir" {
                    guard i + 1 < args.count, execReaders.contains((args[i + 1] as NSString).lastPathComponent) else { return .other }
                }
                i += 1
            }
            return .read
        case "git":
            var i = 0
            while i < args.count, args[i].hasPrefix("-") { i += (args[i] == "-C" || args[i] == "-c") ? 2 : 1 }
            guard i < args.count, readGit.contains(args[i]) else { return .other }
            // `git branch ad` — shoxcha yaratadi; faqat optionlar bilan ro'yxat
            if args[i] == "branch", args[(i + 1)...].contains(where: { !$0.hasPrefix("-") }) { return .other }
            return .read
        case "xargs":
            var i = 0
            while i < args.count, args[i].hasPrefix("-") { i += xargsValueOptions.contains(args[i]) ? 2 : 1 }
            guard i < args.count else { return .other }
            let k = kind(Array(args[i...]))
            return k == .read ? .read : .other
        case "sort":
            return args.contains { $0 == "-o" || $0.hasPrefix("--output") } ? .other : .neutral
        default:
            if readPrograms.contains(prog) { return .read }
            return neutralPrograms.contains(prog) ? .neutral : .other
        }
    }

    private static func isAssignment(_ w: String) -> Bool {
        guard let eq = w.firstIndex(of: "="), eq != w.startIndex else { return false }
        return w[..<eq].allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }

    /// `&&`, `||`, `;`, `|`, `&` va qator oxiri bo'yicha bo'ladi (qo'shtirnoq ichida va `\;` emas)
    private static func split(_ s: String) -> [String] {
        var out: [String] = [], cur = ""
        var quote: Character?
        let chars = Array(s)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if let q = quote {
                if c == "\\", q == "\"", i + 1 < chars.count { cur.append(c); cur.append(chars[i + 1]); i += 2; continue }
                if c == q { quote = nil }
                cur.append(c)
            } else if c == "\\", i + 1 < chars.count {
                cur.append(c); cur.append(chars[i + 1]); i += 2; continue
            } else if c == "'" || c == "\"" {
                quote = c
                cur.append(c)
            } else if c == "&", (i + 1 < chars.count && chars[i + 1] == ">") || (i > 0 && chars[i - 1] == ">") {
                cur.append(c)   // `&>` va `2>&1` — yo'naltirish, bo'lish emas
            } else if c == ";" || c == "|" || c == "&" || c == "\n" {
                out.append(cur)
                cur = ""
            } else {
                cur.append(c)
            }
            i += 1
        }
        out.append(cur)
        return out.map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// So'zlarga bo'ladi: qo'shtirnoq olib tashlanadi, `\x` ekranlanadi. Qo'shtirnoqsiz `>` — yozishga yo'naltirish
    /// (`/dev/null`, `/dev/stderr`, `/dev/stdout`, `&1`, `&2` — zararsiz); u va uning nishoni so'zlar ro'yxatiga kirmaydi
    private static func tokens(_ s: String) -> (words: [String], writes: Bool) {
        var out: [String] = [], cur = ""
        var quote: Character?
        var has = false, writes = false
        let chars = Array(s)
        var i = 0
        func flush() { if has || !cur.isEmpty { out.append(cur) }; cur = ""; has = false }
        while i < chars.count {
            let c = chars[i]
            if let q = quote {
                if q == "\"", c == "\\", i + 1 < chars.count, "\"\\$`".contains(chars[i + 1]) { cur.append(chars[i + 1]); i += 2; continue }
                if c == q { quote = nil } else { cur.append(c) }
            } else if c == "\\", i + 1 < chars.count {
                cur.append(chars[i + 1]); has = true; i += 2; continue
            } else if c == "'" || c == "\"" {
                quote = c
                has = true
            } else if c == " " || c == "\t" {
                flush()
            } else if c == ">" || (c == "&" && i + 1 < chars.count && chars[i + 1] == ">") {
                // oldingi `2` / `1` / `&` — fayl deskriptori, so'z emas
                if !cur.isEmpty, cur.allSatisfy({ $0.isNumber }) { cur = ""; has = false }
                if c == "&" { i += 1 }
                while i < chars.count, chars[i] == ">" { i += 1 }
                if i < chars.count, chars[i] == "&" {   // `>&2`
                    i += 1
                    while i < chars.count, chars[i].isNumber || chars[i] == "-" { i += 1 }
                    continue
                }
                flush()
                while i < chars.count, chars[i] == " " { i += 1 }
                var target = ""
                while i < chars.count, chars[i] != " ", chars[i] != "\t" { target.append(chars[i]); i += 1 }
                if !["/dev/null", "/dev/stderr", "/dev/stdout"].contains(target) { writes = true }
                continue
            } else {
                cur.append(c)
            }
            i += 1
        }
        flush()
        return (out, writes)
    }
}
