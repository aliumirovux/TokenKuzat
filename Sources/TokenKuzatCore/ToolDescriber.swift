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
