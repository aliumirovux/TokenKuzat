import Foundation

// Claude yozadigan ko'chirish eslatmasi: kontekst chegaraga yaqinlashganda UserPromptSubmit hook'i Claude'dan javob
// oxiriga yashirin eslatma qo'shishni so'raydi. Ish nima, nima qilindi, nima qoldi — buni Claude o'zi aniqroq biladi;
// xulosa shu eslatmaga tayanadi, mexanik qismlar esa zaxira bo'lib qoladi.
// Har qator — Markdown havola ta'rifi («[tk-handoff]: <…>»): Markdown uni chizmaydi. HTML izohni (<!-- … -->) esa
// Claude ilovasi oddiy matn qilib ko'rsatadi — u faqat eski javoblardan o'qiladi.

public enum HandoffNote {
    public static let prefix = "[tk-handoff]: "
    static let legacyOpen = "<!-- tk-handoff"
    static let legacyClose = "-->"

    /// Eslatma shu kontekstdan boshlab so'raladi: chegaradan 15% (kamida 20K) oldin — bitta javob kontekstni
    /// ancha o'stirishi mumkin, chegarani kesib o'tgan javobda eslatma allaqachon bo'lsin
    public static func askFrom(thresholdK: Double) -> Int {
        let t = Int(thresholdK * 1000)
        return t - max(20_000, t * 15 / 100)
    }

    /// Claude'ga beriladigan ko'rsatma (foydalanuvchi ko'rmaydi)
    public static func instruction(context: Int, english: Bool) -> String {
        Lang.with(english: english) {
            tr("Token Kuzatuv: bu sessiya konteksti katta (\(Fmt.tokens(context))) — ish tez orada yangi sessiyaga ko'chiriladi. "
               + "Javobingning eng oxiriga, bo'sh qatordan keyin, foydalanuvchiga ko'rinmaydigan eslatma qo'sh — yangi sessiya shundan davom etadi. "
               + "Har qator aynan «\(prefix)<» bilan boshlanib «>» bilan tugasin (Markdown uni ko'rsatmaydi), ichida < va > belgilari bo'lmasin:\n"
               + "\(prefix)<Ish: asosiy ish, bitta qator>\n\(prefix)<Bajarildi: nima qilindi, nima commit/push qilindi>\n"
               + "\(prefix)<Qolgan: tugallanmagan qadamlar>\n\(prefix)<Kutilayotgan qaror: foydalanuvchidan nima kutilyapti; yo'q bo'lsa — yo'q>\n"
               + "\(prefix)<Ochiq takliflar: butun suhbatda muhokama qilingan, lekin hali qilinmagan takliflar, rejalar, ro'yxat bandlari — "
               + "har biri qisqa, «; » bilan; yo'q bo'lsa — yo'q>\n"
               + "\(prefix)<Muhim: yangi sessiya bilishi shart bo'lgan qaror, cheklov, fayl yoki buyruq>\n"
               + "12 qatorgacha, aniq va qisqa. Javobingning qolgan qismini o'zgartirma, eslatma haqida gapirma.",
               "Token Kuzatuv: this session's context is large (\(Fmt.tokens(context))) — the work will move to a new session soon. "
               + "At the very end of your reply, after a blank line, add a note the user won't see; the new session continues from it. "
               + "Every line must start with exactly «\(prefix)<» and end with «>» (Markdown doesn't render it), with no < or > inside:\n"
               + "\(prefix)<Task: the main task, one line>\n\(prefix)<Done: what was done, what was committed/pushed>\n"
               + "\(prefix)<Remaining: unfinished steps>\n\(prefix)<Pending decision: what the user needs to decide; none if nothing>\n"
               + "\(prefix)<Open proposals: proposals, plans or list items discussed anywhere in the conversation but not done yet — "
               + "each short, separated by «; »; none if nothing>\n"
               + "\(prefix)<Important: decisions, constraints, files or commands the new session must know>\n"
               + "Up to 12 lines, specific and short. Don't change the rest of your reply or mention the note.")
        }
    }

