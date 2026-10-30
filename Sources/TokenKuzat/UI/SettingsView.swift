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
    @AppStorage("settingsTab") private var tab = SettingsTab.general
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
    /// Tanlovda qisqartirish oynasidan past chegara bormi
    private func canPickLower(_ w: AutoCompactWindow.Found) -> Bool {
        AutoHandoffRule.thresholdOptionsK.contains { $0 * 1000 < Double(w.tokens) }
    }

    private var compactWindow: AutoCompactWindow.Found? {
        (try? StatusLine.readSettings()).flatMap { AutoCompactWindow.smallest(settings: $0) }
    }
    @AppStorage(Pref.autoHandoffRedirect) private var autoHandoffRedirect = true
    @AppStorage(Pref.autoResume) private var autoResume = true
    @AppStorage(Pref.delegateNudge) private var delegateNudge = true
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

    @ViewBuilder private var updateAction: some View {
        switch updates.install {
        case .downloading: ProgressView().controlSize(.small); Text(tr("Yuklanmoqda…", "Downloading…")).foregroundStyle(.secondary)
        case .installing: ProgressView().controlSize(.small); Text(tr("O'rnatilmoqda…", "Installing…")).foregroundStyle(.secondary)
        default:
            if updates.canInstallInPlace {
                Button(tr("Yangilash", "Update")) { updates.installUpdate() }
                    .buttonStyle(.tkPrimary)
                    .help(tr("Yuklaydi, tekshiradi va ilovani qayta ochadi", "Downloads, verifies and relaunches the app"))
            } else {
                Button(tr("Yuklab olish", "Download")) { updates.download() }.buttonStyle(.tkPrimary)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SettingsTabBar(selection: $tab)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) { page }
                    .frame(maxWidth: 680)
                    .padding(.horizontal, 28).padding(.top, 24).padding(.bottom, 40)
                    .frame(maxWidth: .infinity)
            }
            // Tab almashganda sahifa tepadan boshlanadi
            .id(tab)
        }
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

    @ViewBuilder private var page: some View {
        switch tab {
        case .general: generalPage
        case .notifications: notificationsPage
        case .sessions: sessionsPage
        case .limits: limitsPage
        case .freeModels: FreeModelsSection()
        case .data: dataPage
        }
    }

    // MARK: - Umumiy

    @ViewBuilder private var generalPage: some View {
        SettingsGroup(title: tr("Ilova", "App")) {
            SettingRow(symbol: "globe", title: "Til / Language",
                       subtitle: tr("Darhol qo'llanadi. «Tizim tili» — Mac inglizcha bo'lsa English, aks holda o'zbekcha",
                                    "Applies immediately. “System language” — English if your Mac is in English, otherwise Uzbek")) {
                SettingsMenu(title: "Til / Language", selection: Binding(get: { AppLanguage(rawValue: language) ?? .system }, set: { Lang.set($0) }),
                             options: AppLanguage.allCases.map { ($0, $0.title) })
            }
            ToggleRow(symbol: "power", title: tr("Mac yoqilganda ishga tushsin", "Launch at login"), isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { LaunchAtLogin.set($0) }
                .disabled(!AppInfo.isBundled)
        }

        SettingsGroup(title: tr("Yangilanish", "Updates")) {
            ToggleRow(symbol: "arrow.triangle.2.circlepath", title: tr("Yangi versiyani tekshirish", "Check for updates"),
                      subtitle: updateCaption, isOn: $checkUpdates) {
                if checkUpdates && updates.available == nil {
                    Button(tr("Hozir tekshirish", "Check now")) { updates.check() }
                        .buttonStyle(.link)
                        .disabled(updates.status == .checking)
                }
            }
            .onChange(of: checkUpdates) { on in if on { updates.start() } else { updates.stop() } }
            if let r = updates.available {
                SettingRow(title: tr("Yangi versiya chiqdi", "A new version is out"), child: true) {
                    StateChip(text: "v\(r.version)", kind: .ok, symbol: "arrow.down")
                    Button(tr("Reliz sahifasi", "Release page")) { NSWorkspace.shared.open(r.pageURL) }.buttonStyle(.link)
                    updateAction
                }
                if case .failed(let msg) = updates.install {
                    SettingRow(title: tr("Yangilab bo'lmadi", "Couldn't update"), subtitle: msg, child: true) {
                        Button(tr("DMG'ni yuklab olish", "Download the DMG")) { updates.download() }.buttonStyle(.link)
                    }
                }
            }
        }

        SettingsGroup(title: tr("Ko'rinish", "Appearance")) {
            SettingRow(symbol: "menubar.rectangle", title: tr("Menyu satrida", "Menu bar")) {
                SettingsMenu(title: tr("Menyu satrida", "Menu bar"), selection: $menuBarStyle,
                             options: MenuBarStyle.allCases.map { ($0, $0.title) })
            }
            ToggleRow(symbol: "wind", title: tr("Kam animatsiya", "Reduce motion"),
                      subtitle: tr("Robot, aylanuvchi chegaralar va oqim animatsiyalari to'xtaydi — oyna ochiq turganda protsessor taxminan ikki baravar kam ishlaydi",
                                   "Stops the robot, spinning borders and flow animations — uses about half the CPU while the window is open"),
                      isOn: $lightMode)
        }

        SettingsGroup(title: tr("Hisoblash", "Counting"),
                      footer: tr("Limitni nima ko'proq «yeyayotgani»ni «Narx bo'yicha» usuli yaxshiroq ko'rsatadi.",
                                 "«By cost» shows better what really «eats» your limit.")) {
            SettingRow(symbol: "function", title: tr("Hisoblash usuli", "Counting method"),
                       subtitle: mode == .raw ? tr("Har bir token teng sanaladi", "Every token counts the same")
                                              : tr("Har token kiritish narxiga nisbatan sanaladi:", "Each token is weighed against the input price:")) {
                SettingsSegments(title: tr("Hisoblash usuli", "Counting method"), selection: $mode, options: [
                    (CountMode.raw, tr("Token soni", "Token count")),
                    (CountMode.weighted, tr("Narx bo'yicha", "By cost")),
                ])
            } below: {
                if mode == .weighted { weightTags.padding(.top, 6) }
            }
        }
    }

    /// Narx bo'yicha og'irliklar; tor oynada ikki qatorga bo'linadi
    private var weightTags: some View {
        let tags = [
            WeightTag(label: tr("javob", "output"), value: "×" + fmt(Pricing.output)),
            WeightTag(label: tr("kesh o'qish", "cache read"), value: "×" + fmt(Pricing.cacheRead)),
            WeightTag(label: tr("kesh yozish", "cache write"), value: "×" + fmt(Pricing.cacheWrite5m)),
            WeightTag(label: tr("1 soatlik kesh", "1-hour cache"), value: "×" + fmt(Pricing.cacheWrite1h)),
        ]
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { ForEach(0..<4) { tags[$0] } }
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) { tags[0]; tags[1] }
                HStack(spacing: 6) { tags[2]; tags[3] }
            }
            VStack(alignment: .leading, spacing: 6) { ForEach(0..<4) { tags[$0] } }
        }
    }

    // MARK: - Xabarlar

    @ViewBuilder private var notificationsPage: some View {
        SettingsGroup(title: tr("Bildirishnomalar", "Notifications")) {
            SettingRow(symbol: "bell.badge", title: tr("Qaysilari chiqsin", "Which to show"),
                       subtitle: tr("«Faqat muhim» — ish tugadi, ruxsat kutilyapti, xato va limit; maslahatlar (kontekst, isrof, kesh) chiqmaydi",
                                    "\"Important only\" — task finished, waiting for permission, errors and limits; no tips (context, waste, cache)")) {
                SettingsMenu(title: tr("Bildirishnomalar", "Notifications"), selection: Binding(get: { NotifyMode.current() }, set: { $0.apply() }),
                             options: NotifyMode.allCases.filter { $0 != .custom || NotifyMode.current() == .custom }.map { ($0, $0.title) })
            }
        }
        .disabled(!AppInfo.isBundled)

        SettingsGroup(title: tr("Ish holati", "Work status")) {
            ToggleRow(symbol: "checkmark.circle", title: tr("Claude ishni tugatganda", "When Claude finishes a task"), isOn: $notifyFinished)
                .onChange(of: notifyFinished) { if $0 { askPermission() } }
            SettingRow(title: tr("…agar ish shundan uzoq davom etgan bo'lsa", "…if it ran longer than"), child: true) {
                SettingsMenu(title: tr("…agar ish shundan uzoq davom etgan bo'lsa", "…if it ran longer than"), selection: $notifyFinishedMin, options: [
                    (0.0, tr("har doim", "always")),
                    (30.0, tr("30 soniya", "30 seconds")),
                    (60.0, tr("1 daqiqa", "1 minute")),
                    (180.0, tr("3 daqiqa", "3 minutes")),
                    (600.0, tr("10 daqiqa", "10 minutes")),
                ])
            }
            .disabled(!notifyFinished)
            ToggleRow(symbol: "hourglass", title: tr("Qadam uzoq tugamasa", "When a step takes too long"),
                      subtitle: tr("Ruxsat kutilayotgan bo'lishi mumkin", "It may be waiting for permission"), isOn: $notifyStuck)
                .onChange(of: notifyStuck) { if $0 { askPermission() } }
            SettingRow(title: tr("…shundan keyin", "…after"), child: true) {
                SettingsMenu(title: tr("…shundan keyin", "…after"), selection: $notifyStuckSec, options: [
                    (30.0, tr("30 soniya", "30 seconds")),
                    (90.0, tr("1,5 daqiqa", "1.5 minutes")),
                    (180.0, tr("3 daqiqa", "3 minutes")),
                    (300.0, tr("5 daqiqa", "5 minutes")),
                ])
            }
            .disabled(!notifyStuck)
            ToggleRow(symbol: "hand.raised", title: tr("Claude ruxsat so'raganda", "When Claude asks for permission"),
                      subtitle: hookInstalled ? nil : tr("«Ulash» settings.json ga hook qo'shadi; yangi sessiyalarda ishlaydi",
                                                         "«Connect» adds a hook to settings.json; it works in new sessions"),
                      isOn: $notifyPermission) {
                if hookInstalled {
                    StateChip(text: tr("Ulangan", "Connected"), kind: .ok, symbol: "checkmark")
                    Button(tr("Uzish", "Disconnect")) { toggleHook(false) }.buttonStyle(.tkSecondary)
                } else {
                    Button(tr("Ulash", "Connect")) { toggleHook(true) }.buttonStyle(.tkSecondary)
                }
            }
            if let hookError {
                WideRow(child: true) {
                    Label(hookError, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(Brand.err)
                }
            }
            ToggleRow(symbol: "exclamationmark.triangle", title: tr("Agent ketma-ket 3 marta xato olsa", "When an agent hits 3 errors in a row"), isOn: $notifyErrors)
                .onChange(of: notifyErrors) { if $0 { askPermission() } }
        }
        .disabled(!AppInfo.isBundled)

        SettingsGroup(title: tr("Token tejash maslahatlari", "Token-saving tips")) {
            ToggleRow(symbol: "chart.pie", title: tr("Kontekst 85% to'lganda", "When context is 85% full"),
                      subtitle: tr("Claude Code tez orada suhbatni o'zi qisqartiradi", "Claude Code will soon compact the conversation by itself"), isOn: $notifyContext)
            ToggleRow(symbol: "arrow.triangle.branch", title: tr("Katta kontekstda yangi mavzu boshlansa", "New topic in a large context"),
                      subtitle: tr("Yangi sessiya taklif qilinadi — token tejaydi", "Suggests a new session — saves tokens"), isOn: $notifySavings)
            ToggleRow(symbol: "trash", title: tr("Isrof", "Waste"),
                      subtitle: tr("Kontekst 200K dan oshsa yoki loyiha bugun sarfining 40%+ ini isrof qilsa",
                                   "Context passes 200K, or a project wastes 40%+ of today's usage"), isOn: $notifyWaste)
            ToggleRow(symbol: "snowflake", title: tr("Kesh sovishidan oldin", "Before the cache cools"),
                      subtitle: tr("Javobingizni kutayotgan katta sessiyada", "In a large session waiting for your reply"), isOn: $notifyCache)
        }
        .disabled(!AppInfo.isBundled)

        SettingsGroup(footer: tr("Bildirishnomani bosing — o'sha sessiya ochiladi.", "Click a notification to open that session.")) {
            SettingRow(symbol: "paperplane", title: tr("Sinov bildirishnomasi", "Test notification"),
                       subtitle: tr("Bildirishnomalar ishlashini tekshiring", "Check that notifications work")) {
                Button(tr("Yuborish", "Send")) { Alerts.shared.sendTest() }.buttonStyle(.tkSecondary)
            }
            if notifyDenied {
                SettingRow(symbol: "exclamationmark.triangle", title: tr("macOS bildirishnomalarga ruxsat bermagan", "macOS hasn't allowed notifications")) {
                    StateChip(text: tr("Ruxsat yo'q", "Not allowed"), kind: .warn)
                    Button(tr("Ruxsat berish…", "Allow…")) {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=uz.ali.tokenkuzat")!)
                    }
                    .buttonStyle(.tkSecondary)
                }
            }
        }
        .disabled(!AppInfo.isBundled)
    }

    // MARK: - Sessiyalar

    @ViewBuilder private var sessionsPage: some View {
        SettingsGroup(title: tr("Avtomatik yangi sessiya", "Automatic new session"),
                      footer: tr("Kontekst katta bo'lganda ish xulosa bilan yangi sessiyaga ko'chadi — limit sekinroq tugaydi.",
                                 "When the context gets large, work moves to a new session with a summary — the limit lasts longer."),
                      more: tr("Claude javobni tugatgach yangi sessiya xulosa bilan ochiladi; ish o'rtasida to'xtatilmaydi. Yangi sessiya Claude ilovasida ochiladi, xulosa yozib qo'yiladi — Enter bosasiz "
                               + "(ilova tashqaridan kelgan xabarni xavfsizlik uchun o'zi yubormaydi).",
                               "After Claude finishes its reply, a new session opens with the summary; work is never interrupted. The new session opens in the Claude app with the summary filled in — you press Enter "
                               + "(the app doesn't send outside messages by itself, for safety).")) {
            ToggleRow(symbol: "arrow.left.arrow.right", title: tr("Kontekst katta bo'lsa — avtomatik yangi sessiya", "Large context — open a new session automatically"),
                      subtitle: tr("Javob tugagach xulosa bilan yangi sessiya ochiladi — ish to'xtatilmaydi", "Opens a new session with the summary after Claude's reply — work isn't interrupted"),
                      isOn: $autoHandoff)
                .onChange(of: autoHandoff) { on in
                    if !on { try? PromptRedirectHook.uninstall(); try? PreCompactHook.uninstall() }
                }
            Group {
                SettingRow(title: tr("…kontekst oshganda", "…when context passes"), child: true) {
                    SettingsMenu(title: tr("…kontekst oshganda", "…when context passes"), selection: $autoHandoffK,
                                 options: AutoHandoffRule.thresholdOptionsK.map { ($0, Fmt.tokens($0 * 1000)) })
                }
                if autoHandoff, let w = compactWindow, Double(w.tokens) <= autoHandoffK * 1000 {
                    WideRow(child: true) { compactWarning(w) }
                }
                ToggleRow(title: tr("…eski sessiyada yozsam — yangi sessiyaga yo'naltirish", "…if I type in the old session — redirect to the new one"),
                          subtitle: tr("Keyingi xabaringiz xulosa bilan yangi sessiyaga ketadi", "Your next message goes to the new session with the summary"),
                          child: true, isOn: $autoHandoffRedirect)
                    .help(tr("Birinchi xabar to'xtatilib, xulosa bilan yangi sessiyaga yuboriladi; qayta yuborsangiz — eski sessiyada qoladi",
                             "The first message is stopped and sent to the new session with the summary; send it again to stay in the old session"))
                    // Hook eslatma so'rovi uchun ham kerak — avtomatik ko'chirish yoqiq bo'lsa, faqat yo'naltirishlar o'chiriladi
                    .onChange(of: autoHandoffRedirect) { on in if !on { try? FileManager.default.removeItem(at: RedirectStore.defaultURL) } }
            }
            .disabled(!autoHandoff)
        }
        .disabled(!AppInfo.isBundled)

        SettingsGroup(title: tr("Davom ettirish", "Resume"),
                      footer: tr("Har yangi sessiya boshida ~2–3K token.", "~2–3K tokens at the start of each new session."),
                      more: tr("Oyna yopilgan yoki tashlab ketilgan sessiyaning xulosasi (24 soat ichida) shu papkada ochilgan keyingi yangi sessiyaga "
                               + "o'zi beriladi — har loyiha o'z papkasi bo'yicha. Boshqa mavzuda boshlasangiz, Claude uni e'tiborsiz qoldiradi.",
                               "The summary of a session whose window was closed or left (within 24 hours) is passed to the next new session "
                               + "opened in the same folder — each project by its own folder. Start on another topic and Claude ignores it.")) {
            ToggleRow(symbol: "clock.arrow.circlepath", title: tr("Yopilgan sessiyani avtomatik davom ettirish", "Auto-resume a closed session"),
                      subtitle: tr("Shu papkada yangi sessiya ochsangiz, Claude qayerda qolganini o'zi biladi", "Open a new session in the same folder and Claude knows where things stopped"),
                      isOn: $autoResume) {
                // Hook avtomatik ko'chirishda ham o'rnatiladi — kalit o'chiq turganda «Ulangan» chiqib, chalg'itmasin
                if handoffHookInstalled && autoResume {
                    StateChip(text: tr("Ulangan", "Connected"), kind: .ok, symbol: "checkmark")
                    Button(tr("Uzish", "Disconnect")) {
                        try? SessionStartHook.uninstall()
                        handoffHookInstalled = SessionStartHook.isInstalled
                        // Avtomatik davom ham shu hook'da — keyingi ishga tushishda qayta ulanmasin
                        autoResume = false
                    }
                    .buttonStyle(.tkSecondary)
                }
            }
            .onChange(of: autoResume) { on in
                if on {
                    try? SessionStartHook.install()
                    handoffHookInstalled = SessionStartHook.isInstalled
                } else {
                    ProjectTracker.shared.disableResume()
                }
            }
        }
        .disabled(!AppInfo.isBundled)

        SettingsGroup(title: tr("Yordamchi agentlar", "Helper agents"),
                      footer: tr("Faqat Token Kuzatuv plagini o'rnatilgan bo'lsa ishlaydi (tokenkuzat:izlovchi).", "Works only when the Token Kuzatuv plugin is installed (tokenkuzat:izlovchi).")) {
            ToggleRow(symbol: "person.2", title: tr("Ko'p o'qisangiz — yordamchiga berishni eslatish", "Many reads — remind to use a helper"),
                      subtitle: tr("Claude yordamchisiz ko'p fayl o'qisa, qidiruvni izlovchiga berishni eslatadi", "If Claude reads many files without a helper, it is reminded to hand searches to the finder"),
                      isOn: $delegateNudge)
                .help(tr("Sessiyada yordamchi agent ishlatilmagan va 15 ta o'qish/qidiruv bajarilgan bo'lsa (keyin har 15 tada), Claude'ga qisqa eslatma beriladi. Hech narsani bloklamaydi",
                         "When no helper agent was used in a session and 15 reads/searches were done (then every 15), Claude gets a short reminder. Nothing is blocked"))
                .onChange(of: delegateNudge) { on in DelegateNudgeHook.sync(enabled: on) }
        }
        .disabled(!AppInfo.isBundled)
    }

    private func compactWarning(_ w: AutoCompactWindow.Found) -> some View {
        Label(tr("Claude Code suhbatni \(Fmt.tokens(w.tokens)) da o'zi qisqartiradi (\(w.source)) — bu ko'chirish chegarasidan "
                 + "(\(Fmt.tokens(Int(autoHandoffK * 1000)))) kichik. Ilova qisqartirishni bir marta to'xtatib, ishni yangi sessiyaga ko'chiradi. "
                 + (canPickLower(w)
                    ? "Har doim ishonchli bo'lishi uchun chegarani \(Fmt.tokens(w.tokens)) dan pastroq tanlang."
                    : "Tanlovda \(Fmt.tokens(w.tokens)) dan past chegara yo'q — ishonchli bo'lishi uchun ~/.claude/settings.json dagi autoCompactWindow ni oshiring yoki olib tashlang."),
                 "Claude Code compacts the conversation by itself at \(Fmt.tokens(w.tokens)) (\(w.source)) — below the handoff threshold "
                 + "(\(Fmt.tokens(Int(autoHandoffK * 1000)))). The app stops compaction once and moves the work to a new session. "
                 + (canPickLower(w)
                    ? "To be safe every time, pick a threshold below \(Fmt.tokens(w.tokens))."
                    : "No threshold below \(Fmt.tokens(w.tokens)) is available — to be safe, raise or remove autoCompactWindow in ~/.claude/settings.json.")),
              systemImage: "exclamationmark.triangle.fill")
            .font(.caption).foregroundStyle(Brand.warn)
    }

    // MARK: - Limitlar

    @ViewBuilder private var limitsPage: some View {
        SettingsGroup(title: tr("Claude limiti — hisobdan", "Claude limit — from account"),
                      footer: tr("claude.ai dagi raqamlar bilan bir xil.", "Same numbers as claude.ai."),
                      more: tr("Claude Code'ning Keychain'dagi kirish kaliti bilan Anthropic'dan 5 soatlik va haftalik limit har 1,5 daqiqada olinadi — Code tabi va Claude ilovasida ham ishlaydi. Kalit faqat shu kompyuterda o'qiladi va faqat api.anthropic.com ga yuboriladi. Birinchi marta macOS Keychain ruxsatini so'raydi («Har doim ruxsat»). Ishlamasa — pastdagi status line zaxira manba bo'ladi. Yoqilgan bo'lsa, limitning chat va bulutga (Mac'ga yozilmaydigan ishlarga) ketgan qismi ham hisoblanadi.",
                               "Using Claude Code's sign-in key from Keychain, the current session and weekly limits are fetched from Anthropic every 90 seconds — works for the Code tab and the Claude app too. The key is read only on this computer and sent only to api.anthropic.com. The first time, macOS asks for Keychain access («Always Allow»). If it doesn't work, the status line below is the fallback source. When on, the part of the limit spent in chat & cloud (work not written to this Mac) is calculated too.")) {
            ToggleRow(symbol: "person.crop.circle", title: tr("Claude hisobidan olish", "Fetch from Claude account"), isOn: $accountUsage)
                .onChange(of: accountUsage) { on in
                    if on { AccountUsage.shared.start(); AccountUsage.shared.refreshNow() } else { AccountUsage.shared.stop() }
                    refreshAccount()
                }
            if accountUsage {
                SettingRow(title: tr("Holat", "Status"), subtitle: accountDetail, child: true) {
                    StateChip(text: accountChip.text, kind: accountChip.kind, symbol: accountChip.kind == .ok ? "checkmark" : nil)
                    Button(tr("Hozir yangilash", "Refresh now")) { AccountUsage.shared.refreshNow(); refreshAccountLater() }
                        .buttonStyle(.tkSecondary)
                }
                if let l = store.snap.limits, !l.isEmpty {
                    WideRow(child: true) { RealLimitsView(limits: l, forecast: store.snap.fiveHourForecast) }
                }
            }
        }
        .onAppear(perform: refreshAccount)

        SettingsGroup(title: tr("Claude limiti — status line orqali", "Claude limit — via status line"),
                      footer: tr("Hisobdan olish ishlamasa — zaxira manba.", "The fallback when fetching from the account doesn't work."),
                      more: tr("Claude Code har bir javobdan keyin status line'ga 5 soatlik va haftalik limit foizini beradi (Pro/Max obunada). «Ulash» ~/.claude/settings.json ga Token Kuzatuv'ni status line qilib yozadi: terminalda pastki satrda «5 soat 34% ↻16:40 · hafta 61%» ko'rinadi. Avvalgi status line bo'lsa — saqlanadi va ishlashda davom etadi; «Uzish» uni qaytaradi. Birinchi ulanishda settings.json nusxasi olinadi.",
                               "After each reply, Claude Code passes the 5-hour and weekly limit percentages to the status line (Pro/Max plans). «Connect» sets Token Kuzatuv as the status line in ~/.claude/settings.json: the terminal's bottom line shows «5h 34% ↻16:40 · week 61%». An existing status line is kept and keeps working; «Disconnect» restores it. A backup of settings.json is made on first connect.")) {
            SettingRow(symbol: "terminal", title: "Status line", subtitle: statusLineDetail) {
                StateChip(text: statusLineInstalled ? tr("Ulangan", "Connected") : tr("Ulanmagan", "Not connected"),
                          kind: statusLineKind, symbol: statusLineKind == .ok ? "checkmark" : nil)
                if statusLineInstalled {
                    Button(tr("Uzish", "Disconnect")) { toggleStatusLine(false) }.buttonStyle(.tkSecondary)
                } else {
                    Button(tr("Limitlarni ulash", "Connect limits")) { toggleStatusLine(true) }.buttonStyle(.tkPrimary)
                }
            } below: {
                Button(tr("settings.json'ni ko'rsatish", "Show settings.json")) {
                    NSWorkspace.shared.activateFileViewerSelecting([StatusLine.settingsURL])
                }
                .buttonStyle(.link).font(.system(size: 12)).padding(.top, 2)
            }
            if let statusLineError {
                WideRow(child: true) {
                    Label(statusLineError, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(Brand.err)
                }
            }
            // Hisobdan olish yoqiq bo'lsa, shkalalar yuqoridagi guruhda
            if !accountUsage, let l = store.snap.limits, !l.isEmpty {
                WideRow(child: true) { RealLimitsView(limits: l, forecast: store.snap.fiveHourForecast) }
            }
            ToggleRow(symbol: "bell", title: tr("80% va 95% ga yetganda bildirishnoma", "Notify at 80% and 95%"), isOn: $notifyRealLimit)
                .disabled(!statusLineInstalled || !AppInfo.isBundled)
                .onChange(of: notifyRealLimit) { if $0 { askPermission() } }
        }

        SettingsGroup(title: tr("O'z limitim (taxminiy)", "My own limit (estimate)"),
                      footer: tr("Claude obunasi limiti 5 soatlik oyna bo'yicha tiklanadi. Anthropic aniq limitni e'lon qilmaydi — o'zingizning odatiy sarfingizga qarab qiymat qo'ying (Tarix sahifasida ko'rinadi).",
                                 "Claude plan limits reset on a 5-hour window. Anthropic doesn't publish the exact limit — set a value based on your typical usage (shown on the History page).")) {
            ToggleRow(symbol: "target", title: tr("Limitni kuzatish", "Track limit"), isOn: $budgetEnabled)
            Group {
                SettingRow(title: tr("Davr", "Period"), child: true) {
                    SettingsSegments(title: tr("Davr", "Period"), selection: $budgetPeriod,
                                     options: BudgetPeriod.allCases.map { ($0, $0.title) })
                }
                SettingRow(title: tr("Limit", "Limit"), subtitle: tr("mln token (narx bo'yicha)", "M tokens (by price)"), child: true) {
                    TextField(tr("Limit", "Limit"), value: $budgetLimitM, format: .number.precision(.fractionLength(0...1)))
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                        .tkField()
                        .frame(width: 72)
                        // 0 yoki manfiy limit foizni buzadi — Stepper chegarasiga keltiriladi
                        .onChange(of: budgetLimitM) { v in
                            let c = min(max(v, 1), 2000)
                            if c != v { budgetLimitM = c }
                        }
                    TKStepper(title: tr("Limit", "Limit"), value: $budgetLimitM, range: 1...2000, step: 5)
                }
                ToggleRow(title: tr("80% va 100% da bildirishnoma", "Notify at 80% and 100%"), child: true, isOn: $budgetNotify)
                    .disabled(!AppInfo.isBundled)
                    .onChange(of: budgetNotify) { if $0 { askPermission() } }
            }
            .disabled(!budgetEnabled)
            if budgetEnabled, let b = BudgetStatus.current(store.snap) {
                WideRow(child: true) { BudgetBar(status: b) }
            }
        }
    }

    private var statusLineKind: StateChip.Kind {
        guard statusLineInstalled else { return .off }
        return store.snap.limits.map { !$0.isEmpty } == true ? .ok : .warn
    }

    private var statusLineDetail: String {
        guard statusLineInstalled else { return tr("Terminal pastki satri orqali 5 soatlik va haftalik foiz olinadi", "Gets the 5-hour and weekly percentages through the terminal's bottom line") }
        if let l = store.snap.limits, !l.isEmpty { return tr("Ma'lumot \(Fmt.ago(l.updatedAt))", "Data \(Fmt.ago(l.updatedAt))") }
        if let t = StatusLine.lastUpdate { return tr("Oxirgi chaqiruv \(Fmt.ago(t)), limit kelmadi (API kaliti bilanmi?)", "Last call \(Fmt.ago(t)), no limit received (using an API key?)") }
        return tr("Claude Code'da yangi so'rov kutilyapti", "Waiting for a new prompt in Claude Code")
    }

    private func refreshAccount() { accountStatus = AccountUsage.shared.status }

    private func refreshAccountLater() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { refreshAccount() }
    }

    private var accountChip: (text: String, kind: StateChip.Kind) {
        switch accountStatus {
        case .off: return (tr("O'chirilgan", "Off"), .off)
        case .loading: return (tr("Olinmoqda…", "Fetching…"), .off)
        case .ok: return (tr("Ulangan", "Connected"), .ok)
        case .noCredentials: return (tr("Kalit topilmadi", "No key"), .warn)
        case .expired: return (tr("Kalit eskirgan", "Key expired"), .warn)
        case .throttled: return (tr("Cheklangan", "Rate-limited"), .warn)
        case .failed: return (tr("Xato", "Error"), .err)
        }
    }

    private var accountDetail: String? {
        switch accountStatus {
        case .off, .loading: return nil
        case .ok(let t): return Fmt.ago(t) + (store.snap.limits?.plan.map { " · " + $0 } ?? "")
        case .noCredentials: return tr("Claude Code'ga kiring yoki Keychain ruxsatini bering", "Sign in to Claude Code or allow Keychain access")
        case .expired: return tr("Claude Code'da biror so'rov yuboring", "Send any prompt in Claude Code")
        case .failed(let e): return e
        case .throttled(let until):
            return tr("Anthropic so'rovni cheklab turibdi — \(Fmt.hourMinute.string(from: until)) da qayta urinadi (oxirgi raqamlar ko'rsatilyapti)", "Anthropic is rate-limiting — retrying at \(Fmt.hourMinute.string(from: until)) (showing last numbers)")
        }
    }

    // MARK: - Ma'lumot

    @ViewBuilder private var dataPage: some View {
        SettingsGroup(title: tr("Manbalar", "Sources"),
                      footer: tr("Shu Mac'dagi ~/.claude fayllarini va o'zingiz qo'shgan chat yozuvlarini o'qiydi. Yozuvlar internetga yuborilmaydi.", "Reads ~/.claude files on this Mac and chat transcripts you add. Nothing is sent to the internet.")) {
            SettingRow(symbol: "doc.on.doc", title: tr("Kuzatilayotgan fayllar", "Watched files")) {
                Text(tr("\(store.snap.filesWatched) ta", "\(store.snap.filesWatched)")).fontWeight(.semibold).monospacedDigit()
                Text(tr("oxirgi 30 kun", "last 30 days")).foregroundStyle(.secondary)
            }
            ForEach(store.snap.sources) { src in
                SettingRow(symbol: src.exists ? "folder.fill" : "folder", title: src.path, subtitle: SourcesList.detail(src), mono: true) {
                    if !src.exists {
                        StateChip(text: tr("Yo'q", "Missing"))
                    } else if src.recent > 0 {
                        StateChip(text: tr("Faol", "Active"), kind: .ok, symbol: "checkmark")
                    } else {
                        StateChip(text: tr("Faol emas", "Inactive"))
                    }
                }
            }
        }

        SettingsGroup(title: tr("Bulutdagi chatlar", "Cloud chats"),
                      footer: tr(".jsonl faylni shu tugma bilan qo'shing yoki oynaga sudrab tashlang.", "Add the .jsonl file with this button or drag it onto the window."),
                      more: tr("Claude chat va bulutdagi sessiyalar Mac'ga yozilmaydi. Chatdan Claude'ga «yozuvini Token Kuzatuv uchun ber» deng va kelgan faylni qo'shing. Xaritada «\(ChatImport.projectName)» loyihasi bo'lib chiqadi.",
                               "Claude chat and cloud sessions aren't written to this Mac. In chat, ask Claude to «export the transcript for Token Kuzatuv» and add the file it gives you. It shows up on the map as the «\(ChatImport.projectName)» project.")) {
            SettingRow(symbol: "icloud.and.arrow.down", title: tr("Chat yozuvini qo'shish", "Add a chat transcript")) {
                Button(tr("Papkani ochish", "Open folder")) {
                    try? FileManager.default.createDirectory(at: ChatImport.directory, withIntermediateDirectories: true)
                    NSWorkspace.shared.open(ChatImport.directory)
                }
                .buttonStyle(.link)
                Button(tr("Qo'shish…", "Add…")) { ChatImporter.pick() }.buttonStyle(.tkSecondary)
            }
        }

        SettingsGroup(title: tr("Fayllar", "Files")) {
            SettingRow(symbol: "folder", title: tr("Claude papkasi", "Claude folder")) {
                Button(tr("Ochish", "Open")) { NSWorkspace.shared.open(Engine.primaryRoot) }.buttonStyle(.tkSecondary)
            }
            SettingRow(symbol: "clock", title: tr("Tarix fayli", "History file")) {
                Button(tr("Finder'da ko'rsatish", "Show in Finder")) { NSWorkspace.shared.activateFileViewerSelecting([HistoryStore.defaultURL]) }.buttonStyle(.tkSecondary)
            }
        }

        SettingsGroup(title: tr("Xavfli", "Danger zone"), danger: true) {
            SettingRow(symbol: "trash", title: tr("Tarixni tozalash", "Clear history"),
                       subtitle: tr("Oxirgi 30 kun qayta o'qiladi, undan eskilari tiklanmaydi", "The last 30 days are re-read; older days can't be restored")) {
                Button(role: .destructive) { confirmClear = true } label: {
                    Text(tr("Tozalash…", "Clear…")).foregroundStyle(Brand.err)
                }
                .buttonStyle(.tkDestructive)
            }
        }

        SettingsGroup(title: tr("Ilova haqida", "About")) {
            SettingRow(symbol: "info.circle", title: tr("Versiya", "Version")) {
                Text("\(AppInfo.version) (\(AppInfo.build))").foregroundStyle(.secondary).monospacedDigit().textSelection(.enabled)
            }
        }
    }

    // MARK: - Amallar

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
        return Lang.isEnglish ? s : s.replacingOccurrences(of: ".", with: ",")
    }
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case general, notifications, sessions, limits, freeModels, data
    var id: String { rawValue }
    var title: String {
        switch self {
        case .general: return tr("Umumiy", "General")
        case .notifications: return tr("Xabarlar", "Alerts")
        case .sessions: return tr("Sessiyalar", "Sessions")
        case .limits: return tr("Limitlar", "Limits")
        case .freeModels: return tr("Bepul modellar", "Free models")
        case .data: return tr("Ma'lumot", "Data")
        }
    }
    var symbol: String {
        switch self {
        case .general: return "slider.horizontal.3"
        case .notifications: return "bell.fill"
        case .sessions: return "bubble.left.and.bubble.right.fill"
        case .limits: return "speedometer"
        case .freeModels: return "sparkles"
        case .data: return "cylinder.split.1x2.fill"
        }
    }
    /// Tanlangan tab plitkasi rangi — mavjud toifa ranglaridan
    var tint: Color {
        switch self {
        case .general: return Brand.accent
        case .notifications: return Hue.mcp
        case .sessions: return Hue.files
        case .limits: return Hue.web
        case .freeModels: return Brand.avatars[4]
        case .data: return Brand.avatars[5]
        }
    }
    /// Sozlamalar shu bo'limda ochilsin (masalan, «Limitlarni ulash» tugmasidan)
    func select() { UserDefaults.standard.set(rawValue, forKey: "settingsTab") }
}
