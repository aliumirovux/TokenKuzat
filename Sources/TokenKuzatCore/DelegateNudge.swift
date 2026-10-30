import Foundation

/// «PostToolUse» hook mantig'i: rahbar yordamchisiz ko'p o'qisa, `tokenkuzat:izlovchi` ga berishni eslatadi.
/// Holat — nudge/<session_id>.json (`{reads, helpers, lastNudgeAt}`); transkript o'qilmaydi, hook tez ishlaydi.
public enum DelegateNudge {
    public static let event = "PostToolUse"
    public static let matcher = "Read|Grep|Glob|Bash|Agent|Task"
    /// Birinchi eslatma shu o'qishda, keyin har shuncha o'qishda
    public static let step = 15

    public static var defaultDirectory: URL {
        RateLimitsReader.defaultDirectory.deletingLastPathComponent().appendingPathComponent("nudge")
    }

    struct State: Codable {
        var reads = 0
        var helpers = 0
        var lastNudgeAt = 0
    }

    /// Hook kiritmasini hisoblaydi. Eslatma kerak bo'lsa — hook chiqishi (JSON), aks holda nil. Hech qachon blok qilmaydi
    public static func handle(input: Data, dir: URL = defaultDirectory, fm: FileManager = .default) -> String? {
        guard let o = (try? JSONSerialization.jsonObject(with: input)) as? [String: Any],
              let sid = o["session_id"] as? String, !sid.isEmpty, !sid.contains("/"),
              let tool = o["tool_name"] as? String else { return nil }
        // Yordamchi ichidagi chaqiruv — rahbarning ishi emas (`agent_type` asosiy sessiyada ham kelishi mumkin: `--agent`)
        if o["agent_id"] != nil { return nil }
        let isHelper = tool == "Agent" || tool == "Task"
        let isRead = ReadCounter.isRead(tool: tool, input: o["tool_input"] as? [String: Any])
        guard isHelper || isRead else { return nil }

        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        // Parallel hook'lar bir faylni yozadi — o'qish-o'zgartirish-yozish qulf ostida; qulf 100 ms ichida olinmasa jim chiqadi
        let fd = open(dir.appendingPathComponent(sid + ".lock").path, O_CREAT | O_RDWR, 0o644)
        guard fd >= 0 else { return nil }
        defer { close(fd) }
        var locked = false
        for _ in 0..<20 {
            if flock(fd, LOCK_EX | LOCK_NB) == 0 { locked = true; break }
            usleep(5_000)
        }
        guard locked else { return nil }
        defer { flock(fd, LOCK_UN) }

        let url = dir.appendingPathComponent(sid + ".json")
        var st = (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(State.self, from: $0) } ?? State()
        let before = st
        if isHelper { st.helpers += 1 } else { st.reads += 1 }
        var message: String?
        if st.helpers == 0, st.reads >= step, st.reads - st.lastNudgeAt >= step {
            st.lastNudgeAt = st.reads / step * step
            message = text(reads: st.reads)
        }
        // Hech narsa kamaymasin (tashqi yozuv bilan birlashtirishda eng kattasi)
        st.helpers = max(st.helpers, before.helpers)
        st.reads = max(st.reads, before.reads)
        st.lastNudgeAt = max(st.lastNudgeAt, before.lastNudgeAt)
        try? JSONEncoder().encode(st).write(to: url, options: .atomic)
        guard let message else { return nil }
        let out: [String: Any] = ["hookSpecificOutput": ["hookEventName": event, "additionalContext": message]]
        guard let d = try? JSONSerialization.data(withJSONObject: out) else { return nil }
        return String(data: d, encoding: .utf8)
    }

    static func text(reads: Int) -> String {
        tr("Token Kuzatuv: bu sessiyada siz \(reads) marta o'zingiz fayl o'qidingiz/qidirdingiz, yordamchi agent hali ishlatilmagan. "
           + "Keyingi qidiruvni `tokenkuzat:izlovchi` ga bering (u faqat xulosa qaytaradi, kontekstingiz kichik qoladi).",
           "Token Kuzatuv: in this session you have read/searched files yourself \(reads) times and no helper agent has been used yet. "
           + "Hand the next search to `tokenkuzat:izlovchi` (it returns only a summary, keeping your context small).")
    }
}

extension DelegateNudge {
    /// Bir haftadan eski holat fayllarini o'chiradi
    public static func cleanup(dir: URL = defaultDirectory, olderThan days: Double = 7, now: Date = Date(), fm: FileManager = .default) {
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        for f in files where f.pathExtension == "json" || f.pathExtension == "lock" {
            let m = (try? f.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? now
            if now.timeIntervalSince(m) > days * 86_400 { try? fm.removeItem(at: f) }
        }
    }
}
