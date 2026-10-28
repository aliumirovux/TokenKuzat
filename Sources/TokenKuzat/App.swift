import SwiftUI
import AppKit
import TokenKuzatCore

@main
struct TokenKuzatApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var store = Store.shared

    init() {
        Pref.register()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuPanel().environmentObject(store)
        } label: {
            MenuBarLabel().environmentObject(store)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    // Menyu satri belgisi notch ortida yashirinib qolishi mumkin,
    // shuning uchun ilova ochilganda (Spotlight, Finder) katta oyna ham chiqadi.
    func applicationDidFinishLaunching(_ notification: Notification) {
        Alerts.shared.start()
        DispatchQueue.main.async { WindowManager.shared.show() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        WindowManager.shared.show()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        Store.shared.flush()
    }
}

/// Menyu satridagi yozuv: tinch paytda bugungi jami, agent ishlayotganda ⚡ va tezlik.
struct MenuBarLabel: View {
    @EnvironmentObject var store: Store
    @AppStorage(Pref.countMode) private var mode = CountMode.raw
    @AppStorage(Pref.menuBarStyle) private var style = MenuBarStyle.tokens

    var body: some View {
        let s = store.snap
        let active = s.runningAgents > 0
        switch style {
        case .icon:
            Image(systemName: active ? "bolt.fill" : "chart.bar.xaxis")
        case .budget:
            if let b = BudgetStatus.current(s) {
                HStack(spacing: 3) {
                    Image(systemName: b.level == .ok ? "gauge.with.dots.needle.33percent" : "exclamationmark.triangle.fill")
                    Text(Fmt.percent(b.used, of: b.limit)).monospacedDigit()
                }
            } else {
                tokens(s, active)
            }
        case .tokens:
            tokens(s, active)
        }
    }

    private func tokens(_ s: Snapshot, _ active: Bool) -> some View {
        HStack(spacing: 3) {
            Image(systemName: active ? "bolt.fill" : "chart.bar.xaxis")
            Text(active ? "\(Fmt.tokens(s.rate(mode)))/daq" : Fmt.tokens(s.today.value(mode)))
                .monospacedDigit()
        }
    }
}
