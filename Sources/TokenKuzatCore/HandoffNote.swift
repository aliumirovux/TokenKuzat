import Foundation

// Claude yozadigan ko'chirish eslatmasi: kontekst chegaraga yaqinlashganda UserPromptSubmit hook'i Claude'dan javob
// oxiriga yashirin izoh (<!-- tk-handoff … -->) qo'shishni so'raydi. Ish nima, nima qilindi, nima qoldi — buni
// Claude o'zi aniqroq biladi; xulosa shu izohga tayanadi, mexanik qismlar esa zaxira bo'lib qoladi.

public enum HandoffNote {
    public static let open = "<!-- tk-handoff"
    public static let close = "-->"

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
               + "Javobingning eng oxiriga foydalanuvchiga ko'rinmaydigan izoh qo'sh, yangi sessiya shundan davom etadi:\n"
               + "\(open)\nIsh: <asosiy ish, bitta qator>\nBajarildi: <nima qilindi, nima commit/push qilindi>\n"
               + "Qolgan: <tugallanmagan qadamlar>\nKutilayotgan qaror: <foydalanuvchidan nima kutilyapti; yo'q bo'lsa — yo'q>\n"
               + "Muhim: <yangi sessiya bilishi shart bo'lgan qaror, cheklov, fayl yoki buyruq>\n\(close)\n"
               + "10 qatorgacha, aniq va qisqa. Javobingning qolgan qismini o'zgartirma, izoh haqida gapirma.",
               "Token Kuzatuv: this session's context is large (\(Fmt.tokens(context))) — the work will move to a new session soon. "
               + "At the very end of your reply, add a comment the user won't see; the new session continues from it:\n"
               + "\(open)\nTask: <the main task, one line>\nDone: <what was done, what was committed/pushed>\n"
               + "Remaining: <unfinished steps>\nPending decision: <what the user needs to decide; none if nothing>\n"
               + "Important: <decisions, constraints, files or commands the new session must know>\n\(close)\n"
               + "Up to 10 lines, specific and short. Don't change the rest of your reply or mention the comment.")
        }
    }

    /// Javobdagi oxirgi eslatma: uning matni va eslatmasiz javob. Eslatma bo'lmasa — nil
    public static func extract(from reply: String) -> (note: String, rest: String)? {
        guard let start = reply.range(of: open, options: .backwards) else { return nil }
        let after = reply[start.upperBound...]
        let end = after.range(of: close)
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
