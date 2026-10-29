import Foundation

/// Xulosa uchun haqiqiy holat: o'zgargan fayllar joylashgan git repolarining oxirgi commit'i va commit qilinmagan fayllari.
/// Oxirgi javob ish yarmida yozilgan bo'lishi mumkin («o'rnatyapman…») — git esa nima haqiqatda bajarilganini ko'rsatadi.
public enum GitState {
    /// Fayllar joylashgan repo ildizlari (takrorsiz, tartiblangan)
    public static func roots(for paths: [String], fm: FileManager = .default) -> [String] {
        var out = Set<String>()
        for p in paths where p.hasPrefix("/") {
            var dir = URL(fileURLWithPath: p).deletingLastPathComponent()
            while dir.path != "/" {
                if fm.fileExists(atPath: dir.appendingPathComponent(".git").path) { out.insert(dir.path); break }
                dir.deleteLastPathComponent()
            }
        }
        return out.sorted()
    }

    /// Har repo uchun bir-ikki qator: oxirgi commit va commit qilinmagan o'zgarishlar
    public static func lines(for paths: [String]) -> [String] {
        roots(for: paths).prefix(3).compactMap { root in
            guard let head = git(root, ["log", "-1", "--format=%h %s (%cr)"]), !head.isEmpty else { return nil }
            let dirty = (git(root, ["status", "--porcelain"]) ?? "").split(separator: "\n")
            let state = dirty.isEmpty
                ? tr("commit qilinmagan o'zgarish yo'q", "no uncommitted changes")
                : tr("commit qilinmagan: \(dirty.count) ta fayl", "uncommitted: \(dirty.count) file(s)")
                    + " (" + dirty.prefix(5).map { $0.dropFirst(3) }.joined(separator: ", ") + (dirty.count > 5 ? ", …" : "") + ")"
            return "- \(root): " + tr("oxirgi commit", "last commit") + " \(head); \(state)"
        }
    }

    static func git(_ dir: String, _ args: [String]) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        p.arguments = ["-C", dir] + args
        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.nullDevice
        // waitUntilExit() run loop'ni aylantiradi: asosiy oqimda `Lang.with` ichida UI boshqa tilda chizilib qolardi
        let done = DispatchSemaphore(value: 0)
        p.terminationHandler = { _ in done.signal() }
        do { try p.run() } catch { return nil }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        done.wait()
        guard p.terminationStatus == 0 else { return nil }
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
