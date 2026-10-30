import Foundation
import TokenKuzatCore

/// Claude Code «PostToolUse» hook'i: rahbar yordamchisiz ko'p fayl o'qisa, qidiruvni `tokenkuzat:izlovchi` ga berishni
/// eslatadi (additionalContext). Hech qachon bloklamaydi; xato bo'lsa jim chiqadi.
///
/// Skript stdin'ni ilovaning `--delegate-nudge` rejimiga beradi; u sessiya hisobini nudge/<session_id>.json da yuritadi.
enum DelegateNudgeHook {
    static let flag = "--delegate-nudge"
    private static let event = DelegateNudge.event
    private static let marker = "TokenKuzat/delegate-nudge.sh"

    private static var scriptURL: URL {
        RateLimitsReader.defaultDirectory.deletingLastPathComponent().appendingPathComponent("delegate-nudge.sh")
    }

    private static func writeScript() throws {
        let exe = Bundle.main.executablePath ?? CommandLine.arguments[0]
        let script = """
        #!/bin/sh
        # Token Kuzatuv — Claude Code PostToolUse hook (ilova yaratgan): yordamchisiz ko'p o'qishda izlovchini eslatadi
        [ -x "\(exe)" ] || exit 0
        "\(exe)" \(flag) 2>/dev/null
        exit 0

        """
        try FileManager.default.createDirectory(at: scriptURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
    }

    /// Hook faqat Token Kuzatuv plagini (`tokenkuzat:izlovchi`) o'rnatilgan bo'lsa kerak
    static var pluginInstalled: Bool {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/plugins/installed_plugins.json")
        guard let d = try? Data(contentsOf: url) else { return false }
        return String(decoding: d, as: UTF8.self).contains("\"tokenkuzat@")
    }

    /// Yoqilgan va plagin bor bo'lsa — ulaydi, aks holda uzadi; eski holat fayllarini tozalaydi
    static func sync(enabled: Bool) {
        if enabled && pluginInstalled { try? install() } else { try? uninstall() }
        DelegateNudge.cleanup()
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
        // Yozuv bor va matcher shu bo'lsa — tegilmaydi; matcher boshqacha bo'lsa yangilanadi
        let current = entries(s).filter { isOurs($0) }
        if current.count == 1, current[0]["matcher"] as? String == DelegateNudge.matcher { return }
        var hooks = s["hooks"] as? [String: Any] ?? [:]
        var list = entries(s).filter { !isOurs($0) }
        list.append(["matcher": DelegateNudge.matcher, "hooks": [["type": "command", "command": "\"\(scriptURL.path)\""]]])
        hooks[event] = list
        s["hooks"] = hooks
        try StatusLine.backupOnce()
        try StatusLine.writeSettings(s)
    }

    static func uninstall() throws {
        var s = try StatusLine.readSettings()
        defer {
            try? FileManager.default.removeItem(at: scriptURL)
            try? FileManager.default.removeItem(at: DelegateNudge.defaultDirectory)
        }
        // Ishga tushganda har safar chaqirilishi mumkin — ulanmagan bo'lsa settings.json ga tegilmaydi
        guard entries(s).contains(where: { isOurs($0) }) else { return }
        var hooks = s["hooks"] as? [String: Any] ?? [:]
        let list = entries(s).filter { !isOurs($0) }
        if list.isEmpty { hooks.removeValue(forKey: event) } else { hooks[event] = list }
        if hooks.isEmpty { s.removeValue(forKey: "hooks") } else { s["hooks"] = hooks }
        try StatusLine.writeSettings(s)
    }

    /// `--delegate-nudge` rejimi (Claude Code chaqiradi): eslatma kerak bo'lsa — JSON, aks holda hech narsa
    static func runAndExit() -> Never {
        let data = FileHandle.standardInput.readDataToEndOfFile()
        if let out = DelegateNudge.handle(input: data) {
            FileHandle.standardOutput.write(Data(out.utf8))
        }
        exit(0)
    }
}
