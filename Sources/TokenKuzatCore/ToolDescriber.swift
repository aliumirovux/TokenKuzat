import Foundation

/// Asbob chaqiruvini odam o'qiydigan qisqa matnga aylantiradi: «O'qiyapti · Engine.swift».
public enum ToolDescriber {
    public struct Description: Equatable, Sendable {
        public let symbol: String
        public let text: String
    }

    /// «mcp__github__create_issue» → «github: create_issue»
    public static func shortName(_ name: String) -> String {
        if name.hasPrefix("mcp__") {
            let p = name.components(separatedBy: "__")
            if p.count >= 3 {
                return "\(p[1].replacingOccurrences(of: "_", with: " ")): \(p[2...].joined(separator: "_"))"
            }
        }
        return name
    }

    public static func describe(_ name: String, _ input: [String: Any]) -> Description {
        func str(_ k: String) -> String? {
            guard let s = input[k] as? String, !s.isEmpty else { return nil }
            return s
        }
        func file() -> String {
            guard let p = str("file_path") ?? str("path") ?? str("notebook_path") else { return "" }
            return URL(fileURLWithPath: p).lastPathComponent
        }
        func clip(_ s: String, _ n: Int = 70) -> String {
            let one = s.replacingOccurrences(of: "\n", with: " ")
            return one.count > n ? String(one.prefix(n)) + "…" : one
        }
        func d(_ symbol: String, _ text: String) -> Description { Description(symbol: symbol, text: text) }

        switch name {
        case "Read": return d("doc.text", "O'qiyapti · \(file())")
        case "Write": return d("square.and.pencil", "Yozyapti · \(file())")
        case "Edit", "MultiEdit", "NotebookEdit": return d("pencil", "Tahrirlayapti · \(file())")
        case "Bash": return d("terminal", "Terminal · \(clip(str("description") ?? str("command") ?? ""))")
        case "Grep": return d("magnifyingglass", "Matn qidiryapti · \(clip(str("pattern") ?? "", 50))")
        case "Glob": return d("folder", "Fayl qidiryapti · \(clip(str("pattern") ?? "", 50))")
        case "WebSearch": return d("globe", "Internetda qidiryapti · \(clip(str("query") ?? ""))")
        case "WebFetch":
            let host = str("url").flatMap { URL(string: $0)?.host } ?? ""
            return d("safari", "Sahifa o'qiyapti · \(host)")
        case "Agent", "Task":
            return d("person.2.fill", "Agent ishga tushirdi · \(clip(str("description") ?? str("subagent_type") ?? ""))")
        case "TodoWrite", "TaskCreate", "TaskUpdate": return d("checklist", "Vazifalar ro'yxatini yangiladi")
        case "Skill": return d("sparkles", "Skill · \(str("skill") ?? "")")
        case "ToolSearch": return d("wrench.and.screwdriver", "Asbob yuklayapti")
        default:
            if name.hasPrefix("mcp__") { return d("puzzlepiece.extension", shortName(name)) }
            return d("gearshape", name)
        }
    }
}

// MARK: - Nishon: agent nimaga kirdi

/// Agent «tegingan» narsa turi — sxemada alohida tugun bo'ladi.
public enum ToolCategory: String, CaseIterable, Sendable {
    case files, shell, web, mcp, agent, other

    public var title: String {
        switch self {
        case .files: return "Fayllar"
        case .shell: return "Terminal"
        case .web: return "Internet"
        case .mcp: return "Tashqi xizmatlar"
        case .agent: return "Agent chaqiruvlari"
        case .other: return "Boshqa asboblar"
        }
    }

    public var symbol: String {
        switch self {
        case .files: return "doc.on.doc.fill"
        case .shell: return "terminal.fill"
        case .web: return "globe"
        case .mcp: return "puzzlepiece.extension.fill"
        case .agent: return "person.2.fill"
        case .other: return "wrench.and.screwdriver.fill"
        }
    }
}

public enum ToolAccess: String, Sendable {
    case read, write, run
}

public struct ToolTarget: Equatable, Sendable {
    public let category: ToolCategory
    /// Bir xil narsani birlashtirish kaliti (masalan, faylning to'liq yo'li)
    public let key: String
    public let name: String
    public let detail: String
    public let access: ToolAccess
}

extension ToolDescriber {
    public static func target(_ name: String, _ input: [String: Any]) -> ToolTarget {
        func str(_ k: String) -> String? {
            guard let s = input[k] as? String, !s.isEmpty else { return nil }
            return s
        }
        func shortDir(_ path: String) -> String {
            let dir = (path as NSString).deletingLastPathComponent
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            return dir.hasPrefix(home) ? "~" + dir.dropFirst(home.count) : dir
        }
        func t(_ c: ToolCategory, _ key: String, _ n: String, _ d: String, _ a: ToolAccess) -> ToolTarget {
            ToolTarget(category: c, key: c.rawValue + "|" + key, name: n, detail: d, access: a)
        }

        switch name {
        case "Read", "Write", "Edit", "MultiEdit", "NotebookEdit":
            let path = str("file_path") ?? str("notebook_path") ?? str("path") ?? "?"
            return t(.files, path, (path as NSString).lastPathComponent, shortDir(path), name == "Read" ? .read : .write)
        case "Grep", "Glob":
            let pattern = str("pattern") ?? ""
            let where_ = str("path").map { ($0 as NSString).lastPathComponent } ?? "loyiha"
            return t(.files, "search|" + pattern, "🔍 " + pattern, "qidiruv · \(where_)", .read)
        case "Bash":
            let cmd = str("command") ?? ""
            // «cd x && git status» → «git»: buyruq dasturi bo'yicha guruhlanadi
            let parts = cmd.components(separatedBy: CharacterSet(charactersIn: "&;|\n"))
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && !$0.hasPrefix("cd ") }
            let program = parts.first?.split(separator: " ").first.map(String.init) ?? "shell"
            let prog = (program as NSString).lastPathComponent
            return t(.shell, prog, prog, str("description") ?? String(cmd.prefix(80)), .run)
        case "WebFetch":
            let host = str("url").flatMap { URL(string: $0)?.host } ?? "?"
            return t(.web, host, host, "sahifa o'qildi", .read)
        case "WebSearch":
            let q = str("query") ?? ""
            return t(.web, "search|" + q, "🔍 " + q, "internetda qidiruv", .read)
        case "Agent", "Task":
            let d = str("description") ?? str("subagent_type") ?? "agent"
            return t(.agent, d, d, str("subagent_type") ?? "yordamchi agent", .run)
        default:
            if name.hasPrefix("mcp__") {
                let p = name.components(separatedBy: "__")
                let server = p.count >= 2 ? p[1].replacingOccurrences(of: "_", with: " ") : name
                let tool = p.count >= 3 ? p[2...].joined(separator: "_") : ""
                return t(.mcp, server, server, tool, .run)
            }
            return t(.other, name, name, "", .run)
        }
    }
}
