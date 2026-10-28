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
        ])
    }
}

enum MenuBarStyle: String, CaseIterable, Identifiable {
    case tokens, budget, icon
    var id: String { rawValue }
    var title: String {
        switch self {
        case .tokens: return "Tokenlar va tezlik"
        case .budget: return "5 soatlik limit — qancha qoldi"
        case .icon: return "Faqat belgi"
        }
    }
}

enum BudgetPeriod: String, CaseIterable, Identifiable {
    case fiveHours, day
    var id: String { rawValue }
    var title: String {
        switch self {
        case .fiveHours: return "Oxirgi 5 soat"
        case .day: return "Bugun"
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
