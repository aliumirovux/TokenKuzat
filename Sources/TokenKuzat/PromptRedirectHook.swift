import Foundation
import TokenKuzatCore

/// Claude Code «UserPromptSubmit» hook'i: avtomatik yangi sessiya ochilgan eski sessiyada yozilgan birinchi xabarni
/// to'xtatib, xulosa bilan birga yangi sessiyaga yuboradi. Kontekst chegaraga yaqin sessiyada esa Claude'dan
/// javob oxiriga ko'chirish eslatmasini yozishni so'raydi.
///
/// Skript avval yo'naltirish yoki eslatma fayli borligini tekshiradi — yo'q bo'lsa darhol chiqadi (oddiy xabarlarga ta'sir qilmaydi).
enum PromptRedirectHook {
    static let flag = "--prompt-submit"
    private static let event = "UserPromptSubmit"
    private static let marker = "TokenKuzat/prompt-submit.sh"

    private static var scriptURL: URL {
        RateLimitsReader.defaultDirectory.deletingLastPathComponent().appendingPathComponent("prompt-submit.sh")
    }

    private static func writeScript() throws {
        let exe = Bundle.main.executablePath ?? CommandLine.arguments[0]
        let script = """
        #!/bin/sh
        # Token Kuzatuv — Claude Code UserPromptSubmit hook (ilova yaratgan): faqat ko'chirilgan yoki chegaraga yaqin sessiyada ishlaydi
        [ -f "\(RedirectStore.defaultURL.path)" ] || [ -f "\(NoteRequestStore.defaultURL.path)" ] || exit 0
        [ -x "\(exe)" ] || exit 0
        "\(exe)" \(flag) 2>/dev/null
        exit 0

        """
        try FileManager.default.createDirectory(at: scriptURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
    }

    static var isInstalled: Bool {
        guard let s = try? StatusLine.readSettings() else { return false }
        return entries(s).contains { isOurs($0) } && FileManager.default.isExecutableFile(atPath: scriptURL.path)
    }

    private static func entries(_ s: [String: Any]) -> [[String: Any]] {
        ((s["hooks"] as? [String: Any])?[event] as? [[String: Any]]) ?? []
    }

    private static func isOurs(_ entry: [String: Any]) -> Bool {
        ((entry["hooks"] as? [[String: Any]]) ?? []).contains { ($0["command"] as? String)?.contains(marker) == true }
    }

    /// Skript har safar yangilanadi (ilova boshqa joyga ko'chirilgan bo'lishi mumkin); settings.json — faqat kerak bo'lsa
    static func install() throws {
        try writeScript()
        var s = try StatusLine.readSettings()
        guard !entries(s).contains(where: { isOurs($0) }) else { return }
        var hooks = s["hooks"] as? [String: Any] ?? [:]
        var list = entries(s)
        list.append(["hooks": [["type": "command", "command": "\"\(scriptURL.path)\""]]])
        hooks[event] = list
        s["hooks"] = hooks
        try StatusLine.backupOnce()
        try StatusLine.writeSettings(s)
    }

    static func uninstall() throws {
        var s = try StatusLine.readSettings()
        var hooks = s["hooks"] as? [String: Any] ?? [:]
        let list = entries(s).filter { !isOurs($0) }
        if list.isEmpty { hooks.removeValue(forKey: event) } else { hooks[event] = list }
        if hooks.isEmpty { s.removeValue(forKey: "hooks") } else { s["hooks"] = hooks }
        try StatusLine.writeSettings(s)
        try? FileManager.default.removeItem(at: scriptURL)
        try? FileManager.default.removeItem(at: RedirectStore.defaultURL)
        try? FileManager.default.removeItem(at: NoteRequestStore.defaultURL)
    }

    /// `--prompt-submit` rejimi (Claude Code chaqiradi): yo'naltirish kerak bo'lsa — yangi sessiyani ochadi va
    /// xabarni to'xtatuvchi JSON chiqaradi; sessiya chegaraga yaqin bo'lsa — eslatma so'rovi; aks holda hech narsa
    /// (xabar odatdagidek ketadi)
    static func runAndExit() -> Never {
        let data = FileHandle.standardInput.readDataToEndOfFile()
        Pref.register()
        let target = AutoHandoffTarget(rawValue: UserDefaults.standard.string(forKey: Pref.autoHandoffTarget) ?? "") ?? .app
        if UserDefaults.standard.bool(forKey: Pref.autoHandoffRedirect),
           let d = RedirectStore.handlePrompt(input: data, needsEnter: target == .app) {
            let opened: Bool
            switch target {
            case .app: opened = AutoHandoff.openInApp(cwd: d.cwd, message: d.message)
            case .terminal: opened = AutoHandoff.openInTerminal(cwd: d.cwd, message: d.message)
            }
            // Ochib bo'lmasa — xabar to'xtatilmaydi, shu sessiyada odatdagidek ketadi
            if opened {
                FileHandle.standardOutput.write(Data(d.output.utf8))
                exit(0)
            }
        }
        if UserDefaults.standard.bool(forKey: Pref.autoHandoff), let out = NoteRequestStore.handlePrompt(input: data) {
            FileHandle.standardOutput.write(Data(out.utf8))
        }
        exit(0)
    }
}
