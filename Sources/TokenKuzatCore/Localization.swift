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
    public private(set) static var isEnglish = false

    public static var choice: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: prefKey) ?? "") ?? .system
    }

    public static func load() { isEnglish = resolve(choice) }

    public static func set(_ c: AppLanguage) {
        isEnglish = resolve(c)
        UserDefaults.standard.set(c.rawValue, forKey: prefKey)
    }

    public static func resolve(_ c: AppLanguage, preferred: [String] = Locale.preferredLanguages) -> Bool {
        switch c {
        case .uz: return false
        case .en: return true
        case .system: return preferred.first?.hasPrefix("en") ?? false
        }
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
