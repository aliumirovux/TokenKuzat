import Foundation
import ServiceManagement
import TokenKuzatCore

/// UserDefaults kalitlari — @AppStorage va oddiy kod bir xil nomlardan foydalanadi.
enum Pref {
    static let countMode = "countMode"
    static let menuBarStyle = "menuBarStyle"
    static let budgetEnabled = "budgetEnabled"
    static let budgetPeriod = "budgetPeriod"
    /// Million vaznli token
    static let budgetLimitM = "budgetLimitM"
    static let budgetNotify = "budgetNotify"
    static let section = "windowSection"
    static let notifyFinished = "notifyFinished"
    /// Soniya: shundan qisqa ish uchun «tugadi» yuborilmaydi
    static let notifyFinishedMin = "notifyFinishedMin"
    static let notifyStuck = "notifyStuck"
    static let notifyStuckSec = "notifyStuckSec"
    static let notifyErrors = "notifyErrors"
    static let notifyRealLimit = "notifyRealLimit"
    static let notifyPermission = "notifyPermission"
    static let notifyContext = "notifyContext"
    /// Limitni Claude hisobidan olish (Keychain'dagi Claude Code kaliti bilan)
    static let accountUsage = "accountUsage"
    /// Katta kontekstda yangi mavzu boshlanganda — yangi sessiya taklifi
    static let notifySavings = "notifySavings"
    /// Isrof ogohlantirishlari: sessiya konteksti 200K dan oshsa va loyiha bugun ko'p isrof qilsa
    static let notifyWaste = "notifyWaste"
    /// Kutib turgan sessiyaning keshi sovishidan oldin (5 daqiqalikda — 1 daqiqa, 1 soatlikda — 5 daqiqa)
    static let notifyCache = "notifyCache"
    /// Avtomatik yangi sessiya: kontekst chegaradan oshgan sessiya javobni tugatganda xulosa bilan yangi sessiya ochiladi
    static let autoHandoff = "autoHandoff"
    /// Kuniga bir marta GitHub'da yangi versiya borligini tekshirish
    static let checkUpdates = "checkUpdates"
    static let autoHandoffK = "autoHandoffK"
    /// Ko'chirilgan eski sessiyada yozilgan birinchi xabar yangi sessiyaga yo'naltiriladi (UserPromptSubmit hook)
    static let autoHandoffRedirect = "autoHandoffRedirect"
    /// Claude limiti tugaganda bildirishnomada «Bepul modelda davom etish» (FreeLLMAPI orqali, terminalda)
    static let freeFallback = "freeFallback"
    /// Bepul modelga Terminal'da o'tilgach, eski sessiyaning Terminal oynasi yopiladi
    static let closeOldTerminal = "closeOldTerminal"
    /// Avtomatik davom: shu papkada yangi sessiya ochilsa, oldingi sessiya (24 soat ichida) xulosasi o'zi beriladi
    static let autoResume = "autoResume"
    /// Yengil rejim: bezak animatsiyalari (robot, aylanuvchi chegaralar, oqim nuqtalari) to'xtaydi — protsessor tejaladi
    static let lightMode = "lightMode"
    /// «Faqat xarita»: sessiya sahifasida yon menyu, sarlavha va tablar yashiriladi — oynada faqat xarita
    static let mapOnly = "mapOnly"

    static func register() {
        UserDefaults.standard.register(defaults: [
            countMode: CountMode.weighted.rawValue,
            menuBarStyle: MenuBarStyle.tokens.rawValue,
            budgetEnabled: false,
            budgetPeriod: BudgetPeriod.fiveHours.rawValue,
            budgetLimitM: 20.0,
            budgetNotify: true,
            section: Section.overview.rawValue,
            notifyFinished: true,
            notifyFinishedMin: 60.0,
            notifyStuck: true,
            notifyStuckSec: 90.0,
            notifyErrors: true,
            notifyRealLimit: true,
            notifyPermission: true,
            notifyContext: true,
            notifySavings: true,
            notifyWaste: true,
            notifyCache: true,
            autoHandoff: true,
            checkUpdates: true,
            autoHandoffRedirect: true,
            autoHandoffK: AutoHandoffRule.defaultThresholdK,
            freeFallback: false,
            closeOldTerminal: true,
            autoResume: true,
        ])
    }
}

enum MenuBarStyle: String, CaseIterable, Identifiable {
    case tokens, budget, icon
    var id: String { rawValue }
    var title: String {
        switch self {
        case .tokens: return tr("Tokenlar va tezlik", "Tokens and rate")
        case .budget: return tr("5 soatlik limit — qancha qoldi", "5-hour limit — how much is left")
        case .icon: return tr("Faqat belgi", "Icon only")
        }
    }
}

enum NotifyMode: String, CaseIterable, Identifiable {
    case important, all, silent, custom
    var id: String { rawValue }
    var title: String {
        switch self {
        case .important: return tr("Faqat muhim", "Important only")
        case .all: return tr("Hammasi", "All")
        case .silent: return tr("Jim", "Silent")
        case .custom: return tr("O'zim tanlayman", "Custom")
        }
    }

    /// Diqqatingizni talab qiladiganlar: ish tugadi, ruxsat yoki osilish, xatolar, limit
    static let importantKeys = [Pref.notifyFinished, Pref.notifyStuck, Pref.notifyErrors, Pref.notifyPermission,
                                Pref.notifyRealLimit, Pref.budgetNotify]
    /// Maslahat turidagilar: kontekst, yangi mavzu, isrof, kesh
    static let adviceKeys = [Pref.notifyContext, Pref.notifySavings, Pref.notifyWaste, Pref.notifyCache]

    static func current(_ d: UserDefaults = .standard) -> NotifyMode {
        let imp = importantKeys.map { d.bool(forKey: $0) }, adv = adviceKeys.map { d.bool(forKey: $0) }
        switch (imp.allSatisfy { $0 }, adv.allSatisfy { $0 }, (imp + adv).contains(true)) {
        case (true, true, _): return .all
        case (true, _, _) where !adv.contains(true): return .important
        case (_, _, false): return .silent
        default: return .custom
        }
    }

    func apply(_ d: UserDefaults = .standard) {
        guard self != .custom else { return }
        for k in Self.importantKeys { d.set(self != .silent, forKey: k) }
        for k in Self.adviceKeys { d.set(self == .all, forKey: k) }
    }
}

enum BudgetPeriod: String, CaseIterable, Identifiable {
    case fiveHours, day
    var id: String { rawValue }
    var title: String {
        switch self {
        case .fiveHours: return tr("Oxirgi 5 soat", "Last 5 hours")
        case .day: return tr("Bugun", "Today")
        }
    }
}

enum LaunchAtLogin {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("TokenKuzat: login item — \(error.localizedDescription)")
        }
    }
}

enum AppInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }
    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }
    /// `swift run` bilan .app'siz ishga tushganda bildirishnoma va login item ishlamaydi
    static var isBundled: Bool { Bundle.main.bundleURL.pathExtension == "app" }
}
