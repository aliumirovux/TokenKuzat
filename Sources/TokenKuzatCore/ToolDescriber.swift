import Foundation

/// Asbob chaqiruvini odam o'qiydigan qisqa matnga aylantiradi: «O'qiyapti · Engine.swift».
public enum ToolDescriber {
    public struct Description: Equatable, Sendable {
        public let symbol: String
        public let text: String
        /// Terminal buyrug'ida tilga olingan rasm/HTML/PDF yo'llari («Natijalar» uchun)
        public var paths: [String] = []
    }

    /// «mcp__github__create_issue» → «github: create_issue»; claude.ai konnektori (server nomi UUID) → «create_issue»
    public static func shortName(_ name: String) -> String {
        if name.hasPrefix("mcp__") {
            let p = name.components(separatedBy: "__")
            if p.count >= 3 {
                let tool = p[2...].joined(separator: "_")
                return isOpaqueServer(p[1]) ? tool : "\(p[1].replacingOccurrences(of: "_", with: " ")): \(tool)"
            }
        }
        return name
    }

    /// Server nomi o'rnida ID (UUID) — foydalanuvchiga ko'rsatib bo'lmaydi
    public static func isOpaqueServer(_ server: String) -> Bool {
        server.range(of: #"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"#, options: .regularExpression) != nil
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
        case "Read": return d("doc.text", tr("O'qiyapti · \(file())", "Reading · \(file())"))
        case "Write": return d("square.and.pencil", tr("Yozyapti · \(file())", "Writing · \(file())"))
        case "Edit", "MultiEdit", "NotebookEdit": return d("pencil", tr("Tahrirlayapti · \(file())", "Editing · \(file())"))
        case "Bash":
            var x = d("terminal", "Terminal · \(clip(str("description") ?? str("command") ?? ""))")
            x.paths = SessionOutputs.paths(in: str("command") ?? "")
            return x
        case "Grep": return d("magnifyingglass", tr("Matn qidiryapti · ", "Searching text · ") + clip(str("pattern") ?? "", 50))
        case "Glob": return d("folder", tr("Fayl qidiryapti · ", "Finding files · ") + clip(str("pattern") ?? "", 50))
        case "WebSearch": return d("globe", tr("Internetda qidiryapti · ", "Searching the web · ") + clip(str("query") ?? ""))
        case "WebFetch":
            let host = str("url").flatMap { URL(string: $0)?.host } ?? ""
            return d("safari", tr("Sahifa o'qiyapti · \(host)", "Reading page · \(host)"))
        case "Agent", "Task":
            return d("person.2.fill", tr("Agent ishga tushirdi · ", "Launched agent · ") + clip(str("description") ?? str("subagent_type") ?? ""))
        case "TodoWrite", "TaskCreate", "TaskUpdate": return d("checklist", tr("Vazifalar ro'yxatini yangiladi", "Updated the task list"))
        case "Skill": return d("sparkles", "Skill · \(str("skill") ?? "")")
        case "ToolSearch": return d("wrench.and.screwdriver", tr("Asbob yuklayapti", "Loading tools"))
        default:
            if name.hasPrefix("mcp__") {
                let p = name.components(separatedBy: "__")
                if p.count >= 3, let h = humanMCP(server: p[1], tool: p[2...].joined(separator: "_"), input) { return h }
                return d("puzzlepiece.extension", shortName(name))
            }
            return d("gearshape", name)
        }
    }

