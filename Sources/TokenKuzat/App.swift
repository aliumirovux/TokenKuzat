import SwiftUI
import AppKit
import TokenKuzatCore

@main
struct TokenKuzatApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var store = Store.shared

    init() {
        // Claude Code status line chaqirig'i — oynasiz, darhol chiqadi
        if CommandLine.arguments.contains(StatusLine.flag) { StatusLine.runAndExit() }
        if CommandLine.arguments.contains(Hooks.flag) { Hooks.runAndExit() }
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
        // Ishlab chiquvchi uchun: `TokenKuzat --snapshot-panel fayl.png` — menyu panelini rasmga saqlab chiqadi
        if let i = CommandLine.arguments.firstIndex(of: "--snapshot-panel"), i + 1 < CommandLine.arguments.count {
            snapshotPanel(to: URL(fileURLWithPath: CommandLine.arguments[i + 1]))
            return
        }
        // `--snapshot-map fayl.png` — eng so'nggi sessiya xaritasini rasmga saqlaydi
        if let i = CommandLine.arguments.firstIndex(of: "--snapshot-map"), i + 1 < CommandLine.arguments.count {
            snapshotMap(to: URL(fileURLWithPath: CommandLine.arguments[i + 1]))
            return
        }
        Alerts.shared.start()
        DispatchQueue.main.async { WindowManager.shared.show() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        WindowManager.shared.show()
        return true
    }

    private func snapshotPanel(to url: URL) {
        // Birinchi skan tugashini kutadi, keyin panelni ikki temada chizadi
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            for scheme in [ColorScheme.dark, .light] {
                let view = MenuPanel().environmentObject(Store.shared)
                    .background(Color(nsColor: .windowBackgroundColor))
                    .environment(\.colorScheme, scheme)
                let r = ImageRenderer(content: view)
                r.scale = 2
                let out = scheme == .dark ? url : url.deletingPathExtension().appendingPathExtension("light.png")
                if let img = r.nsImage, let tiff = img.tiffRepresentation,
                   let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                    try? png.write(to: out)
                }
            }
            NSApp.terminate(nil)
        }
    }

    private func snapshotMap(to url: URL) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            let all = Store.shared.snap.sessions
            if let s = all.first {
                let view = SessionMapView(chain: SessionChain.chain(for: s, in: all), mode: .raw, selectedTurn: nil,
                                          onSelectTurn: { _, _ in }, onSelectTool: { _, _, _ in })
                    .frame(width: 1100, height: 560)
                    .environment(\.colorScheme, .dark)
                let r = ImageRenderer(content: view)
                r.scale = 2
                if let img = r.nsImage, let tiff = img.tiffRepresentation,
                   let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                    try? png.write(to: url)
                }
            }
            NSApp.terminate(nil)
        }
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
        if !s.permissionWaits.isEmpty {
            // Ruxsat kutilayotgani har qanday uslubdan ustun: ish to'xtab turibdi
            HStack(spacing: 3) {
                Image(systemName: "hand.raised.fill")
                Text("Ruxsat")
            }
        } else {
            styled(s, active)
        }
    }

    @ViewBuilder
    private func styled(_ s: Snapshot, _ active: Bool) -> some View {
        switch style {
        case .icon:
            Image(systemName: active ? "bolt.fill" : "chart.bar.xaxis")
        case .budget:
            if let w = s.limits?.fiveHour {
                HStack(spacing: 4) {
                    Image(systemName: w.usedPercentage >= 80 ? "exclamationmark.triangle.fill" : (active ? "bolt.fill" : "circle.dashed"))
                    Text("\(max(0, 100 - Int(w.usedPercentage.rounded())))%").monospacedDigit()
                }
            } else if let b = BudgetStatus.current(s) {
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
