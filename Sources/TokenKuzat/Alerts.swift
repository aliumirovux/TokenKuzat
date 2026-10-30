import Foundation
import AppKit
import UserNotifications
import TokenKuzatCore

/// Barcha macOS bildirishnomalari: limit (80% / 100%) va sessiya hodisalari (tugadi, osildi, ketma-ket xato).
/// Bildirishnoma bosilsa — o'sha sessiya sxemada ochiladi.
final class Alerts: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Alerts()

    private let thresholds: [Double] = [0.8, 1.0]
    private let firedKey = "budgetFired"
    private let epochKey = "budgetEpoch"
    private let monitor = ActivityMonitor()
    private var center: UNUserNotificationCenter? {
        AppInfo.isBundled ? UNUserNotificationCenter.current() : nil
    }

    /// Ilova ochilganda: delegat va (biror bildirishnoma yoqilgan bo'lsa) ruxsat so'rovi
    func start() {
        guard let center else { return }
        center.delegate = self
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Self.freeCategory, actions: [
                UNNotificationAction(identifier: Self.freeAction, title: tr("Bepul modelda davom etish", "Continue on a free model"), options: []),
            ], intentIdentifiers: []),
            UNNotificationCategory(identifier: Self.backCategory, actions: [
                UNNotificationAction(identifier: Self.backAction, title: tr("Claude'da davom etish", "Continue in Claude"), options: []),
            ], intentIdentifiers: []),
        ])
        let d = UserDefaults.standard
        let any = [Pref.notifyFinished, Pref.notifyStuck, Pref.notifyErrors, Pref.notifyRealLimit,
                   Pref.notifyPermission, Pref.notifyContext, Pref.notifyWaste, Pref.notifyCache].contains { d.bool(forKey: $0) }
            || (d.bool(forKey: Pref.budgetEnabled) && d.bool(forKey: Pref.budgetNotify))
        if any { requestPermission() }
    }

    func requestPermission(_ done: ((Bool) -> Void)? = nil) {
        guard let center else { done?(false); return }
        center.requestAuthorization(options: [.alert, .sound]) { ok, _ in
            DispatchQueue.main.async { done?(ok) }
        }
    }

    /// Sozlamalardagi «Sinov bildirishnomasi» tugmasi
    func sendTest() {
        requestPermission { _ in
            self.post(tr("Token Kuzatuv: bildirishnomalar ishlayapti", "Token Kuzatuv: notifications are working"),
                      tr("Claude ishni tugatganda, qadam osilib qolganda yoki xatolar takrorlanganda shunday xabar keladi.",
                         "You'll get a message like this when Claude finishes, a step gets stuck, or errors repeat."))
        }
    }

    // MARK: - Bepul modellar

    private static let freeCategory = "free-fallback"
    private static let freeAction = "free.start"
    private static let backCategory = "claude-back"
    private static let backAction = "claude.back"

    /// Limit tugaganda bepul modelda davom etish taklif qilinsinmi: yoqilgan va server sozlangan
    private var offerFree: Bool {
        UserDefaults.standard.bool(forKey: Pref.freeFallback) && FreeModels.load() != nil
    }

    /// Bildirishnomadagi tugma: ish terminalda bepul modelda davom etadi
    private func startFree(session: String?, resetsAt: Date?) {
        let sess = FreeFallback.source(in: Store.shared.snap, preferred: session)
        FreeFallback.start(from: sess, resetsAt: resetsAt) { ok in
            if !ok {
                self.post(tr("Bepul modelda ochib bo'lmadi", "Couldn't open on a free model"),
                          tr("Sozlamalar → «Bepul modellar»da manzil va kalitni tekshiring.", "Check the address and key in Settings → «Free models»."),
                          section: .settings)
            }
        }
    }

    /// Bildirishnomadagi tugma: bepul modeldagi ish Claude'ga qaytadi
    private func backToClaude(since: Date?) {
        FreeFallback.returnToClaude(in: Store.shared.snap, since: since) { ok in
            if !ok {
                self.post(tr("Claude'ga qaytaradigan ish topilmadi", "No work to move back to Claude"),
                          tr("Limit tugaganidan keyin bepul modelda ishlangan sessiya yo'q. Claude'ni odatdagidek oching.",
                             "No session ran on a free model after the limit ran out. Open Claude as usual."),
                          section: .overview)
            }
        }
    }

    func evaluate(_ s: Snapshot) {
        evaluateBudget(s)
        evaluateActivity(s)
        evaluateRealLimits(s)
        evaluateFailures(s)
        evaluatePermission(s)
        evaluateContext(s)
        evaluateSavings(s)
        evaluateBigContext(s)
        evaluateProjectWaste(s)
        evaluateAutoHandoff(s)
        evaluateCache(s)
    }

    // MARK: - Kesh taymeri

    /// Rejalashtirilgan ogohlantirishlar: sessiya → o'sha paytdagi sovish vaqti
    private var cacheScheduled: [String: Date] = [:]

    /// Javobni kutib turgan katta sessiyaning keshi sovishidan oldin — bir marta. Bildirishnoma oldindan
    /// rejalashtiriladi (ilova jim turganda ham o'z vaqtida chiqadi); yangi so'rov yozilsa — bekor qilinadi
    private func evaluateCache(_ s: Snapshot) {
        guard let center else { return }
        let now = Date()
        var keep: Set<String> = []
        if s.initialScanDone, UserDefaults.standard.bool(forKey: Pref.notifyCache) {
            let k = UserDefaults.standard.double(forKey: Pref.autoHandoffK)
            for sess in s.sessions where sess.state == .idle && s.permissionWaits[sess.id] == nil {
                guard let c = CacheClock.of(sess), c.isWarm(at: now),
                      // Yangi sessiyaga ko'chirilgan — unda davom etilmaydi
                      !AutoHandoffRule.alreadyDone(doneAt: autoDoneContext[sess.id], known: autoDone[sess.id] != nil,
                                                   context: sess.contextTokens, thresholdK: k) else { continue }
                keep.insert(sess.id)
                let fire = c.remaining(at: now) - c.warnBefore
                guard cacheScheduled[sess.id] != c.expiresAt, fire > 0 else { continue }
                cacheScheduled[sess.id] = c.expiresAt
                let left = c.warnBefore >= 300 ? tr("5 daqiqada", "in 5 minutes") : tr("1 daqiqada", "in 1 minute")
                post(tr("\(sess.project): kesh \(left) soviydi", "\(sess.project): cache cools \(left)"),
                     tr("Keyingi so'rov \(Fmt.tokens(c.tokens)) kontekstni qaytadan yozadi — iliq keshdagidan ~\(c.coldMultiplier)× qimmat. "
                        + "Davom etsangiz — hozir yozing; uzoq tanaffusdan keyin yangi mavzu bo'lsa — yangi sessiya arzonroq.",
                        "The next prompt will rewrite the \(Fmt.tokens(c.tokens)) context — ~\(c.coldMultiplier)× the warm price. "
                        + "If you're continuing, write now; after a long break on a new topic, a new session is cheaper."),
                     session: sess.id, id: "cache-" + sess.id, after: fire)
            }
        }
        let gone = cacheScheduled.keys.filter { !keep.contains($0) }
        guard !gone.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: gone.map { "cache-" + $0 })
        gone.forEach { cacheScheduled[$0] = nil }
    }

    // MARK: - Avtomatik yangi sessiya

    private var autoPrevious: [String: AgentState] = [:]
    /// Eslatma so'ralayotgan sessiyalar (faylga faqat to'plam o'zgarganda yoziladi; kontekst — 10K aniqlikda)
    private var noteRequests: [String: NoteRequestStore.Request]?

    private func updateNoteRequests(_ wanted: [String: NoteRequestStore.Request]) {
        let rounded = wanted.mapValues { NoteRequestStore.Request(context: $0.context / 10_000 * 10_000, english: $0.english) }
        guard rounded != noteRequests else { return }
        let first = noteRequests == nil
        noteRequests = rounded
        // Ilova ishga tushganda fayl bo'lmasa — hech narsa qilinmaydi (keraksiz yozish va hook o'rnatish yo'q)
        if first && rounded.isEmpty && !FileManager.default.fileExists(atPath: NoteRequestStore.defaultURL.path) { return }
        NoteRequestStore.save(rounded)
        if !rounded.isEmpty { try? PromptRedirectHook.install() }
    }
    private var redirectArmed: Set<String> = []
    /// Avtomatik qisqartirishi to'xtatiladigan sessiyalar (faylga faqat to'plam o'zgarganda yoziladi)
    private var compactGuarded: Set<String>?

    private func updateCompactGuard(_ wanted: Set<String>) {
        guard wanted != compactGuarded else { return }
        let first = compactGuarded == nil
        compactGuarded = wanted
        if first && wanted.isEmpty && !FileManager.default.fileExists(atPath: CompactGuard.guardURL.path) { return }
        CompactGuard.saveGuarded(wanted)
        if !wanted.isEmpty { try? PreCompactHook.install() }
    }

    /// Eski sessiyaning keyingi xabari yangi sessiyaga ketsin: xulosa saqlanadi, hook ulanadi
    private static func armRedirect(_ sess: SessionSnap, summary: String, replace: Bool = false) {
        RedirectStore.add(session: sess.id, summary: summary, previousContext: sess.contextTokens,
                          english: SavingsAdvisor.conversationEnglish(sess), folder: SavingsAdvisor.projectFolder(for: sess),
                          replace: replace)
        try? PromptRedirectHook.install()
    }
    /// Yangi sessiya ochilgan sessiyalar — diskda (ilova qayta ishga tushsa yoki yangilansa ham qayta ochilmasin), 7 kun
    private let autoDoneKey = "autoHandoffDone"
    private lazy var autoDone: [String: Double] = {
        let all = UserDefaults.standard.dictionary(forKey: autoDoneKey) as? [String: Double] ?? [:]
        let cutoff = Date().timeIntervalSince1970 - 7 * 86400
        return all.filter { $0.value >= cutoff }
    }()
    /// Ko'chirish paytidagi kontekst — eski sessiyada davom etilsa, +30K dan keyin qayta ko'chirish uchun
    private let autoDoneContextKey = "autoHandoffDoneContext"
    private lazy var autoDoneContext: [String: Int] = UserDefaults.standard.dictionary(forKey: autoDoneContextKey) as? [String: Int] ?? [:]

    /// Kontekst chegaradan oshgan sessiya javobini tugatdi — xulosa saqlanadi va yangi sessiya ochiladi.
    /// Eski sessiyada davom etilsa — kontekst yana +30K o'sganda qayta
    private func evaluateAutoHandoff(_ s: Snapshot) {
        defer { autoPrevious = Dictionary(s.sessions.map { ($0.id, $0.state) }, uniquingKeysWith: { a, _ in a }) }
        let d = UserDefaults.standard
        guard s.initialScanDone, d.bool(forKey: Pref.autoHandoff) else {
            updateNoteRequests([:])
            updateCompactGuard([])
            return
        }
        let k = d.double(forKey: Pref.autoHandoffK)
        // Bepul modeldagi sessiyalar (FreeLLMAPI) ko'chirilmaydi: Claude limiti tugagani uchun ochilgan, qisqartirishni Claude Code o'zi qiladi
        let claude = s.sessions.filter(\.isClaude)
        // Chegaraga yaqin, hali ko'chirilmagan, so'nggi sutkada ishlagan sessiyalar — Claude javob oxirida eslatma yozsin
        let askFrom = HandoffNote.askFrom(thresholdK: k)
        let recent = Date().addingTimeInterval(-86400)
        updateNoteRequests(Dictionary(claude.filter {
            $0.contextTokens >= askFrom && ($0.lastActivity ?? .distantPast) >= recent
                && !AutoHandoffRule.alreadyDone(doneAt: autoDoneContext[$0.id], known: autoDone[$0.id] != nil,
                                                context: $0.contextTokens, thresholdK: k)
        }.map { ($0.id, NoteRequestStore.Request(context: $0.contextTokens, english: SavingsAdvisor.conversationEnglish($0))) },
        uniquingKeysWith: { a, _ in a }))
        // Hali ko'chirilmagan katta sessiyalar: Claude Code ularni avtomatik qisqartirmoqchi bo'lsa — bir marta to'xtatiladi,
        // o'rniga javob oxirida yangi sessiya ochiladi (aks holda qisqartirish ko'chirishdan oldin kelib, uni yo'qqa chiqarardi)
        updateCompactGuard(Set(claude.filter {
            $0.contextTokens >= AutoHandoffRule.compactGuardFloor && ($0.lastActivity ?? .distantPast) >= recent
                && !AutoHandoffRule.alreadyDone(doneAt: autoDoneContext[$0.id], known: autoDone[$0.id] != nil,
                                                context: $0.contextTokens, thresholdK: k)
        }.map(\.id)))
        let compactBlocked = compactGuarded?.isEmpty == false ? CompactGuard.loadBlocked() : [:]
        // Ko'chirilgan sessiyalar (shu jumladan ilova qayta ishga tushishidan oldingilari) — keyingi xabari yangi sessiyaga yo'naltiriladi
        if d.bool(forKey: Pref.autoHandoffRedirect) {
            let cutoff = Date().timeIntervalSince1970 - RedirectStore.lifetime
            let pending = s.sessions.contains { (autoDone[$0.id] ?? 0) >= cutoff && !redirectArmed.contains($0.id) }
            let stored = pending ? RedirectStore.load() : [:]
            for sess in s.sessions where (autoDone[sess.id] ?? 0) >= cutoff && !redirectArmed.contains(sess.id) {
                redirectArmed.insert(sess.id)
                // Oldingi ishga tushishda saqlangan — xulosa qayta yasalmaydi (loyiha papkasida git chaqirilmaydi)
                if stored[sess.id] != nil { continue }
                AutoHandoff.summary(for: sess) { Self.armRedirect(sess, summary: $0) }
            }
        }
        for sess in claude where AutoHandoffRule.shouldTrigger(
            previous: autoPrevious[sess.id], state: sess.state, context: sess.contextTokens, thresholdK: k,
            waitingPermission: s.permissionWaits[sess.id] != nil,
            alreadyDone: AutoHandoffRule.alreadyDone(doneAt: autoDoneContext[sess.id], known: autoDone[sess.id] != nil,
                                                     context: sess.contextTokens, thresholdK: k),
            compactBlocked: compactBlocked[sess.id].map { $0.timeIntervalSince1970 > (autoDone[sess.id] ?? 0) } ?? false,
            turnEnded: sess.turnEnded) {
            let byCompact = Double(sess.contextTokens) < k * 1000
            autoDone[sess.id] = Date().timeIntervalSince1970
            autoDoneContext[sess.id] = sess.contextTokens
            d.set(autoDone, forKey: autoDoneKey)
            d.set(autoDoneContext.filter { autoDone[$0.key] != nil }, forKey: autoDoneContextKey)
            let redirect = d.bool(forKey: Pref.autoHandoffRedirect)
            if redirect { redirectArmed.insert(sess.id) }
            AutoHandoff.summary(for: sess) { summary in
                if redirect { Self.armRedirect(sess, summary: summary, replace: true) }
                let ok = AutoHandoff.start(sess, summary: summary)
                let start = SavingsAdvisor.startContext(for: sess) ?? SavingsAdvisor.baseline
                let why = byCompact ? tr("Claude Code suhbatni avtomatik qisqartirmoqchi edi — o'rniga ish yangi sessiyaga ko'chirildi. ",
                                         "Claude Code was about to auto-compact the conversation — the work moved to a new session instead. ") : ""
                self.post(tr("\(sess.project): yangi sessiya ochildi", "\(sess.project): new session opened"),
                          why + (ok
                                // Claude ilovasi tashqi havoladagi xabarni xavfsizlik uchun o'zi yubormaydi — Enter foydalanuvchida
                                ? tr("Kontekst \(Fmt.tokens(sess.contextTokens)) edi. Yangi sessiyada xulosa yozib qo'yildi — Enter bosing, Claude ishni davom ettiradi "
                                     + "(kontekst ~\(Fmt.tokens(start)) dan boshlanadi). Eski sessiyada davom etmang.",
                                     "Context was \(Fmt.tokens(sess.contextTokens)). The summary is filled in the new session — press Enter and Claude continues the work "
                                     + "(context starts at ~\(Fmt.tokens(start))). Don't keep working in the old session.")
                             : tr("Yangi sessiyani ochib bo'lmadi — sessiyani oching va «Yangi sessiyada davom ettirish»ni bosing.",
                                  "Couldn't open a new session — open the session and click «Continue in a new session».")),
                          session: sess.id)
            }
        }
    }

    // MARK: - Isrof

    private var bigContextWarned: Set<String> = []
    private var bigContextPrimed = false
    private var lastWasteCheck = Date.distantPast

    /// Ishlayotgan sessiya konteksti 200K dan oshganda — bir marta (100K dan tushsa — /compact yoki yangi sessiya — qayta qurollanadi).
    /// Ilova ochilgandagi mavjud katta sessiyalar uchun emas
    private func evaluateBigContext(_ s: Snapshot) {
        defer { bigContextPrimed = true }
        for sess in s.sessions {
            if sess.contextTokens < 100_000 { bigContextWarned.remove(sess.id); continue }
            guard sess.contextTokens >= 200_000, !bigContextWarned.contains(sess.id) else { continue }
            bigContextWarned.insert(sess.id)
            guard bigContextPrimed, sess.state != .idle, UserDefaults.standard.bool(forKey: Pref.notifyWaste) else { continue }
            let extra = sess.contextTokens - (SavingsAdvisor.startContext(for: sess) ?? SavingsAdvisor.baseline)
            post(tr("\(sess.project): kontekst \(Fmt.tokens(sess.contextTokens))", "\(sess.project): context \(Fmt.tokens(sess.contextTokens))"),
                 tr("Har javobda taxminan \(Fmt.tokens(extra)) ortiqcha qayta o'qilyapti. Yangi mavzu bo'lsa — yangi sessiya, shu mavzu bo'lsa — /compact. "
                    + "Bosing — sessiya ochiladi, «Yangi sessiyada davom ettirish» u yerda.",
                    "About \(Fmt.tokens(extra)) extra is re-read on every reply. New topic — a new session; same topic — /compact. "
                    + "Click to open the session — «Continue in a new session» is there."),
                 session: sess.id)
        }
    }

    /// Loyiha bugun sarfining 40%+ i isrof bo'lsa (narx bo'yicha, kamida 2M vaznli) — kuniga bir marta, 5 daqiqada bir tekshiriladi
    private func evaluateProjectWaste(_ s: Snapshot) {
        let now = s.updatedAt
        guard s.initialScanDone, now.timeIntervalSince(lastWasteCheck) >= 300 else { return }
        lastWasteCheck = now
        let d = UserDefaults.standard
        guard d.bool(forKey: Pref.notifyWaste) else { return }
        let day = HistoryStore.key(now)
        var alerted = d.dictionary(forKey: "wasteAlerted") as? [String: String] ?? [:]
        for r in ProjectSavings.reports(s, period: .today, now: now)
        where r.wasteShare(.weighted) >= 0.4 && r.waste(.weighted) >= 2_000_000 && alerted[r.project] != day {
            alerted[r.project] = day
            let pct = Int((r.wasteShare(.weighted) * 100).rounded())
            post(tr("\(r.project): bugun sarfning taxminan \(pct)% isrof", "\(r.project): an estimated \(pct)% of today's usage is waste"),
                 (r.issues.first.map { tr("Asosiy sabab: ", "Main cause: ") + $0.title.lowercased() + ". " } ?? "")
                    + tr("Bosing — Tejash sahifasida sabablar va «Claude'ga topshirish».",
                         "Click for the causes and «Hand to Claude» on the Savings page."),
                 section: .savings)
        }
        d.set(alerted, forKey: "wasteAlerted")
    }

    private var savingsAnnounced: [String: Int] = [:]
    private var savingsPrimed = false

    /// Kontekst katta (300K+) bo'lganda yangi mavzu (10 daqiqadan uzoq tanaffusdan keyingi so'rov) boshlansa —
    /// bir marta: yangi sessiya oching, davom etish xulosasi bilan. Model va sifat o'zgarmaydi
    private func evaluateSavings(_ s: Snapshot) {
        defer { savingsPrimed = true }
        for sess in s.sessions where sess.state != .idle && sess.contextTokens >= 300_000 {
            guard let t = sess.turns.last, sess.turns.count >= 2, savingsAnnounced[sess.id] != t.id else { continue }
            let prev = sess.turns[sess.turns.count - 2]
            guard !t.isContinuation, t.start.timeIntervalSince(prev.end) > 600 else { continue }
            savingsAnnounced[sess.id] = t.id
            guard savingsPrimed, UserDefaults.standard.bool(forKey: Pref.notifySavings) else { continue }
            let save = sess.contextTokens - SavingsAdvisor.baseline
            post(tr("\(sess.project): yangi mavzu — yangi sessiya arzonroq", "\(sess.project): new topic — a new session is cheaper"),
                 tr("Kontekst \(Fmt.tokens(Double(sess.contextTokens))). Yangi sessiyada har javobda taxminan \(Fmt.tokens(Double(save))) token tejaladi. "
                 + "Bosing — sessiya ochiladi, tejash belgisidagi «Yangi sessiyada davom ettirish» tugmasini bosing.",
                    "Context \(Fmt.tokens(Double(sess.contextTokens))). A new session saves an estimated \(Fmt.tokens(Double(save))) tokens on every reply. "
                 + "Click to open the session, then press «Continue in a new session» under the savings badge."),
                 session: sess.id)
        }
    }

    // MARK: - Ruxsat va kontekst

    private var announcedWaits: [String: Date] = [:]
    private var waitsPrimed = false
    private var contextWarned: Set<String> = []

    /// Claude ruxsat so'rab to'xtaganda — har bir so'rov uchun bir marta (ilova ochilgandagi eski holatlar uchun emas)
    private func evaluatePermission(_ s: Snapshot) {
        defer { waitsPrimed = true }
        for (sid, n) in s.permissionWaits where announcedWaits[sid] != n.date {
            announcedWaits[sid] = n.date
            guard waitsPrimed, UserDefaults.standard.bool(forKey: Pref.notifyPermission) else { continue }
            let project = s.sessions.first { $0.id == sid }?.project ?? "Claude"
            post(tr("\(project): Claude ruxsatingizni kutyapti", "\(project): Claude is waiting for your permission"),
                 (n.message.isEmpty ? tr("Asbobdan foydalanish uchun ruxsat kerak.", "Permission is needed to use a tool.") : Self.uz(n.message))
                    + tr("\nClaude Code oynasida javob bering.", "\nRespond in the Claude Code window."),
                 session: sid)
        }
    }

    /// Hook xabarini o'zbekchaga: «Claude needs your permission to use Bash» → «Bash uchun ruxsat so'rayapti»
    static func uz(_ message: String) -> String {
        let p = "Claude needs your permission to use "
        if message.hasPrefix(p) { return tr("\(message.dropFirst(p.count)) uchun ruxsat so'rayapti.", "Asking for permission to use \(message.dropFirst(p.count)).") }
        return message
    }

    /// Kontekst 85% dan oshganda — sessiyada bir marta; 50% dan tushsa (xulosa qilingan) qayta qurollanadi
    private func evaluateContext(_ s: Snapshot) {
        for sess in s.sessions {
            let f = sess.contextFraction
            if f < 0.5 { contextWarned.remove(sess.id); continue }
            guard f >= 0.85, sess.state != .idle, !contextWarned.contains(sess.id) else { continue }
            contextWarned.insert(sess.id)
            guard UserDefaults.standard.bool(forKey: Pref.notifyContext) else { continue }
            post(tr("\(sess.project): kontekst \(Int((f * 100).rounded()))% to'ldi", "\(sess.project): context \(Int((f * 100).rounded()))% full"),
                 "\(Fmt.tokens(Double(sess.contextTokens))) / \(Fmt.tokens(Double(sess.contextWindow))). "
                    + tr("Tez orada suhbat avtomatik xulosa qilinadi — muhim narsalarni hozir ayting yoki ishni bo'lib bering.",
                         "The conversation will soon be auto-summarized — say anything important now or split up the work."),
                 session: sess.id)
        }
    }

    // MARK: - API xatosi (StopFailure)

    private var failureNotified: [String: Date] = [:]

    /// Javob API xatosi bilan uzilgan sessiya — bir xato uchun bir xabar. Limit tugagan bo'lsa, tiklanish vaqti
    /// hisob ma'lumotidan (hook uni bermaydi)
    private func evaluateFailures(_ s: Snapshot) {
        guard UserDefaults.standard.bool(forKey: Pref.notifyErrors) else { return }
        for (id, n) in s.failures where failureNotified[id] != n.date {
            failureNotified[id] = n.date
            // Ilova qayta ishga tushganda eski xato qayta aytilmaydi; limit 100% bo'lsa — «limit tugadi» xabari allaqachon chiqqan
            // (u o'chirilgan bo'lsa — shu xabar aytadi, bepul model taklifi bilan)
            let exhausted = UserDefaults.standard.bool(forKey: Pref.notifyRealLimit)
                && [s.limits?.fiveHour, s.limits?.sevenDay].contains { ($0?.usedPercentage ?? 0) >= 99.5 }
            guard Date().timeIntervalSince(n.date) < 600, !(n.error == "rate_limit" && exhausted),
                  let sess = s.sessions.first(where: { $0.id == id }) else { continue }
            var (title, body) = Self.failureText(n, limits: s.limits)
            let free = n.error == "rate_limit" && sess.isClaude && offerFree
            if free { body += Self.freeHint }
            post("\(sess.project): \(title)", body, session: id, id: "failure-" + id,
                 category: free ? Self.freeCategory : nil)
        }
    }

    /// Limit tugadi xabari oxiriga — bepul model tugmasi haqida
    private static var freeHint: String {
        tr(" «Bepul modelda davom etish» (bildirishnoma tugmasi) — ish terminalda bepul modelda davom etadi.",
           " «Continue on a free model» (notification button) — the work continues in Terminal on a free model.")
    }

    static func failureText(_ n: HookNotice, limits: RateLimits?) -> (String, String) {
        switch n.error {
        case "rate_limit":
            // To'lib qolgan oyna: eng ko'p ishlatilgani; ma'lumot bo'lmasa — vaqtsiz
            let w = [limits?.fiveHour, limits?.sevenDay].compactMap { $0 }.max { $0.usedPercentage < $1.usedPercentage }
            guard let w, w.resetsAt > Date() else {
                return (tr("Claude limiti tugadi", "Claude limit reached"),
                        tr("Javob limit sababli to'xtadi. Tiklanish vaqtini Claude'dagi /usage ko'rsatadi.",
                           "The reply stopped on the rate limit. /usage in Claude shows when it resets."))
            }
            return (tr("Claude limiti tugadi", "Claude limit reached"),
                    tr("Javob to'xtadi. \(LimitText.dayTime(w.resetsAt)) da tiklanadi (\(duration(w.resetsAt.timeIntervalSinceNow)) qoldi) — keyin shu sessiyada davom eting.",
                       "The reply stopped. Resets \(LimitText.dayTime(w.resetsAt)) (in \(duration(w.resetsAt.timeIntervalSinceNow))) — continue in this session then."))
        case "overloaded", "server_error":
            return (tr("Anthropic serverlari band", "Anthropic servers are busy"),
                    tr("Javob uzildi. Bir necha daqiqadan keyin xabarni qayta yuboring.", "The reply was cut off. Send the message again in a few minutes."))
        case "authentication_failed", "oauth_org_not_allowed":
            return (tr("Hisobga qayta kirish kerak", "Sign in again"),
                    tr("Claude hisobingizni tanimadi. Claude Code'da /login qiling.", "Claude didn't recognize your account. Run /login in Claude Code."))
        case "billing_error", "account_on_hold":
            return (tr("Hisob yoki to'lov muammosi", "Account or billing problem"),
                    tr("Javob to'xtadi. claude.ai'dagi hisob sozlamalarini tekshiring.", "The reply stopped. Check your account settings on claude.ai."))
        case "max_output_tokens":
            return (tr("Javob juda uzun bo'lib uzildi", "Reply cut off for length"),
                    tr("«Davom et» deb yozing yoki vazifani bo'laklang.", "Write \"continue\" or split the task."))
        default:
            return (tr("Javob xato bilan to'xtadi", "Reply stopped with an error"), n.message)
        }
    }

    // MARK: - Haqiqiy limit

    /// Har bir oyna (5 soat / hafta) uchun 80% va 95% da bir martadan — oyna tiklanguncha.
    /// 100% da — «tugadi, qachon tiklanadi» va tiklanish paytiga oldindan rejalashtirilgan «tiklandi»
    private func evaluateRealLimits(_ s: Snapshot) {
        let d = UserDefaults.standard
        guard d.bool(forKey: Pref.notifyRealLimit), let l = s.limits else { return }
        var fired = d.dictionary(forKey: "realLimitFired") as? [String: Double] ?? [:]
        for (name, label, w) in [("5 soatlik", tr("5 soatlik", "5-hour"), l.fiveHour), ("Haftalik", tr("Haftalik", "Weekly"), l.sevenDay)] {
            guard let w else { continue }
            if w.usedPercentage >= 99.5 {
                let key = "\(name)-100"
                guard fired[key] != w.resetsAt.timeIntervalSince1970 else { continue }
                fired[key] = w.resetsAt.timeIntervalSince1970
                // 95% xabari endi kerak emas — tugagani aytiladi
                fired["\(name)-80"] = w.resetsAt.timeIntervalSince1970
                fired["\(name)-95"] = w.resetsAt.timeIntervalSince1970
                // Haftalik limit ham tugagan va keyinroq tiklanadi: 5 soatlik tiklanishi Claude'ni qaytarmaydi —
                // bu xabarlar o'rniga haftalik «tugadi / tiklandi» aytiladi (oldin rejalashtirilgan 5 soatlik «tiklandi» bekor)
                if let week = l.sevenDay, week.usedPercentage >= 99.5 {
                    if name == "5 soatlik", week.resetsAt > w.resetsAt { continue }
                    if name == "Haftalik", let five = l.fiveHour, five.resetsAt < w.resetsAt {
                        center?.removePendingNotificationRequests(withIdentifiers: ["limit-reset-5 soatlik"])
                    }
                }
                let reset = LimitText.dayTime(w.resetsAt)
                let free = offerFree
                post(tr("\(label) Claude limiti tugadi", "\(label) Claude limit reached"),
                     tr("\(reset.prefix(1).uppercased() + reset.dropFirst()) da tiklanadi (\(Self.duration(w.resetsAt.timeIntervalSinceNow)) qoldi). Shu paytgacha Claude javob bermaydi — tiklanganda xabar beraman.",
                        "Resets \(reset) (in \(Self.duration(w.resetsAt.timeIntervalSinceNow))). Claude won't answer until then — I'll let you know when it resets.")
                        + (free ? Self.freeHint : ""),
                     id: "limit-out-\(name)", category: free ? Self.freeCategory : nil,
                     extra: ["resetsAt": w.resetsAt.timeIntervalSince1970])
                post(tr("\(label) Claude limiti tiklandi", "\(label) Claude limit reset"),
                     free ? tr("Claude'da yana ishlashingiz mumkin. Bepul modelda ishlagan bo'lsangiz — «Claude'da davom etish» o'sha ishni xulosa bilan Claude'ga qaytaradi.",
                               "You can use Claude again. If you worked on a free model — «Continue in Claude» moves that work back to Claude with a summary.")
                         : tr("Claude'da yana ishlashingiz mumkin.", "You can use Claude again."),
                     id: "limit-reset-\(name)", after: w.resetsAt.timeIntervalSinceNow, category: free ? Self.backCategory : nil,
                     extra: ["limitOut": Date().timeIntervalSince1970])
                continue
            }
            for t in [80.0, 95.0] where w.usedPercentage >= t {
                let key = "\(name)-\(Int(t))"
                guard fired[key] != w.resetsAt.timeIntervalSince1970 else { continue }
                fired[key] = w.resetsAt.timeIntervalSince1970
                let reset = Fmt.hourMinute.string(from: w.resetsAt)
                var body = tr("\(Int(w.usedPercentage.rounded()))% ishlatildi · \(reset) da tiklanadi (\(Self.duration(w.resetsAt.timeIntervalSinceNow))).",
                               "\(Int(w.usedPercentage.rounded()))% used · resets at \(reset) (\(Self.duration(w.resetsAt.timeIntervalSinceNow))).")
                if name == "5 soatlik", case .runsOut(let at) = s.fiveHourForecast {
                    body += tr(" Shu tezlikda ~\(Fmt.hourMinute.string(from: at)) da tugaydi.", " At this pace it runs out at ~\(Fmt.hourMinute.string(from: at)).")
                }
                post(tr("\(label) Claude limiti: \(Int(t))%", "\(label) Claude limit: \(Int(t))%"), body)
            }
        }
        d.set(fired, forKey: "realLimitFired")
    }

    // MARK: - Sessiya hodisalari

    private func evaluateActivity(_ s: Snapshot) {
        let d = UserDefaults.standard
        let cfg = ActivityMonitor.Config(finishMin: d.double(forKey: Pref.notifyFinishedMin),
                                         stuckAfter: d.double(forKey: Pref.notifyStuckSec),
                                         errorStreak: 3)
        // Monitor har doim yuradi (holatni eslab qolishi uchun), xabar esa faqat yoqilgan turlar uchun
        for e in monitor.process(s, config: cfg) {
            switch e.kind {
            case .finished(let duration, let tokens, let steps):
                guard d.bool(forKey: Pref.notifyFinished) else { continue }
                post(tr("\(e.project): Claude tugatdi", "\(e.project): Claude finished"),
                     tr("\(e.title)\n\(Self.duration(duration)) · \(steps) qadam · \(Fmt.tokens(tokens)) token. Javobingizni kutyapti.",
                        "\(e.title)\n\(Self.duration(duration)) · \(steps) \(steps == 1 ? "step" : "steps") · \(Fmt.tokens(tokens)) tokens. Waiting for your reply."),
                     session: e.sessionId)
            case .helperFinished(let duration, let tokens, let steps):
                guard d.bool(forKey: Pref.notifyFinished) else { continue }
                post(tr("\(e.project): yordamchi agent tugatdi", "\(e.project): subagent finished"),
                     tr("\(e.agentTitle)\n\(Self.duration(duration)) · \(steps) qadam · \(Fmt.tokens(tokens)) token. Natija asosiy agentga qaytdi.",
                        "\(e.agentTitle)\n\(Self.duration(duration)) · \(steps) \(steps == 1 ? "step" : "steps") · \(Fmt.tokens(tokens)) tokens. The result went back to the main agent."),
                     session: e.sessionId)
            case .stuck(let step, let duration):
                // Ruxsat kutilayotgani aniq bo'lsa — u haqda alohida xabar ketgan
                guard d.bool(forKey: Pref.notifyStuck), s.permissionWaits[e.sessionId] == nil else { continue }
                post(tr("\(e.project): qadam \(Self.duration(duration)) dan beri tugamadi", "\(e.project): step hasn't finished for \(Self.duration(duration))"),
                     "\(e.agentTitle) · \(step)\n" + tr("Ruxsat so'rayotgan yoki osilib qolgan bo'lishi mumkin.", "It may be asking for permission or stuck."),
                     session: e.sessionId)
            case .errorStreak(let count, let step):
                guard d.bool(forKey: Pref.notifyErrors) else { continue }
                post(tr("\(e.project): ketma-ket \(count) ta xato", "\(e.project): \(count) errors in a row"),
                     tr("\(e.agentTitle) bir joyda aylanib qolgan bo'lishi mumkin.\nOxirgisi: \(step)",
                        "\(e.agentTitle) may be going in circles.\nLast one: \(step)"),
                     session: e.sessionId)
            }
        }
    }

    static func duration(_ s: TimeInterval) -> String {
        let m = Int(s) / 60
        if m >= 60 { return tr("\(m / 60) soat \(m % 60) daq", "\(m / 60) h \(m % 60) min") }
        if m > 0 { return tr("\(m) daq", "\(m) min") }
        return "\(Int(s)) s"
    }

    // MARK: - Limit

    /// «Bugun» — har kuni qayta qurollanadi; «5 soat» — sarf 50% dan pastga tushganda.
    private func evaluateBudget(_ s: Snapshot) {
        let d = UserDefaults.standard
        guard d.bool(forKey: Pref.budgetNotify), let b = BudgetStatus.current(s) else { return }

        var epoch = d.integer(forKey: epochKey)
        if b.period == .fiveHours && b.fraction < 0.5 {
            // Oyna bo'shadi — keyingi to'lishda yana ogohlantiramiz
            if (d.dictionary(forKey: firedKey) as? [String: String])?.values.contains(where: { $0.hasPrefix("5h-\(epoch)") }) == true {
                epoch += 1
                d.set(epoch, forKey: epochKey)
            }
        }
        let periodKey = b.period == .day ? "day-" + HistoryStore.key(Date()) : "5h-\(epoch)"

        var fired = d.dictionary(forKey: firedKey) as? [String: String] ?? [:]
        for t in thresholds where b.fraction >= t {
            let k = String(t)
            guard fired[k] != periodKey else { continue }
            fired[k] = periodKey
            let period = b.period == .day ? tr("Bugungi", "Today's") : tr("5 soatlik", "5-hour")
            if t >= 1 {
                post(tr("Token limiti tugadi", "Token limit reached"),
                     tr("\(period) limit: \(Fmt.tokens(b.used)) / \(Fmt.tokens(b.limit)) token (narx bo'yicha).", "\(period) limit: \(Fmt.tokens(b.used)) / \(Fmt.tokens(b.limit)) tokens (by price)."))
            } else {
                post(tr("Token limitining \(Int(t * 100))% ishlatildi", "\(Int(t * 100))% of token limit used"),
                     tr("\(period) sarf: \(Fmt.tokens(b.used)) / \(Fmt.tokens(b.limit)) token (narx bo'yicha).", "\(period) usage: \(Fmt.tokens(b.used)) / \(Fmt.tokens(b.limit)) tokens (by price)."))
            }
        }
        d.set(fired, forKey: firedKey)
    }

    // MARK: - Yuborish va bosish

    /// `id` va `after` berilsa — shu vaqtdan keyin chiqadi va shu id bilan bekor qilinadi (yoki almashtiriladi)
    /// `category` — tugmalar to'plami (bepul model / Claude'ga qaytish), `extra` — tugma uchun qo'shimcha ma'lumot
    private func post(_ title: String, _ body: String, session: String? = nil, section: Section? = nil,
                      id: String? = nil, after: TimeInterval? = nil, category: String? = nil, extra: [String: Any] = [:]) {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        var info = extra
        if let session {
            info["session"] = session
            content.threadIdentifier = session
        } else if let section {
            info["section"] = section.rawValue
        }
        content.userInfo = info
        if let category { content.categoryIdentifier = category }
        let trigger = after.map { UNTimeIntervalNotificationTrigger(timeInterval: max(1, $0), repeats: false) }
        center.add(UNNotificationRequest(identifier: id ?? UUID().uuidString, content: content, trigger: trigger))
    }

    /// Ilova oynasi ochiq bo'lsa ham banner ko'rinsin
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler done: @escaping (UNNotificationPresentationOptions) -> Void) {
        done([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler done: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        let session = info["session"] as? String
        DispatchQueue.main.async {
            if response.actionIdentifier == Self.freeAction {
                self.startFree(session: session, resetsAt: (info["resetsAt"] as? Double).map(Date.init(timeIntervalSince1970:)))
            } else if response.actionIdentifier == Self.backAction {
                self.backToClaude(since: (info["limitOut"] as? Double).map(Date.init(timeIntervalSince1970:)))
            } else if let session {
                UserDefaults.standard.set(session, forKey: GraphScreen.selectedSessionKey)
                WindowManager.shared.show(.graph)
            } else if let raw = response.notification.request.content.userInfo["section"] as? String, let section = Section(rawValue: raw) {
                WindowManager.shared.show(section)
            } else {
                WindowManager.shared.show(.overview)
            }
            done()
        }
    }
}
