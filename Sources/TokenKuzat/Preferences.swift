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
    /// Avtomatik yangi sessiya: kontekst chegaradan oshgan sessiya javobni tugatganda xulosa bilan yangi sessiya ochiladi
    static let autoHandoff = "autoHandoff"
    /// Kuniga bir marta GitHub'da yangi versiya borligini tekshirish
    static let checkUpdates = "checkUpdates"
    static let autoHandoffK = "autoHandoffK"
    static let autoHandoffTarget = "autoHandoffTarget"
    /// Yengil rejim: bezak animatsiyalari (robot, aylanuvchi chegaralar, oqim nuqtalari) to'xtaydi — protsessor tejaladi
    static let lightMode = "lightMode"
    /// «Faqat xarita»: sessiya sahifasida yon menyu, sarlavha va tablar yashiriladi — oynada faqat xarita
    static let mapOnly = "mapOnly"

    static func register() {
        UserDefaults.standard.register(defaults: [
            countMode: CountMode.raw.rawValue,
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
            autoHandoff: true,
            checkUpdates: true,
            autoHandoffK: AutoHandoffRule.defaultThresholdK,
            autoHandoffTarget: AutoHandoffTarget.app.rawValue,
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