    /// Tez-tez uchraydigan MCP asboblari odam tilida: «computer-use: app_screenshot» → «Ekranni ko'ryapti».
    /// Notanish asbob — `nil`, ya'ni «server: asbob» ko'rinishida qoladi.
    static func humanMCP(server: String, tool: String, _ input: [String: Any]) -> Description? {
        let t = tool.hasPrefix("app_") ? String(tool.dropFirst(4)) : tool
        func d(_ symbol: String, _ text: String) -> Description { Description(symbol: symbol, text: text) }
        switch server {
        case "computer-use":
            switch t {
            case "screenshot", "zoom": return d("camera.viewfinder", tr("Ekranni ko'ryapti", "Looking at the screen"))
            case "request_access", "request_full_control", "request_teach_access":
                return d("hand.raised", tr("Ilovaga ruxsat so'rayapti", "Asking for app access"))
            case "list_windows", "list_apps", "list_granted_applications", "ax_find":
                return d("macwindow", tr("Oynalarni ko'zdan kechiryapti", "Looking through windows"))
            case "release", "release_full_control": return d("hand.wave", tr("Ilovani qo'yib yubordi", "Released the app"))
            default: return d("cursorarrow.click", tr("Ilovani boshqaryapti", "Controlling an app"))
            }
        case "Claude_Browser", "claude-in-chrome":
            let b = server == "claude-in-chrome" ? "Chrome" : tr("Brauzer", "Browser")
            switch t {
            case "navigate":
                let host = (input["url"] as? String).flatMap { URL(string: $0)?.host } ?? ""
                return d("safari", tr("\(b) · sahifa ochyapti", "\(b) · opening a page") + (host.isEmpty ? "" : " · \(host)"))
            case "read_page", "get_page_text", "find", "read_console_messages", "read_network_requests":
                return d("doc.text.magnifyingglass", tr("\(b) · sahifani o'qiyapti", "\(b) · reading the page"))
            default: return d("safari", tr("\(b) · boshqaryapti", "\(b) · controlling"))
            }
        default:
            guard server.hasPrefix("ccd_") else { return nil }
            switch tool {
            case "update_plan": return d("checklist", tr("Rejani yangiladi", "Updated the plan"))
            case "wrap_up": return d("flag.checkered", tr("Javobni yakunlayapti", "Wrapping up the reply"))
            default: return d("app.badge", tr("Claude ilovasi · ", "Claude app · ") + tool.replacingOccurrences(of: "_", with: " "))
            }
        }
    }

    /// Sxemadagi xizmat nomi: «computer-use» → «Kompyuter»
    static func serverTitle(_ server: String) -> String {
        switch server {
        case "computer-use": return tr("Kompyuter", "Computer")
        case "Claude_Browser": return tr("Brauzer", "Browser")
        case "claude-in-chrome": return "Chrome"
        default: return server.hasPrefix("ccd_") ? tr("Claude ilovasi", "Claude app") : server.replacingOccurrences(of: "_", with: " ")
        }
    }
}

// MARK: - Nishon: agent nimaga kirdi

/// Agent «tegingan» narsa turi — sxemada alohida tugun bo'ladi.
public enum ToolCategory: String, CaseIterable, Sendable {
    case files, shell, web, mcp, agent, other

    public var title: String {
        switch self {
        case .files: return tr("Fayllar", "Files")
        case .shell: return "Terminal"
        case .web: return tr("Internet", "Web")
        case .mcp: return tr("Tashqi xizmatlar", "External services")
        case .agent: return tr("Agent chaqiruvlari", "Agent calls")
        case .other: return tr("Boshqa asboblar", "Other tools")
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
            let where_ = str("path").map { ($0 as NSString).lastPathComponent } ?? tr("loyiha", "project")
            return t(.files, "search|" + pattern, "🔍 " + pattern, tr("qidiruv · \(where_)", "search · \(where_)"), .read)
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
            return t(.web, host, host, tr("sahifa o'qildi", "page read"), .read)
        case "WebSearch":
            let q = str("query") ?? ""
            return t(.web, "search|" + q, "🔍 " + q, tr("internetda qidiruv", "web search"), .read)
        case "Agent", "Task":
            let d = str("description") ?? str("subagent_type") ?? "agent"
            return t(.agent, d, d, str("subagent_type") ?? tr("yordamchi agent", "subagent"), .run)
        default:
            if name.hasPrefix("mcp__") {
                let p = name.components(separatedBy: "__")
                let server = p.count >= 2 ? p[1].replacingOccurrences(of: "_", with: " ") : name
                let tool = p.count >= 3 ? p[2...].joined(separator: "_") : ""
                if p.count >= 2, isOpaqueServer(p[1]) { return t(.mcp, p[1], tool, tr("konnektor", "connector"), .run) }
                return t(.mcp, server, p.count >= 2 ? serverTitle(p[1]) : server, tool, .run)
            }
            switch name {
            case "ToolSearch": return t(.other, name, tr("Asbob qidiruvi", "Tool search"), "", .run)
            case "TodoWrite", "TaskCreate", "TaskUpdate": return t(.other, "tasks", tr("Vazifalar ro'yxati", "Task list"), "", .run)
            case "Skill": return t(.other, "skill|" + (str("skill") ?? ""), "Skill · " + (str("skill") ?? ""), "", .run)
            default: return t(.other, name, name, "", .run)
            }
        }
    }
}
