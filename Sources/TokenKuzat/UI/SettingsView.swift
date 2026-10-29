import SwiftUI
import AppKit
import UserNotifications
import TokenKuzatCore

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @AppStorage(Pref.countMode) private var mode = CountMode.weighted
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
    @AppStorage(Pref.notifyRealLimit) private var notifyRealLimit = true
    @AppStorage(Pref.notifyPermission) private var notifyPermission = true
    @AppStorage(Pref.notifyContext) private var notifyContext = true
    @AppStorage(Pref.notifySavings) private var notifySavings = true
    @AppStorage(Pref.notifyWaste) private var notifyWaste = true
    @AppStorage(Pref.notifyCache) private var notifyCache = true
    @AppStorage(Pref.autoHandoff) private var autoHandoff = true
    @AppStorage(Pref.autoHandoffK) private var autoHandoffK = AutoHandoffRule.defaultThresholdK
    /// Claude Code'ning o'z qisqartirish oynasi (~/.claude/settings.json yoki muhit o'zgaruvchisi)
    private var compactWindow: AutoCompactWindow.Found? {
        (try? StatusLine.readSettings()).flatMap { AutoCompactWindow.smallest(settings: $0) }
    }
    @AppStorage(Pref.autoHandoffTarget) private var autoHandoffTarget = AutoHandoffTarget.app.rawValue
    @AppStorage(Pref.autoHandoffRedirect) private var autoHandoffRedirect = true
    @AppStorage(Pref.lightMode) private var lightMode = false
    @AppStorage(Lang.prefKey) private var language = AppLanguage.system.rawValue
    @State private var hookInstalled = Hooks.isInstalled
    @State private var handoffHookInstalled = SessionStartHook.isInstalled
    @State private var hookError: String?
    @State private var statusLineInstalled = StatusLine.isInstalled
    @AppStorage(Pref.accountUsage) private var accountUsage = false
    @State private var accountStatus: AccountUsage.Status = .off
    @State private var statusLineError: String?
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @AppStorage(Pref.checkUpdates) private var checkUpdates = true
    @ObservedObject private var updates = UpdateChecker.shared
    @State private var notifyDenied = false
    @State private var confirmClear = false

    private var updateCaption: String {
        let current = tr("Hozirgi: v\(AppInfo.version)", "Current: v\(AppInfo.version)")
        switch updates.status {
        case .checking: return current + tr(" · tekshirilmoqda…", " · checking…")
        case .failed: return current + tr(" · tekshirib bo'lmadi (internet?)", " · couldn't check (internet?)")
        case .upToDate: return current + tr(" · eng so'nggi versiya", " · up to date")
        case .idle: return current + tr(" · kuniga bir marta GitHub'dan tekshiriladi", " · checked on GitHub once a day")
        }
    }

    var body: some View {
        Form {
            SwiftUI.Section(tr("Umumiy", "General")) {
                Picker(selection: Binding(get: { AppLanguage(rawValue: language) ?? .system }, set: { Lang.set($0) })) {
                    ForEach(AppLanguage.allCases) { Text($0.title).tag($0) }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Til / Language")
                        Text(tr("Darhol qo'llanadi. «Tizim tili» — Mac inglizcha bo'lsa English, aks holda o'zbekcha",
                                "Applies immediately. “System language” — English if your Mac is in English, otherwise Uzbek"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Toggle(tr("Mac yoqilganda ishga tushsin", "Launch at login"), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { LaunchAtLogin.set($0) }
                    .disabled(!AppInfo.isBundled)
                Toggle(isOn: $checkUpdates) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr("Yangi versiyani tekshirish", "Check for updates"))
                        Text(updateCaption).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .onChange(of: checkUpdates) { on in if on { updates.start() } else { updates.stop() } }
                if let r = updates.available {
                    HStack {
                        Label(tr("v\(r.version) chiqdi", "v\(r.version) is out"), systemImage: "arrow.down.circle.fill").foregroundStyle(Brand.accent)
                        Spacer()
                        Button(tr("Reliz sahifasi", "Release page")) { NSWorkspace.shared.open(r.pageURL) }.buttonStyle(.link)
                        Button(tr("Yuklab olish", "Download")) { updates.download() }
                    }
                } else if checkUpdates {
                    HStack {
                        Spacer()
                        Button(tr("Hozir tekshirish", "Check now")) { updates.check() }.disabled(updates.status == .checking)
                    }
                }
                Picker(tr("Menyu satrida", "Menu bar"), selection: $menuBarStyle) {
                    ForEach(MenuBarStyle.allCases) { Text($0.title).tag($0) }
                }
                Toggle(isOn: $lightMode) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr("Kam animatsiya", "Reduce motion"))
                        Text(tr("Robot, aylanuvchi chegaralar va oqim animatsiyalari to'xtaydi — oyna ochiq turganda protsessor taxminan ikki baravar kam ishlaydi", "Stops the robot, spinning borders and flow animations — uses about half the CPU while the window is open"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            SwiftUI.Section {
                Toggle(tr("Claude ishni tugatganda", "When Claude finishes a task"), isOn: $notifyFinished)
                Picker(tr("…agar ish shundan uzoq davom etgan bo'lsa", "…if it ran longer than"), selection: $notifyFinishedMin) {
                    Text(tr("har doim", "always")).tag(0.0)
                    Text(tr("30 soniya", "30 seconds")).tag(30.0)
                    Text(tr("1 daqiqa", "1 minute")).tag(60.0)
                    Text(tr("3 daqiqa", "3 minutes")).tag(180.0)
                    Text(tr("10 daqiqa", "10 minutes")).tag(600.0)
                }
                .disabled(!notifyFinished)
                Toggle(tr("Qadam uzoq tugamasa (ruxsat kutilayotgan bo'lishi mumkin)", "When a step takes too long (may be waiting for permission)"), isOn: $notifyStuck)
                Picker(tr("…shundan keyin", "…after"), selection: $notifyStuckSec) {
                    Text(tr("30 soniya", "30 seconds")).tag(30.0)
                    Text(tr("1,5 daqiqa", "1.5 minutes")).tag(90.0)
                    Text(tr("3 daqiqa", "3 minutes")).tag(180.0)
                    Text(tr("5 daqiqa", "5 minutes")).tag(300.0)
                }
                .disabled(!notifyStuck)
                Toggle(tr("Agent ketma-ket 3 marta xato olsa", "When an agent hits 3 errors in a row"), isOn: $notifyErrors)
                Toggle(tr("Kontekst 85% to'lganda (tez orada avtomatik xulosa)", "When context is 85% full (auto-summary coming soon)"), isOn: $notifyContext)
                Toggle(tr("Katta kontekstda yangi mavzu boshlansa — yangi sessiya taklifi (token tejash)", "New topic in a large context — suggest a new session (saves tokens)"), isOn: $notifySavings)
                Toggle(tr("Isrof: kontekst 200K dan oshsa yoki loyiha bugun sarfining 40%+ ini isrof qilsa", "Waste: context passes 200K, or a project wastes 40%+ of today's usage"), isOn: $notifyWaste)
                Toggle(tr("Kesh sovishidan oldin — javobingizni kutayotgan katta sessiyada", "Before the cache cools — in a large session waiting for your reply"), isOn: $notifyCache)
                captionToggle(tr("Kontekst katta bo'lsa — avtomatik yangi sessiya", "Large context — open a new session automatically"),
                              tr("Javob tugagach xulosa bilan yangi sessiya ochiladi — ish to'xtatilmaydi", "Opens a new session with the summary after Claude's reply — work isn't interrupted"),
                              help: tr("Claude javobni tugatgach yangi sessiya xulosa bilan ochiladi; ish o'rtasida to'xtatilmaydi. Claude ilovasida xulosa yozib qo'yiladi — Enter bosasiz "
                                 + "(ilova tashqaridan kelgan xabarni xavfsizlik uchun o'zi yubormaydi); Terminalda to'liq avtomatik",
                                 "After Claude finishes its reply, a new session opens with the summary; work is never interrupted. In the Claude app the summary is filled in — you press Enter "
                                 + "(the app doesn't send outside messages by itself, for safety); in Terminal it's fully automatic"),
                              isOn: $autoHandoff)
                .onChange(of: autoHandoff) { on in
                    if !on { try? PromptRedirectHook.uninstall(); try? PreCompactHook.uninstall() }
                }
                if autoHandoff {
                    Picker(tr("…kontekst oshganda", "…when context passes"), selection: $autoHandoffK) {
                        ForEach(AutoHandoffRule.thresholdOptionsK, id: \.self) { Text(Fmt.tokens($0 * 1000)).tag($0) }
                    }
                    Picker(tr("…ochiladi", "…opens"), selection: $autoHandoffTarget) {
                        ForEach(AutoHandoffTarget.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                    if let w = compactWindow, Double(w.tokens) <= autoHandoffK * 1000 {
                        Label(tr("Claude Code suhbatni \(Fmt.tokens(w.tokens)) da o'zi qisqartiradi (\(w.source)) — bu ko'chirish chegarasidan "
                                 + "(\(Fmt.tokens(Int(autoHandoffK * 1000)))) kichik. Ilova qisqartirishni bir marta to'xtatib, ishni yangi sessiyaga ko'chiradi. "
                                 + "Har doim ishonchli bo'lishi uchun chegarani \(Fmt.tokens(w.tokens)) dan pastroq tanlang.",
                                 "Claude Code compacts the conversation by itself at \(Fmt.tokens(w.tokens)) (\(w.source)) — below the handoff threshold "
                                 + "(\(Fmt.tokens(Int(autoHandoffK * 1000)))). The app stops compaction once and moves the work to a new session. "
                                 + "To be safe every time, pick a threshold below \(Fmt.tokens(w.tokens))."),
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(.orange)
                    }
                    captionToggle(tr("…eski sessiyada yozsam — yangi sessiyaga yo'naltirish", "…if I type in the old session — redirect to the new one"),
                                  tr("Keyingi xabaringiz xulosa bilan yangi sessiyaga ketadi", "Your next message goes to the new session with the summary"),
                                  help: tr("Birinchi xabar to'xtatilib, xulosa bilan yangi sessiyaga yuboriladi; qayta yuborsangiz — eski sessiyada qoladi",
                                     "The first message is stopped and sent to the new session with the summary; send it again to stay in the old session"),
                                  isOn: $autoHandoffRedirect)
                    // Hook eslatma so'rovi uchun ham kerak — avtomatik ko'chirish yoqiq bo'lsa, faqat yo'naltirishlar o'chiriladi
                    .onChange(of: autoHandoffRedirect) { on in if !on { try? FileManager.default.removeItem(at: RedirectStore.defaultURL) } }
                }
                if handoffHookInstalled {
                    HStack {
                        Text(tr("Yangi sessiyada davom ettirish (xulosa avtomatik beriladi)", "Continue in a new session (summary passed automatically)"))
                        Spacer()
                        Label(tr("Ulangan", "Connected"), systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(Brand.ok)
                        Button(tr("Uzish", "Disconnect")) {
                            try? SessionStartHook.uninstall()
                            handoffHookInstalled = SessionStartHook.isInstalled
                        }.buttonStyle(.link)
                    }
                }
                HStack {
                    Toggle(tr("Claude ruxsat so'raganda", "When Claude asks for permission"), isOn: $notifyPermission)
                    Spacer()
                    if hookInstalled {
                        Label(tr("Ulangan", "Connected"), systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(Brand.ok)
                        Button(tr("Uzish", "Disconnect")) { toggleHook(false) }.buttonStyle(.link)
                    } else {
                        Button(tr("Claude Code'ga ulash", "Connect to Claude Code")) { toggleHook(true) }
                    }
                }
                if let hookError {
                    Label(hookError, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(Brand.err)
                }
                HStack {
                    Spacer()
                    Button(tr("Sinov bildirishnomasi", "Test notification")) { Alerts.shared.sendTest() }
                }
                if notifyDenied {
                    HStack {
                        Label(tr("macOS bildirishnomalarga ruxsat bermagan", "macOS hasn't allowed notifications"), systemImage: "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(Brand.warn)
                        Spacer()
                        Button(tr("Ruxsat berish…", "Allow…")) {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=uz.ali.tokenkuzat")!)
                        }
                    }
                }
            } header: {
                Text(tr("Bildirishnomalar", "Notifications"))
            } footer: {
                Text(tr("Bildirishnomani bosing — o'sha sessiya ochiladi.\nRuxsat so'rovi uchun «Ulash» settings.json ga hook qo'shadi; yangi sessiyalarda ishlaydi.", "Click a notification to open that session.\nFor permission requests, «Connect» adds a hook to settings.json; it works in new sessions."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            .disabled(!AppInfo.isBundled)
            .onChange(of: notifyFinished) { if $0 { askPermission() } }
            .onChange(of: notifyStuck) { if $0 { askPermission() } }
            .onChange(of: notifyErrors) { if $0 { askPermission() } }

            SwiftUI.Section {
                Picker(tr("Hisoblash usuli", "Counting method"), selection: $mode) {
                    Text(tr("Token soni", "Token count")).tag(CountMode.raw)
                    Text(tr("Narx bo'yicha", "By cost")).tag(CountMode.weighted)
                }
                .pickerStyle(.radioGroup)
            } header: {
                Text(tr("Hisoblash", "Counting"))
            } footer: {
                Text(tr("Token soni — har bir token teng sanaladi. Narx bo'yicha — kiritish narxiga nisbatan: javob ×\(fmt(Pricing.output)), kesh o'qish ×\(fmt(Pricing.cacheRead)), kesh yozish ×\(fmt(Pricing.cacheWrite5m)) (1 soatlik kesh ×\(fmt(Pricing.cacheWrite1h))). Limitni nima ko'proq «yeyayotgani»ni shu usul yaxshiroq ko'rsatadi.", "Token count — every token counts the same. By cost — relative to input price: output ×\(fmt(Pricing.output)), cache read ×\(fmt(Pricing.cacheRead)), cache write ×\(fmt(Pricing.cacheWrite5m)) (1-hour cache ×\(fmt(Pricing.cacheWrite1h))). This shows better what really «eats» your limit."))
                    .font(.caption).foregroundStyle(.secondary)
            }

            SwiftUI.Section {
                Toggle(tr("Claude hisobidan olish (claude.ai bilan bir xil)", "Fetch from Claude account (same as claude.ai)"), isOn: $accountUsage)
                    .onChange(of: accountUsage) { on in
                        if on { AccountUsage.shared.start(); AccountUsage.shared.refreshNow() } else { AccountUsage.shared.stop() }
                        refreshAccount()
                    }
                if accountUsage {
                    LabeledContent(tr("Holat", "Status")) {
                        HStack(spacing: 6) {
                            Circle().fill(accountColor).frame(width: 8, height: 8)
                            Text(accountText)
                        }
                    }
                    HStack {
                        Spacer()
                        Button(tr("Hozir yangilash", "Refresh now")) { AccountUsage.shared.refreshNow(); refreshAccountLater() }
                    }
                }
            } header: {
                Text(tr("Claude limiti — hisobdan", "Claude limit — from account"))
            } footer: {
                Text(tr("Claude Code'ning Keychain'dagi kirish kaliti bilan Anthropic'dan 5 soatlik va haftalik limit har daqiqada olinadi — Code tabi va Claude ilovasida ham ishlaydi. Kalit faqat shu kompyuterda o'qiladi va faqat api.anthropic.com ga yuboriladi. Birinchi marta macOS Keychain ruxsatini so'raydi («Har doim ruxsat»). Ishlamasa — pastdagi status line zaxira manba bo'ladi. Yoqilgan bo'lsa, limitning chat va bulutga (Mac'ga yozilmaydigan ishlarga) ketgan qismi ham hisoblanadi.", "Using Claude Code's sign-in key from Keychain, the current session and weekly limits are fetched from Anthropic every minute — works for the Code tab and the Claude app too. The key is read only on this computer and sent only to api.anthropic.com. The first time, macOS asks for Keychain access («Always Allow»). If it doesn't work, the status line below is the fallback source. When on, the part of the limit spent in chat & cloud (work not written to this Mac) is calculated too."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            .onAppear(perform: refreshAccount)

            SwiftUI.Section {
                LabeledContent(tr("Holat", "Status")) {
                    HStack(spacing: 6) {
                        Circle().fill(statusLineInstalled ? (store.snap.limits.map { !$0.isEmpty } == true ? Brand.ok : Brand.warn) : .secondary)
                            .frame(width: 8, height: 8)
                        Text(statusLineStatus)
                    }
                }
                HStack {
                    if statusLineInstalled {
                        Button(tr("Uzish", "Disconnect")) { toggleStatusLine(false) }
                    } else {
                        Button(tr("Claude Code'ga ulash", "Connect to Claude Code")) { toggleStatusLine(true) }.buttonStyle(.borderedProminent)
                    }
                    Spacer()
                    Button(tr("settings.json'ni ko'rsatish", "Show settings.json")) {
                        NSWorkspace.shared.activateFileViewerSelecting([StatusLine.settingsURL])
                    }
                    .buttonStyle(.link)
                }
                if let statusLineError {
                    Label(statusLineError, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(Brand.err)
                }
                if let l = store.snap.limits, !l.isEmpty {
                    RealLimitsView(limits: l, forecast: store.snap.fiveHourForecast)
                }
                Toggle(tr("80% va 95% ga yetganda bildirishnoma", "Notify at 80% and 95%"), isOn: $notifyRealLimit)
                    .disabled(!statusLineInstalled || !AppInfo.isBundled)
                    .onChange(of: notifyRealLimit) { if $0 { askPermission() } }
            } header: {
                Text(tr("Claude limiti (haqiqiy)", "Claude limit (real)"))
            } footer: {
                Text(tr("Claude Code har bir javobdan keyin status line'ga 5 soatlik va haftalik limit foizini beradi (Pro/Max obunada). «Ulash» ~/.claude/settings.json ga Token Kuzatuv'ni status line qilib yozadi: terminalda pastki satrda «5 soat 34% ↻16:40 · hafta 61%» ko'rinadi. Avvalgi status line bo'lsa — saqlanadi va ishlashda davom etadi; «Uzish» uni qaytaradi. Birinchi ulanishda settings.json nusxasi olinadi.", "After each reply, Claude Code passes the 5-hour and weekly limit percentages to the status line (Pro/Max plans). «Connect» sets Token Kuzatuv as the status line in ~/.claude/settings.json: the terminal's bottom line shows «5h 34% ↻16:40 · week 61%». An existing status line is kept and keeps working; «Disconnect» restores it. A backup of settings.json is made on first connect."))
                    .font(.caption).foregroundStyle(.secondary)
            }

            FreeModelsSection()

            SwiftUI.Section {
                Toggle(tr("Limitni kuzatish", "Track limit"), isOn: $budgetEnabled)
                Picker(tr("Davr", "Period"), selection: $budgetPeriod) {
                    ForEach(BudgetPeriod.allCases) { Text($0.title).tag($0) }
                }
                .disabled(!budgetEnabled)
                LabeledContent(tr("Limit", "Limit")) {
                    HStack(spacing: 6) {
                        TextField("", value: $budgetLimitM, format: .number.precision(.fractionLength(0...1)))
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Stepper("", value: $budgetLimitM, in: 1...2000, step: 5).labelsHidden()
                        Text(tr("mln token (narx bo'yicha)", "M tokens (by price)")).foregroundStyle(.secondary)
                    }
                }
                .disabled(!budgetEnabled)
                Toggle(tr("80% va 100% da bildirishnoma", "Notify at 80% and 100%"), isOn: $budgetNotify)
                    .disabled(!budgetEnabled || !AppInfo.isBundled)
                    .onChange(of: budgetNotify) { if $0 { askPermission() } }
                if budgetEnabled, let b = BudgetStatus.current(store.snap) {
                    BudgetBar(status: b)
                }
            } header: {
                Text(tr("O'z limitim (taxminiy)", "My own limit (estimate)"))
            } footer: {
                Text(tr("Claude obunasi limiti 5 soatlik oyna bo'yicha tiklanadi. Anthropic aniq limitni e'lon qilmaydi — o'zingizning odatiy sarfingizga qarab qiymat qo'ying (Tarix sahifasida ko'rinadi).", "Claude plan limits reset on a 5-hour window. Anthropic doesn't publish the exact limit — set a value based on your typical usage (shown on the History page)."))
                    .font(.caption).foregroundStyle(.secondary)
            }

            SwiftUI.Section(tr("Ma'lumot", "Data")) {
                LabeledContent(tr("Kuzatilayotgan fayllar", "Watched files"), value: tr("\(store.snap.filesWatched) ta (oxirgi 30 kun)", "\(store.snap.filesWatched) (last 30 days)"))
                SourcesList(sources: store.snap.sources)
                LabeledContent(tr("Bulutdagi chatlar", "Cloud chats")) {
                    HStack {
                        Button(tr("Chat yozuvini qo'shish…", "Add chat transcript…")) { ChatImporter.pick() }
                        Button(tr("Papkani ochish", "Open folder")) {
                            try? FileManager.default.createDirectory(at: ChatImport.directory, withIntermediateDirectories: true)
                            NSWorkspace.shared.open(ChatImport.directory)
                        }
                    }
                }
                Text(tr("Claude chat va bulutdagi sessiyalar Mac'ga yozilmaydi. Chatdan Claude'ga «yozuvini Token Kuzatuv uchun ber» deng — kelgan .jsonl faylni shu tugma bilan qo'shing yoki oynaga sudrab tashlang. Xaritada «\(ChatImport.projectName)» loyihasi bo'lib chiqadi.", "Claude chat and cloud sessions aren't written to this Mac. In chat, ask Claude to «export the transcript for Token Kuzatuv» — add the .jsonl file with this button or drag it onto the window. It shows up on the map as the «\(ChatImport.projectName)» project."))
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button(tr("Claude papkasini ochish", "Open Claude folder")) { NSWorkspace.shared.open(Engine.primaryRoot) }
                    Button(tr("Tarix faylini ko'rsatish", "Show history file")) {
                        NSWorkspace.shared.activateFileViewerSelecting([HistoryStore.defaultURL])
                    }
                    Spacer()
                    Button(tr("Tarixni tozalash…", "Clear history…"), role: .destructive) { confirmClear = true }
                }
            }

            SwiftUI.Section(tr("Ilova haqida", "About")) {
                LabeledContent(tr("Versiya", "Version"), value: "\(AppInfo.version) (\(AppInfo.build))")
                Text(tr("Shu Mac'dagi ~/.claude fayllarini va o'zingiz qo'shgan chat yozuvlarini o'qiydi. Yozuvlar internetga yuborilmaydi.", "Reads ~/.claude files on this Mac and chat transcripts you add. Nothing is sent to the internet."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .confirmationDialog(tr("Saqlangan kunlik tarix o'chirilsinmi?", "Delete saved daily history?"), isPresented: $confirmClear) {
            Button(tr("O'chirish", "Delete"), role: .destructive) { store.clearHistory() }
        } message: {
            Text(tr("Oxirgi 30 kundagi Claude yozuvlari qayta o'qiladi, undan eskilari tiklanmaydi.", "Claude logs from the last 30 days will be re-read; older ones can't be restored."))
        }
        .onAppear(perform: refreshStatus)
        // Tizim sozlamalarida ruxsat berib qaytilganda holat yangilanadi
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshStatus()
        }
    }

    private var statusLineStatus: String {
        guard statusLineInstalled else { return tr("Ulanmagan", "Not connected") }
        if let l = store.snap.limits, !l.isEmpty { return tr("Ulangan · ma'lumot \(Fmt.ago(l.updatedAt))", "Connected · data \(Fmt.ago(l.updatedAt))") }
        if let t = StatusLine.lastUpdate { return tr("Ulangan · oxirgi chaqiruv \(Fmt.ago(t)), limit kelmadi (API kaliti bilanmi?)", "Connected · last call \(Fmt.ago(t)), no limit received (using an API key?)") }
        return tr("Ulangan · Claude Code'da yangi so'rov kutilyapti", "Connected · waiting for a new prompt in Claude Code")
    }

    private func refreshAccount() { accountStatus = AccountUsage.shared.status }

    private func refreshAccountLater() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { refreshAccount() }
    }

    private var accountColor: Color {
        switch accountStatus {
        case .ok: return Brand.ok
        case .loading, .off: return .secondary
        case .throttled: return Brand.warn
        case .expired, .noCredentials: return Brand.warn
        case .failed: return Brand.err
        }
    }

    private var accountText: String {
        switch accountStatus {
        case .off: return tr("O'chirilgan", "Off")
        case .loading: return tr("Olinmoqda…", "Fetching…")
        case .ok(let t): return tr("Ulangan · ", "Connected · ") + Fmt.ago(t) + (store.snap.limits?.plan.map { " · " + $0 } ?? "")
        case .noCredentials: return tr("Claude Code kaliti topilmadi (Claude Code'ga kiring yoki Keychain ruxsatini bering)", "Claude Code key not found (sign in to Claude Code or allow Keychain access)")
        case .expired: return tr("Kalit muddati o'tgan — Claude Code'da biror so'rov yuboring", "Key expired — send any prompt in Claude Code")
        case .failed(let e): return tr("Xato: ", "Error: ") + e
        case .throttled(let until):
            return tr("Anthropic so'rovni cheklab turibdi — \(Fmt.hourMinute.string(from: until)) da qayta urinadi (oxirgi raqamlar ko'rsatilyapti)", "Anthropic is rate-limiting — retrying at \(Fmt.hourMinute.string(from: until)) (showing last numbers)")
        }
    }

    /// Izohli toggle. Izoh bir satrga sig'sin: Form o'ralgan matnli qator balandligini kam hisoblab, qo'shni qator ustiga chizadi —
    /// to'liq tushuntirish maslahatda (help)
    private func captionToggle(_ title: String, _ caption: String, help: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(caption).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            Toggle(title, isOn: isOn).labelsHidden().toggleStyle(.switch)
        }
        .help(help)
    }

    private func toggleStatusLine(_ on: Bool) {
        do {
            if on { try StatusLine.install() } else { try StatusLine.uninstall() }
            statusLineError = nil
        } catch {
            statusLineError = error.localizedDescription
        }
        statusLineInstalled = StatusLine.isInstalled
    }

    private func toggleHook(_ on: Bool) {
        do {
            if on { try Hooks.install(); askPermission() } else { try Hooks.uninstall() }
            hookError = nil
        } catch {
            hookError = error.localizedDescription
        }
        hookInstalled = Hooks.isInstalled
    }

    private func refreshStatus() {
        hookInstalled = Hooks.isInstalled
        handoffHookInstalled = SessionStartHook.isInstalled
        statusLineInstalled = StatusLine.isInstalled
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
