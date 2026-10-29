import Foundation

/// Avtomatik yangi sessiya: kontekst chegaradan oshgan sessiyada Claude javobini tugatgan zahoti
/// xulosa saqlanadi va yangi sessiya ochiladi. Ish o'rtasida hech qachon — faqat ishlayotgan holatdan
/// bo'sh holatga o'tganda; har sessiyada bir marta.
public enum AutoHandoffRule {
    public static let defaultThresholdK: Double = 200
    public static let thresholdOptionsK: [Double] = [150, 200, 300, 500]

    /// Ko'chirilgandan keyin ham eski sessiyada davom etilsa — kontekst yana shuncha o'sganda qayta ko'chiriladi
    public static let repeatStep = 100_000

    /// Sessiya «allaqachon ko'chirilgan» hisoblanadimi: oxirgi ko'chirishdan beri kontekst `repeatStep` dan kam o'sgan.
    /// Ko'chirish paytidagi kontekst noma'lum bo'lsa (eski yozuvlar) — chegara asos qilinadi
    public static func alreadyDone(doneAt: Int?, known: Bool, context: Int, thresholdK: Double) -> Bool {
        guard known else { return false }
        let base = doneAt ?? Int(thresholdK * 1000)
        return context < base + repeatStep
    }

    /// Shu yangilanishda yangi sessiya ochilsinmi
    public static func shouldTrigger(previous: AgentState?, state: AgentState, context: Int, thresholdK: Double,
                                     waitingPermission: Bool, alreadyDone: Bool) -> Bool {
        guard !alreadyDone, !waitingPermission, state == .idle else { return false }
        guard let previous, previous != .idle else { return false }
        return Double(context) >= thresholdK * 1000
    }

    /// Yangi sessiyaning birinchi xabari — o'zi yuboriladi: nima uchun ko'chirilgani, xulosa va nima qilish kerakligi.
    /// Ish tugagan bo'lsa — yangi ish boshlamaydi, holatni aytib kutadi
    public static func firstMessage(summary: String, previousContext: Int, english: Bool? = nil, limit: Int = 8000) -> String {
        if let english { return Lang.with(english: english) { firstMessage(summary: summary, previousContext: previousContext, limit: limit) } }
        let head = tr("Token Kuzatuv: oldingi sessiya konteksti \(Fmt.tokens(previousContext)) ga yetgani uchun ish shu yangi sessiyaga ko'chirildi "
                      + "(har javobda butun suhbat qayta o'qilmasin). Quyidagi xulosaga tayan. Tugallanmagan ish bo'lsa — davom ettir. "
                      + "Ish tugagan yoki keyingi qadam men qaror qilishim kerak bo'lsa — hech narsa boshlamay, 2–3 jumlada holatni ayt va kut.",
                      "Token Kuzatuv: the previous session's context reached \(Fmt.tokens(previousContext)), so the work moved to this new session "
                      + "(so the whole conversation isn't re-read on every reply). Rely on the summary below. If there's unfinished work, continue it. "
                      + "If the work is done or the next step is my decision, don't start anything — state where things stand in 2–3 sentences and wait.")
        // Xulosa «↪ Loyiha — ish» qatori bilan boshlansa — u xabarning eng boshiga chiqadi (sessiya nomi shundan yasaladi)
        var headline: String?
        var rest = summary
        if summary.hasPrefix("↪ ") {
            let parts = summary.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
            headline = String(parts[0])
            rest = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .newlines) : ""
        }
        let body = rest.count > limit ? String(rest.prefix(limit)) + "…" : rest
        return (headline.map { $0 + "\n\n" } ?? "") + head + "\n\n" + body
    }

    /// Xulosaning birinchi qatori: «↪ TokenKuzat — Ofis paneli»
    public static func headline(project: String?, task: String?) -> String {
        let parts = [project, task].compactMap { $0 }.filter { !$0.isEmpty }
        return "↪ " + (parts.isEmpty ? tr("Oldingi sessiya davomi", "Continued session") : parts.joined(separator: " — "))
    }

    /// Bundan qisqa so'rov («Ha, chiqar», «Ha, push qil») vazifa nomi bo'lolmaydi
    public static let meaningfulLength = 15

    /// Token Kuzatuv yuborgan ko'chirish xabari (birinchi qatori ham) — foydalanuvchi so'rovi emas
    public static func isHandoffPrompt(_ prompt: String) -> Bool {
        prompt.hasPrefix("Token Kuzatuv:") || prompt.hasPrefix("↪ ")
    }
}

extension AutoHandoffRule {
    /// Ko'chirilgan sessiyaning birinchi xabari — tizim matni, sarlavha bo'lib ko'rinmasin.
    /// Xulosadagi so'nggi ma'noli vazifa olinadi («Ha, chiqar» kabi qisqa javoblar o'tkazib yuboriladi).
    /// Ko'chirilgan sessiya bo'lmasa — nil
    public static func continuationTitle(from prompt: String) -> String? {
        let lines = prompt.components(separatedBy: "\n")
        // Yangi usul: «↪ Loyiha — ish» qatori, keyin tizim matni. Loyiha nomi alohida ko'rinadi — faqat ish olinadi
        if let first = lines.first, first.hasPrefix("↪ "), lines.count > 2, lines[2].hasPrefix("Token Kuzatuv:") {
            let name = String(first.dropFirst(2))
            let task = name.range(of: " — ").map { String(name[$0.upperBound...]) } ?? name
            return task.isEmpty ? tr("Oldingi sessiya davomi", "Continued session") : task
        }
        guard prompt.hasPrefix("Token Kuzatuv:") else { return nil }
        guard let head = lines.firstIndex(where: { $0 == "So'nggi vazifalar:" || $0 == "Recent tasks:" }) else {
            return tr("Oldingi sessiya davomi", "Continued session")
        }
        let tasks = lines[(head + 1)...].prefix { $0.hasPrefix("- #") }.map { line -> String in
            guard let colon = line.range(of: ": ") else { return line }
            return String(line[colon.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
        let pick = tasks.last { $0.count >= meaningfulLength } ?? tasks.last
        return pick.flatMap { $0.isEmpty ? nil : $0 } ?? tr("Oldingi sessiya davomi", "Continued session")
    }
}

/// Yangi sessiya qayerda ochiladi
public enum AutoHandoffTarget: String, CaseIterable, Identifiable, Sendable {
    case app, terminal
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .app: return tr("Claude ilovasida", "In the Claude app")
        case .terminal: return tr("Terminalda (claude)", "In Terminal (claude)")
        }
    }
}
