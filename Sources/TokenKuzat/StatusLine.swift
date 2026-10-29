import Foundation
import TokenKuzatCore

/// Claude Code status line'iga ulanish.
///
/// Claude Code har yangilanishda `statusLine.command` ni ishga tushiradi va stdin'ga sessiya JSON'ini beradi.
/// Biz o'z ilovamizni `--statusline` bilan qo'yamiz: u JSON'ni ~/Library/Application Support/TokenKuzat/statusline
/// ga yozadi va status line uchun qisqa satr chiqaradi. Avval boshqa status line bo'lgan bo'lsa — u saqlanadi,
/// chaqiriladi (uning chiqishi ko'rsatiladi) va uzilganda qaytariladi.
enum StatusLine {
    static let flag = "--statusline"

    static var settingsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/settings.json")
    }

    private static var supportDir: URL { RateLimitsReader.defaultDirectory }
    private static var previousURL: URL { supportDir.appendingPathComponent("previous-statusline.json") }

    /// Status line skripti: ma'lumotni bir zumda faylga yozadi (Claude Code sekin skriptni to'xtatib qo'yishi mumkin),
    /// keyin satrni ilova chiqaradi
    private static var scriptURL: URL { supportDir.deletingLastPathComponent().appendingPathComponent("statusline.sh") }

    static var command: String { "\"\(scriptURL.path)\"" }

    private static func writeScript() throws {
        let exe = Bundle.main.executablePath ?? CommandLine.arguments[0]
        let script = """
        #!/bin/sh
        # Token Kuzatuv — Claude Code status line (ilova yaratgan; Sozlamalar → «Uzish» bilan olib tashlanadi)
        D="$HOME/Library/Application Support/TokenKuzat/statusline"
        mkdir -p "$D"
        T="$D/.in.$$"
        cat > "$T"
        cp "$T" "$D/latest.json.tmp" && mv -f "$D/latest.json.tmp" "$D/latest.json"
        if [ -x "\(exe)" ]; then "\(exe)" \(flag) < "$T"; else echo "Token Kuzatuv"; fi
        rm -f "$T"

        """
        try FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
    }

    private static func isOurs(_ command: String?) -> Bool {
        guard let c = command else { return false }
        return c.contains("TokenKuzat/statusline.sh") || c.contains(flag)
    }

    // MARK: - Holat

    static var isInstalled: Bool { isOurs(currentStatusLine()?["command"] as? String) }

    /// Oxirgi ma'lumot qachon kelgan — ulangan, lekin Claude Code hali ishlatilmagan holatni ajratish uchun
    static var lastUpdate: Date? {
        (try? supportDir.appendingPathComponent("latest.json").resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate
    }

    // MARK: - Ulash / uzish

    enum InstallError: LocalizedError {
        case unreadable
        var errorDescription: String? { tr("~/.claude/settings.json ni o'qib bo'lmadi (JSON buzuq bo'lishi mumkin).", "Couldn't read ~/.claude/settings.json (the JSON may be broken).") }
    }

    static func install() throws {
        var settings = try readSettings()
        if let existing = settings["statusLine"] as? [String: Any], !isOurs(existing["command"] as? String) {
            // Foydalanuvchining o'z status line'i — saqlab qo'yamiz va biznikidan chaqiramiz
            try FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
            try JSONSerialization.data(withJSONObject: existing, options: [.prettyPrinted]).write(to: previousURL)
        }
        try writeScript()
        settings["statusLine"] = ["type": "command", "command": command]
        try backupOnce()
        try writeSettings(settings)
    }

    static func uninstall() throws {
        var settings = try readSettings()
        if let d = try? Data(contentsOf: previousURL),
           let prev = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] {
            settings["statusLine"] = prev
            try? FileManager.default.removeItem(at: previousURL)
        } else {
            settings.removeValue(forKey: "statusLine")
        }
        try writeSettings(settings)
        try? FileManager.default.removeItem(at: scriptURL)
    }

    private static func currentStatusLine() -> [String: Any]? {
        (try? readSettings())?["statusLine"] as? [String: Any]
    }

    static func readSettings() throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else { return [:] }
        let d = try Data(contentsOf: settingsURL)
        if d.isEmpty { return [:] }
        guard let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] else { throw InstallError.unreadable }
        return o
    }

    static func writeSettings(_ s: [String: Any]) throws {
        try FileManager.default.createDirectory(at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let d = try JSONSerialization.data(withJSONObject: s, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try d.write(to: settingsURL, options: .atomic)
    }

    /// Birinchi ulanishda settings.json nusxasi: settings.json.tokenkuzat-backup
    static func backupOnce() throws {
        let backup = settingsURL.appendingPathExtension("tokenkuzat-backup")
        guard FileManager.default.fileExists(atPath: settingsURL.path),
              !FileManager.default.fileExists(atPath: backup.path) else { return }
        try FileManager.default.copyItem(at: settingsURL, to: backup)
    }

    // MARK: - `--statusline` rejimi (Claude Code chaqiradi)

    /// Ilova oynasiz ishlaydi: JSON'ni yozadi, satr chiqaradi va darhol chiqadi.
    static func runAndExit() -> Never {
        let data = FileHandle.standardInput.readDataToEndOfFile()
        let parsed = StatusLinePayload.parse(data)
        let fm = FileManager.default
        let sessions = supportDir.appendingPathComponent("sessions")
        try? fm.createDirectory(at: sessions, withIntermediateDirectories: true)
        if parsed != nil {
            try? data.write(to: supportDir.appendingPathComponent("latest.json"), options: .atomic)
            if let id = parsed?.sessionId, !id.contains("/") {
                try? data.write(to: sessions.appendingPathComponent(id + ".json"), options: .atomic)
                OldTerminal.record(session: id)
            }
        }

        if let prev = previousCommand() {
            // Foydalanuvchining oldingi status line'i — o'shaning chiqishi ko'rsatiladi
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/sh")
            p.arguments = ["-c", prev]
            let input = Pipe()
            p.standardInput = input
            p.standardOutput = FileHandle.standardOutput
            p.standardError = FileHandle.standardError
            if (try? p.run()) != nil {
                input.fileHandleForWriting.write(data)
                try? input.fileHandleForWriting.close()
                p.waitUntilExit()
                exit(p.terminationStatus)
            }
        }
        print(summary(parsed))
        exit(0)
    }

    private static func previousCommand() -> String? {
        guard let d = try? Data(contentsOf: previousURL),
              let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] else { return nil }
        return o["command"] as? String
    }

    /// «5 soat 34% ↻16:40 · hafta 61% · $1,23»
    static func summary(_ p: StatusLinePayload.Parsed?) -> String {
        guard let p else { return "Token Kuzatuv" }
        var parts: [String] = []
        if let w = p.fiveHour {
            parts.append(tr("5 soat", "5h") + " \(Int(w.usedPercentage.rounded()))% ↻\(Fmt.hourMinute.string(from: w.resetsAt))")
        }
        if let w = p.sevenDay { parts.append(tr("hafta", "week") + " \(Int(w.usedPercentage.rounded()))%") }
        if let c = p.costUSD { parts.append(Fmt.usd(c)) }
        return parts.isEmpty ? "Token Kuzatuv" : parts.joined(separator: " · ")
    }
}