    /// Javobdagi oxirgi eslatma: uning matni va eslatmasiz javob. Eslatma bo'lmasa — nil
    public static func extract(from reply: String) -> (note: String, rest: String)? {
        var lines = reply.components(separatedBy: "\n")
        // Oxirgi eslatma qatorlari to'plami (oralarida bo'sh qator bo'lishi mumkin)
        guard let last = lines.lastIndex(where: { isNoteLine($0) }) else { return extractLegacy(from: reply) }
        var first = last
        while first > 0, isNoteLine(lines[first - 1]) || lines[first - 1].trimmingCharacters(in: .whitespaces).isEmpty { first -= 1 }
        let note = lines[first...last].filter(isNoteLine).map(noteText).filter { !$0.isEmpty }.joined(separator: "\n")
        guard !note.isEmpty else { return nil }
        lines.removeSubrange(first...last)
        return (note, lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static func isNoteLine(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).hasPrefix(prefix)
    }

    static func noteText(_ line: String) -> String {
        var t = Substring(line.trimmingCharacters(in: .whitespaces).dropFirst(prefix.count))
        if t.hasPrefix("<") { t = t.dropFirst() }
        if t.hasSuffix(">") { t = t.dropLast() }
        return t.trimmingCharacters(in: .whitespaces)
    }

    /// Eski javoblardagi <!-- tk-handoff … --> izohi
    static func extractLegacy(from reply: String) -> (note: String, rest: String)? {
        guard let start = reply.range(of: legacyOpen, options: .backwards) else { return nil }
        let after = reply[start.upperBound...]
        let end = after.range(of: legacyClose)
        let note = String(after[..<(end?.lowerBound ?? after.endIndex)]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty else { return nil }
        let rest = String(reply[..<start.lowerBound]) + (end.map { String(after[$0.upperBound...]) } ?? "")
        return (note, rest.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Eslatmadagi maydon («Ish:» / «Task:»), bo'sh bo'lsa — nil
    public static func field(_ note: String, _ names: [String]) -> String? {
        for line in note.components(separatedBy: "\n") {
            let l = line.trimmingCharacters(in: .whitespaces)
            for n in names where l.hasPrefix(n + ":") {
                let v = l.dropFirst(n.count + 1).trimmingCharacters(in: .whitespaces)
                if !v.isEmpty { return v }
            }
        }
        return nil
    }
}

/// Eslatma so'raladigan sessiyalar: ilova kontekstni kuzatib yozadi, hook o'qiydi. Fayl bo'lmasa hook ilovani ishga tushirmaydi
public enum NoteRequestStore {
    public struct Request: Codable, Equatable, Sendable {
        public let context: Int
        public let english: Bool
        public init(context: Int, english: Bool) {
            self.context = context
            self.english = english
        }
    }

    public static var defaultURL: URL {
        RateLimitsReader.defaultDirectory.deletingLastPathComponent().appendingPathComponent("handoff-note-wanted.json")
    }

    public static func load(at url: URL = defaultURL) -> [String: Request] {
        guard let d = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: Request].self, from: d)) ?? [:]
    }

    /// Bo'sh ro'yxat — fayl o'chiriladi
    public static func save(_ all: [String: Request], at url: URL = defaultURL) {
        guard !all.isEmpty else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(all).write(to: url, options: .atomic)
    }

    /// UserPromptSubmit kiritmasi → Claude Code'ga qaytariladigan JSON (ko'rsatma kontekstga qo'shiladi) yoki nil
    public static func handlePrompt(input: Data, at url: URL = defaultURL) -> String? {
        guard let o = (try? JSONSerialization.jsonObject(with: input)) as? [String: Any],
              let sid = o["session_id"] as? String, let r = load(at: url)[sid] else { return nil }
        let out: [String: Any] = ["hookSpecificOutput": ["hookEventName": "UserPromptSubmit",
                                                         "additionalContext": HandoffNote.instruction(context: r.context, english: r.english)]]
        guard let d = try? JSONSerialization.data(withJSONObject: out) else { return nil }
        return String(data: d, encoding: .utf8)
    }
}
