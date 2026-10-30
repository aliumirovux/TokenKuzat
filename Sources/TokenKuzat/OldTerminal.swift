import Foundation
import Darwin
import TokenKuzatCore

/// Ish yangi sessiyaga ko'chgach, eski sessiyaning Terminal oynasini yopish.
///
/// Status line har yangilanishda sessiya qaysi `claude` jarayonida va qaysi terminalda (tty) ishlayotganini yozib boradi.
/// Yangi sessiya Terminal'da ochilgach, uning skripti fonda `--close-terminal <id>` ni chaqiradi: eski `claude` to'xtatiladi,
/// keyin shu tty dagi Terminal oynasi yopiladi. Faqat Terminal.app — iTerm, VS Code va Claude ilovasidagi sessiyalarga tegilmaydi
enum OldTerminal {
    static let flag = "--close-terminal"

    private static var folder: URL {
        ProjectSavingsHistory.defaultURL.deletingLastPathComponent().appendingPathComponent("terminals")
    }

    private static func fileURL(_ session: String) -> URL? {
        session.isEmpty || session.contains("/") ? nil : folder.appendingPathComponent(session)
    }

    /// Status line'dan: shu jarayonning ajdodlari ichidan `claude` ni topib, «pid tty» ni yozadi
    static func record(session: String) {
        guard let url = fileURL(session), let p = claudeAncestor(), let tty = tty(of: p) else { return }
        let line = "\(p) \(tty)"
        if (try? String(contentsOf: url, encoding: .utf8)) == line { return }
        let fm = FileManager.default
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        try? line.write(to: url, atomically: true, encoding: .utf8)
        // Tugagan sessiyalarning yozuvlari to'planib qolmasin
        let old = Date().addingTimeInterval(-3 * 86400)
        for f in (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        where ((try? f.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantFuture) < old {
            try? fm.removeItem(at: f)
        }
    }

    /// Yangi sessiya skriptiga qo'shiladigan qator: `claude` ishga tushgach, fonda eski oynani yopadi
    static func scriptLine(closing session: String?) -> String {
        guard let session, fileURL(session) != nil, let exe = Bundle.main.executablePath,
              UserDefaults.standard.bool(forKey: Pref.closeOldTerminal) else { return "" }
        func quote(_ s: String) -> String { "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }
        return "( sleep 3; \(quote(exe)) \(flag) \(quote(session)) ) >/dev/null 2>&1 &!\n"
    }

    static func runAndExit() -> Never {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: flag), i + 1 < args.count { close(session: args[i + 1]) }
        exit(0)
    }

    private static func close(session: String) {
        guard let url = fileURL(session), let line = try? String(contentsOf: url, encoding: .utf8) else { return }
        let parts = line.split(separator: " ")
        guard parts.count == 2, let pid = pid_t(parts[0]) else { return }
        let tty = String(parts[1])
        // Jarayon hali o'sha `claude` va o'sha terminalda — pid boshqa dasturga o'tib ketgan bo'lmasin
        guard isClaude(pid), self.tty(of: pid) == tty else { try? FileManager.default.removeItem(at: url); return }
        // Avval oyna Terminal.app'da ekani tekshiriladi: topilmasa (iTerm, VS Code…) — hech narsa to'xtatilmaydi
        guard osascript(find(tty)) == "found" else { return }
        kill(pid, SIGTERM)
        for _ in 0..<30 where kill(pid, 0) == 0 { usleep(100_000) }
        guard kill(pid, 0) != 0 else { return }
        try? FileManager.default.removeItem(at: url)
        _ = osascript(closeScript(tty))
    }

    // MARK: Terminal.app

    private static func find(_ tty: String) -> String {
        """
        if application "Terminal" is not running then return "none"
        tell application "Terminal"
            repeat with w in windows
                repeat with t in tabs of w
                    if tty of t is "/dev/\(tty)" then return "found"
                end repeat
            end repeat
        end tell
        return "none"
        """
    }

    /// Bitta tabli oyna yopiladi; bir nechta tab bo'lsa — faqat shu tabdagi qobiq chiqadi
    private static func closeScript(_ tty: String) -> String {
        """
        tell application "Terminal"
            repeat with w in windows
                repeat with t in tabs of w
                    if tty of t is "/dev/\(tty)" then
                        if (count of tabs of w) is 1 then
                            close w
                        else
                            try
                                do script "exit" in t
                            end try
                        end if
                        return
                    end if
                end repeat
            end repeat
        end tell
        """
    }

    private static func osascript(_ source: String) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", source]
        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return nil }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { return nil }
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Jarayonlar

    private static func info(_ pid: pid_t) -> kinfo_proc? {
        var k = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, 4, &k, &size, nil, 0) == 0, size > 0 else { return nil }
        return k
    }

    private static func name(_ pid: pid_t) -> String {
        var buf = [CChar](repeating: 0, count: 256)
        return proc_name(pid, &buf, UInt32(buf.count)) > 0 ? String(cString: buf) : ""
    }

    private static func path(_ pid: pid_t) -> String {
        var buf = [CChar](repeating: 0, count: Int(4 * MAXPATHLEN))
        return proc_pidpath(pid, &buf, UInt32(buf.count)) > 0 ? String(cString: buf) : ""
    }

    /// Yangi o'rnatishda `claude` fayli versiya bilan nomlanadi (`~/.local/share/claude/versions/2.1.314`) —
    /// jarayon nomida «claude» yo'q, shuning uchun to'liq yo'l ham tekshiriladi
    private static func isClaude(_ pid: pid_t) -> Bool {
        name(pid).lowercased().contains("claude") || path(pid).lowercased().contains("/claude/")
    }

    /// status line → sh → (sh -c) → claude: bir necha qadam yuqoriga qaraladi
    private static func claudeAncestor() -> pid_t? {
        var p = getppid()
        for _ in 0..<5 {
            if p <= 1 { return nil }
            if isClaude(p) { return p }
            guard let k = info(p) else { return nil }
            p = k.kp_eproc.e_ppid
        }
        return nil
    }

    private static func tty(of pid: pid_t) -> String? {
        guard let k = info(pid), k.kp_eproc.e_tdev != -1, let n = devname(k.kp_eproc.e_tdev, S_IFCHR) else { return nil }
        let s = String(cString: n)
        return s.hasPrefix("tty") ? s : nil
    }
}
