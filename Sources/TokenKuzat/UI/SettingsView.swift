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
    @AppStorage(Pref.notifyFinished) private var notifyFinished = true
    @AppStorage(Pref.notifyFinishedMin) private var notifyFinishedMin = 60.0
    @AppStorage(Pref.notifyStuck) private var notifyStuck = true
    @AppStorage(Pref.notifyStuckSec) private var notifyStuckSec = 90.0
    @AppStorage(Pref.notifyErrors) private var notifyErrors = true
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
                Toggle("Claude ishni tugatganda", isOn: $notifyFinished)
                Picker("…agar ish shundan uzoq davom etgan bo'lsa", selection: $notifyFinishedMin) {
                    Text("har doim").tag(0.0)
                    Text("30 soniya").tag(30.0)
                    Text("1 daqiqa").tag(60.0)
                    Text("3 daqiqa").tag(180.0)
                    Text("10 daqiqa").tag(600.0)
                }
                .disabled(!notifyFinished)
                Toggle("Qadam uzoq tugamasa (ruxsat kutilayotgan bo'lishi mumkin)", isOn: $notifyStuck)
                Picker("…shundan keyin", selection: $notifyStuckSec) {
                    Text("30 soniya").tag(30.0)
                    Text("1,5 daqiqa").tag(90.0)
                    Text("3 daqiqa").tag(180.0)
                    Text("5 daqiqa").tag(300.0)
                }
                .disabled(!notifyStuck)
                Toggle("Agent ketma-ket 3 marta xato olsa", isOn: $notifyErrors)
                HStack {
                    Spacer()
                    Button("Sinov bildirishnomasi") { Alerts.shared.sendTest() }
                }
                if notifyDenied {
                    HStack {
                        Label("macOS bildirishnomalarga ruxsat bermagan", systemImage: "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(.orange)
                        Spacer()
                        Button("Ruxsat berish…") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=uz.ali.tokenkuzat")!)
                        }
                    }
                }
            } header: {
                Text("Bildirishnomalar")
            } footer: {
                Text("Bildirishnomani bosing — o'sha sessiya Agentlar sxemasida ochiladi. Ilova ochilganda mavjud holatlar uchun xabar yuborilmaydi.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .disabled(!AppInfo.isBundled)
            .onChange(of: notifyFinished) { if $0 { askPermission() } }
            .onChange(of: notifyStuck) { if $0 { askPermission() } }
            .onChange(of: notifyErrors) { if $0 { askPermission() } }

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
                    .onChange(of: budgetNotify) { if $0 { askPermission() } }
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
        .onAppear(perform: refreshStatus)
        // Tizim sozlamalarida ruxsat berib qaytilganda holat yangilanadi
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshStatus()
        }
    }

    private func refreshStatus() {
        launchAtLogin = LaunchAtLogin.isEnabled
        guard AppInfo.isBundled else { return }
        UNUserNotificationCenter.current().getNotificationSettings { s in
            DispatchQueue.main.async { notifyDenied = s.authorizationStatus == .denied }
        }
    }

    private func askPermission() {
        Alerts.shared.requestPermission { notifyDenied = !$0 }
    }

    private func fmt(_ v: Double) -> String {
        var s = String(format: "%.2f", v)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s.replacingOccurrences(of: ".", with: ",")
    }
}
