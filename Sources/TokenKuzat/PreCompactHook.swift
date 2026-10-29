import Foundation
import AppKit
import TokenKuzatCore

/// Claude Code «PreCompact» hook'i (faqat avtomatik qisqartirish): avtomatik yangi sessiya kutilayotgan sessiyada
/// qisqartirishni bir marta to'xtatadi — javob tugagach ish xulosa bilan yangi sessiyaga ko'chiriladi (`CompactGuard`).
///
/// Skript avval ro'yxat fayli borligini tekshiradi — yo'q bo'lsa darhol chiqadi (qisqartirish odatdagidek).
enum PreCompactHook {
    static let flag = "--pre-compact"
    private static let event = "PreCompact"
    private static let marker = "TokenKuzat/pre-compact.sh"

    private static var scriptURL: URL {
        RateLimitsReader.defaultDirectory.deletingLastPathComponent().appendingPathComponent("pre-compact.sh")
    }

    private static func writeScript() throws {
        let exe = Bundle.main.executablePath ?? CommandLine.arguments[0]
        let script = """
        #!/bin/sh
        # Token Kuzatuv — Claude Code PreCompact hook (ilova yaratgan): faqat avtomatik ko'chirish kutilayotgan sessiyada ishlaydi
        [ -f "\(CompactGuard.guardURL.path)" ] || exit 0
        [ -x "\(exe)" ] || exit 0
        "\(exe)" \(flag) 2>/dev/null
        exit 0

        """
        try FileManager.default.createDirectory(at: scriptURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
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
        list.append(["matcher": "auto", "hooks": [["type": "command", "command": "\"\(scriptURL.path)\""]]])
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
        CompactGuard.saveGuarded([])
    }

    /// `--pre-compact` rejimi (Claude Code chaqiradi): to'xtatish kerak bo'lsa — JSON, aks holda hech narsa
    static func runAndExit() -> Never {
        let data = FileHandle.standardInput.readDataToEndOfFile()
        Pref.register()
        // Ilova yopiq bo'lsa yangi sessiyani ochadigan yo'q — qisqartirish to'xtatilmaydi
        if UserDefaults.standard.bool(forKey: Pref.autoHandoff), appRunning, let out = CompactGuard.handlePreCompact(input: data) {
            FileHandle.standardOutput.write(Data(out.utf8))
        }
        exit(0)
    }

    private static var appRunning: Bool {
        guard let id = Bundle.main.bundleIdentifier else { return false }
        let me = ProcessInfo.processInfo.processIdentifier
        return NSRunningApplication.runningApplications(withBundleIdentifier: id).contains { $0.processIdentifier != me }
    }
}
