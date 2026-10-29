import SwiftUI
import AppKit
import TokenKuzatCore

@main
struct TokenKuzatApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var store = Store.shared

    init() {
        // Til birinchi bo'lib yuklanadi: status line va bildirishnomalar ham shu tilda chiqadi
        Lang.load()
        // Claude Code status line chaqirig'i — oynasiz, darhol chiqadi
        if CommandLine.arguments.contains(StatusLine.flag) { StatusLine.runAndExit() }
        if CommandLine.arguments.contains(Hooks.flag) { Hooks.runAndExit() }
        if CommandLine.arguments.contains(SessionStartHook.flag) { SessionStartHook.runAndExit() }
        if CommandLine.arguments.contains(PromptRedirectHook.flag) { PromptRedirectHook.runAndExit() }
        // MCP server (Claude Code plagini) — stdio orqali, oynasiz
        if CommandLine.arguments.contains(MCPServer.flag) { MCPServer.runAndExit() }
        Pref.register()
    }

    var body: some Scene {
        MenuBarExtra {
            LanguageScope { MenuPanel() }.environmentObject(store)
        } label: {
            LanguageScope { MenuBarLabel() }.environmentObject(store)
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
        // `--snapshot-robots fayl.png` — robotning barcha holatlari bitta rasmda
        if let i = CommandLine.arguments.firstIndex(of: "--snapshot-robots"), i + 1 < CommandLine.arguments.count {
            let all: [RobotView.Action] = [.typing("Terminal"), .reading("App.swift"), .writing("Robot.swift"), .browsing("Internet"),
                                           .plugging("computer-use"), .delegating("Explore"), .tinkering("Asbob"), .thinking,
                                           .answering, .waiting, .error, .greeting, .celebrating, .sleeping, .watching, .hello]
            let view = LazyVGrid(columns: Array(repeating: GridItem(.fixed(170)), count: 7), spacing: 20) {
                ForEach(Array(all.enumerated()), id: \.offset) { _, a in RobotView(action: a, size: 64).frame(height: 130) }
            }
            .padding(24).background(Brand.canvas).environment(\.colorScheme, .dark)
            let r = ImageRenderer(content: view)
            r.scale = 2
            if let img = r.nsImage, let tiff = img.tiffRepresentation,
               let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: CommandLine.arguments[i + 1]))
            }
            NSApp.terminate(nil)
            return
        }
        // `--snapshot-map fayl.png` — eng so'nggi sessiya xaritasini rasmga saqlaydi
        if let i = CommandLine.arguments.firstIndex(of: "--snapshot-header"), i + 1 < CommandLine.arguments.count {
            snapshotHeader(to: URL(fileURLWithPath: CommandLine.arguments[i + 1]))
            return
        }
        if let i = CommandLine.arguments.firstIndex(of: "--snapshot-map"), i + 1 < CommandLine.arguments.count {
            snapshotMap(to: URL(fileURLWithPath: CommandLine.arguments[i + 1]))
            return
        }
        Alerts.shared.start()
        AccountUsage.shared.start()
        UpdateChecker.shared.start()
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

    /// Ishlab chiquvchi uchun: `--snapshot-header fayl.png --width 700` — sessiya sarlavhasi berilgan kenglikda
    private func snapshotHeader(to url: URL) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            let width = CommandLine.arguments.firstIndex(of: "--width").flatMap { i in
                i + 1 < CommandLine.arguments.count ? Double(CommandLine.arguments[i + 1]) : nil
            } ?? 700
            if let s = Store.shared.snap.sessions.first {
                let view = SessionHeader(session: s, turn: s.turns.last, mode: .raw, costUSD: nil)
                    .padding(.bottom, 20)
                    .frame(width: CGFloat(width))
                    .background(Color(nsColor: .windowBackgroundColor))
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

    private func snapshotMap(to url: URL) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            let all = Store.shared.snap.sessions
            if let s = all.first {
                let zoom = CommandLine.arguments.firstIndex(of: "--zoom").flatMap { i in
                    i + 1 < CommandLine.arguments.count ? Double(CommandLine.arguments[i + 1]) : nil
                }
                let width = CommandLine.arguments.firstIndex(of: "--width").flatMap { i in
                    i + 1 < CommandLine.arguments.count ? Double(CommandLine.arguments[i + 1]) : nil
                } ?? 1240
                let view = SessionMapView(chain: SessionChain.chain(for: s, in: all), mode: .raw, selectedTurn: nil,
                                          onSelectTurn: { _, _ in }, onSelectTool: { _, _, _ in },
                                          initialScale: zoom.map { CGFloat($0) },
                                          interactive: true)
                    .frame(width: CGFloat(width), height: 600)
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

/// Til almashganda ichidagi ko'rinish qaytadan quriladi — barcha matnlar darhol yangi tilda chiqadi
struct LanguageScope<Content: View>: View {
    @AppStorage(Lang.prefKey) private var language = AppLanguage.system.rawValue
    @ViewBuilder var content: () -> Content

    var body: some View {
        content().id(language)
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
                Text(tr("Ruxsat", "Permission"))
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
            Text(active ? tr("\(Fmt.tokens(s.rate(mode)))/daq", "\(Fmt.tokens(s.rate(mode)))/min") : Fmt.tokens(s.today.value(mode)))
                .monospacedDigit()
        }
    }
}
