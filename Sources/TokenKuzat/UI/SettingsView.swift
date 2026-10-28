import SwiftUI
import AppKit
import UserNotifications
import TokenKuzatCore

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @AppStorage(Pref.countMode) private var mode = CountMode.raw
    @AppStorage(Pref.menuBarStyle) private var menuBarStyle = MenuBarStyle.tokens
    @AppStorage(Pref.budgetEnabled) private var budgetEnabled = false
    @AppStorage(Pref.budgetPeriod) private var budgetPeriod = BudgetPeriod.fiveHours
    @AppStorage(Pref.budgetLimitM) private var budgetLimitM = 20.0
    @AppStorage(Pref.budgetNotify) private var budgetNotify = true
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var notifyDenied = false
    @State private var confirmClear = false

    var body: some View {
        Form {
            SwiftUI.Section("Umumiy") {
                Toggle("Mac yoqilganda ishga tushsin", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { LaunchAtLogin.set($0) }
                    .disabled(!AppInfo.isBundled)
                Picker("Menyu satrida", selection: $menuBarStyle) {
                    ForEach(MenuBarStyle.allCases) { Text($0.title).tag($0) }
                }
            }

            SwiftUI.Section {
                Picker("Hisoblash usuli", selection: $mode) {
                    Text("Xom — hamma token teng").tag(CountMode.raw)
                    Text("Vaznli — taxminiy narx bo'yicha").tag(CountMode.weighted)
                }
                .pickerStyle(.radioGroup)
            } header: {
                Text("Hisoblash")
            } footer: {
                Text("Vaznli rejim kiritish narxiga nisbatan: javob ×\(fmt(Pricing.output)), kesh o'qish ×\(fmt(Pricing.cacheRead)), kesh yozish ×\(fmt(Pricing.cacheWrite5m)) (1 soatlik kesh ×\(fmt(Pricing.cacheWrite1h))). Limitni nima ko'proq «yeyayotgani»ni shu rejim yaxshiroq ko'rsatadi.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            SwiftUI.Section {
                Toggle("Limitni kuzatish", isOn: $budgetEnabled)
                Picker("Davr", selection: $budgetPeriod) {
                    ForEach(BudgetPeriod.allCases) { Text($0.title).tag($0) }
                }
                .disabled(!budgetEnabled)
                LabeledContent("Limit") {
                    HStack(spacing: 6) {
                        TextField("", value: $budgetLimitM, format: .number.precision(.fractionLength(0...1)))
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Stepper("", value: $budgetLimitM, in: 1...2000, step: 5).labelsHidden()
                        Text("mln vaznli token").foregroundStyle(.secondary)
                    }
                }
                .disabled(!budgetEnabled)
                Toggle("80% va 100% da bildirishnoma", isOn: $budgetNotify)
                    .disabled(!budgetEnabled || !AppInfo.isBundled)
                    .onChange(of: budgetNotify) { on in
                        if on { Alerts.shared.requestPermission { notifyDenied = !$0 } }
                    }
                if notifyDenied {
                    Label("Bildirishnomalarga ruxsat yo'q — Tizim sozlamalari → Bildirishnomalar → Token Kuzatuv.",
                          systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(.orange)
                }
                if budgetEnabled, let b = BudgetStatus.current(store.snap) {
                    BudgetBar(status: b)
                }
            } header: {
                Text("Limit")
            } footer: {
                Text("Claude obunasi limiti 5 soatlik oyna bo'yicha tiklanadi. Anthropic aniq limitni e'lon qilmaydi — o'zingizning odatiy sarfingizga qarab qiymat qo'ying (Tarix sahifasida ko'rinadi).")
                    .font(.caption).foregroundStyle(.secondary)
            }

            SwiftUI.Section("Ma'lumot") {
                LabeledContent("Kuzatilayotgan fayllar", value: "\(store.snap.filesWatched) ta (oxirgi 30 kun)")
                SourcesList(sources: store.snap.sources)
                HStack {
                    Button("Claude papkasini ochish") { NSWorkspace.shared.open(Engine.primaryRoot) }
                    Button("Tarix faylini ko'rsatish") {
                        NSWorkspace.shared.activateFileViewerSelecting([HistoryStore.defaultURL])
                    }
                    Spacer()
                    Button("Tarixni tozalash…", role: .destructive) { confirmClear = true }
                }
            }

            SwiftUI.Section("Ilova haqida") {
                LabeledContent("Versiya", value: "\(AppInfo.version) (\(AppInfo.build))")
                Text("Faqat shu Mac'dagi ~/.claude fayllarini o'qiydi. Internetga hech narsa yubormaydi.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Saqlangan kunlik tarix o'chirilsinmi?", isPresented: $confirmClear) {
            Button("O'chirish", role: .destructive) { store.clearHistory() }
        } message: {
            Text("Oxirgi 30 kundagi Claude yozuvlari qayta o'qiladi, undan eskilari tiklanmaydi.")
        }
        .onAppear {
            launchAtLogin = LaunchAtLogin.isEnabled
            if AppInfo.isBundled {
                UNUserNotificationCenter.current().getNotificationSettings { s in
                    DispatchQueue.main.async { notifyDenied = budgetNotify && s.authorizationStatus == .denied }
                }
            }
        }
    }

    private func fmt(_ v: Double) -> String {
        var s = String(format: "%.2f", v)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s.replacingOccurrences(of: ".", with: ",")
    }
}
