import Foundation

/// Ilova tili. Sukut — Mac tiliga qarab: inglizcha bo'lsa English, aks holda O'zbekcha.
public enum AppLanguage: String, CaseIterable, Identifiable {
    case system, uz, en
    public var id: String { rawValue }

    /// Tanlov ro'yxatida har doim o'z tilida yoziladi
    public var title: String {
        switch self {
        case .system: return tr("Tizim tili", "System language")
        case .uz: return "O'zbekcha"
        case .en: return "English"
        }
    }
}

/// Joriy til. Ilova ochilganda va Sozlamalarda tanlanganda `Lang.load()` / `Lang.set(_:)` bilan yangilanadi;
/// testlar va yuklanmagan holatda — o'zbekcha.
public enum Lang {
    /// UserDefaults kaliti (@AppStorage ham shu nomdan foydalanadi)
    public static let prefKey = "language"
    /// Ilova tili. `with(english:)` faqat o'z oqimida almashtiradi — fondagi matn yasash UI'ga til aralashtirmasin
    public static var isEnglish: Bool {
        (Thread.current.threadDictionary[overrideKey] as? Bool) ?? appEnglish
    }
    nonisolated(unsafe) private static var appEnglish = false
    private static let overrideKey = "uz.ali.tokenkuzat.lang.override"

    public static var choice: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: prefKey) ?? "") ?? .system
    }

    public static func load() { appEnglish = resolve(choice) }

    public static func set(_ c: AppLanguage) {
        appEnglish = resolve(c)
        UserDefaults.standard.set(c.rawValue, forKey: prefKey)
    }

    public static func resolve(_ c: AppLanguage, preferred: [String] = Locale.preferredLanguages) -> Bool {
        switch c {
        case .uz: return false
        case .en: return true
        case .system: return preferred.first?.hasPrefix("en") ?? false
        }
    }

    /// `body` ichida `tr(...)` berilgan tilda qaytadi (Claude'ga yuboriladigan matnlar uchun — ilova tili emas, suhbat tili)
    public static func with<T>(english: Bool, _ body: () -> T) -> T {
        let dict = Thread.current.threadDictionary
        let saved = dict[overrideKey]
        dict[overrideKey] = english
        defer { dict[overrideKey] = saved }
        return body()
    }

    /// Foydalanuvchi xabarlari qaysi tilda: true — inglizcha, false — o'zbekcha, nil — aniqlab bo'lmadi
    public static func detectEnglish(_ texts: [String]) -> Bool? {
        let uzWords: Set<String> = ["va", "bu", "shu", "nima", "uchun", "kerak", "qil", "qilgin", "yana", "ha", "yo'q", "emas",
                                    "bilan", "qanday", "endi", "hozir", "bor", "edi", "ham", "lekin", "qilib", "bo'yicha", "qani", "nega"]
        let enWords: Set<String> = ["the", "and", "is", "to", "of", "it", "this", "that", "what", "please", "can", "you",
                                    "with", "for", "do", "make", "how", "why", "not", "add", "fix"]
        var uz = 0, en = 0
        for text in texts {
            let lower = text.lowercased()
                .replacingOccurrences(of: "ʻ", with: "'").replacingOccurrences(of: "’", with: "'")
            // o', g' va kirill o'zbek harflari — deyarli aniq belgi
            if lower.range(of: #"[ўқғҳ]|[og]'[a-z]"#, options: .regularExpression) != nil { uz += 2 }
            for w in lower.split(whereSeparator: { !$0.isLetter && $0 != "'" }) {
                if uzWords.contains(String(w)) { uz += 1 } else if enWords.contains(String(w)) { en += 1 }
            }
        }
        guard uz + en >= 2, uz != en else { return nil }
        return en > uz
    }

    /// Sanalar uchun locale
    public static var locale: Locale { Locale(identifier: isEnglish ? "en_US" : "uz_Latn_UZ") }
}

/// Ikki tilli matn — o'zbekcha va inglizcha yonma-yon: `tr("Bugun", "Today")`.
/// Yangi matn qo'shganda ikkalasini shu yerda yozing; satr ichidagi qiymatlar (`\(n)`) odatdagidek ishlaydi.
@inline(__always)
public func tr(_ uz: String, _ en: String) -> String { Lang.isEnglish ? en : uz }

/// Agent javob yozib bo'lganini bildiruvchi `lastAction` — til almashgandan keyin eski tildagi yozuv ham tanilsin
public func isAnsweredAction(_ s: String?) -> Bool { s == "Javob yozdi" || s == "Answered" }
