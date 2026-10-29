import Foundation

/// Avtomatik qisqartirish (auto-compact) va avtomatik yangi sessiya to'qnashmasin.
///
/// Claude Code kontekst «auto-compact window» ga yetganda suhbatni o'zi qisqartiradi. Avtomatik yangi sessiya yoqilgan
/// bo'lsa, bu ko'chirishdan oldin sodir bo'lishi mumkin (masalan, oyna chegaradan kichik) — kontekst kichrayadi va
/// ko'chirish hech qachon ishlamaydi. «PreCompact» hook'i shunday sessiyada qisqartirishni bir marta to'xtatadi:
/// javob tugashi bilan ish xulosa bilan yangi sessiyaga ko'chiriladi.
///
/// Xavfsizlik: faqat ishlayotgan sessiyada (jim turgan sessiyani qisqartirish — tegilmaydi) va sessiyada bir marta.
/// Hujjat bo'yicha oldindan qilinadigan qisqartirish to'xtatilsa, suhbat qisqartirilmasdan davom etadi; kontekst
/// haqiqatan to'lib qolsa, ikkinchi urinishga ruxsat beriladi — so'rov xato bilan uzilmaydi.
public enum CompactGuard {
    /// Ilova yozadi: ko'chirilishi kutilayotgan sessiyalar
    public static var guardURL: URL {
        RateLimitsReader.defaultDirectory.deletingLastPathComponent().appendingPathComponent("compact-guard.json")
    }

    /// Hook yozadi: qaysi sessiyada qachon to'xtatildi
    public static var blockedURL: URL {
        RateLimitsReader.defaultDirectory.deletingLastPathComponent().appendingPathComponent("compact-blocked.json")
    }

    /// Transkript shundan yangi o'zgargan bo'lsa — sessiya ishlayapti (aks holda — jim turganda qisqartirish)
    public static let activeWindow: TimeInterval = 120

    public static func loadGuarded(at url: URL = guardURL) -> Set<String> {
        guard let d = try? Data(contentsOf: url) else { return [] }
        return Set((try? JSONDecoder().decode([String].self, from: d)) ?? [])
    }

    /// Bo'sh ro'yxat — fayl o'chiriladi (hook skripti darhol chiqadi)
    public static func saveGuarded(_ ids: Set<String>, at url: URL = guardURL) {
        guard !ids.isEmpty else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(ids.sorted()).write(to: url, options: .atomic)
    }

    /// Sessiya → to'xtatilgan payt (7 kundan eskilari tashlanadi)
    public static func loadBlocked(at url: URL = blockedURL, now: Date = Date()) -> [String: Date] {
        guard let d = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([String: Double].self, from: d) else { return [:] }
        let cutoff = now.timeIntervalSince1970 - 7 * 86400
        return raw.filter { $0.value >= cutoff }.mapValues { Date(timeIntervalSince1970: $0) }
    }

    static func saveBlocked(_ all: [String: Date], at url: URL) {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(all.mapValues(\.timeIntervalSince1970)).write(to: url, options: .atomic)
    }

    /// Qisqartirish to'xtatilsinmi
    public static func shouldBlock(trigger: String?, sessionId: String, guarded: Set<String>, blockedBefore: Bool,
                                   transcriptAge: TimeInterval?) -> Bool {
        guard trigger == "auto", guarded.contains(sessionId), !blockedBefore else { return false }
        guard let age = transcriptAge else { return false }
        return age < activeWindow
    }

    /// PreCompact kiritmasi → Claude Code'ga qaytariladigan JSON (to'xtatish) yoki nil (qisqartirish odatdagidek)
    public static func handlePreCompact(input: Data, guardURL: URL = guardURL, blockedURL: URL = blockedURL,
                                        now: Date = Date()) -> String? {
        guard let o = (try? JSONSerialization.jsonObject(with: input)) as? [String: Any],
              let sid = o["session_id"] as? String, !sid.isEmpty else { return nil }
        let age = (o["transcript_path"] as? String).flatMap { path -> TimeInterval? in
            let mtime = (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date
            return mtime.map { now.timeIntervalSince($0) }
        }
        var blocked = loadBlocked(at: blockedURL, now: now)
        guard shouldBlock(trigger: o["trigger"] as? String, sessionId: sid, guarded: loadGuarded(at: guardURL),
                          blockedBefore: blocked[sid] != nil, transcriptAge: age) else { return nil }
        blocked[sid] = now
        saveBlocked(blocked, at: blockedURL)
        let reason = tr("Token Kuzatuv: avtomatik qisqartirish o'rniga javob tugagach ish xulosa bilan yangi sessiyaga ko'chiriladi.",
                        "Token Kuzatuv: instead of auto-compacting, the work moves to a new session with a summary when this reply ends.")
        let out: [String: Any] = ["decision": "block", "reason": reason]
        return (try? JSONSerialization.data(withJSONObject: out)).flatMap { String(data: $0, encoding: .utf8) }
    }
}
