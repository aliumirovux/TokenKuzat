import SwiftUI
import AppKit
import TokenKuzatCore

/// «Tejash» sahifasi: loyihalar bo'yicha sarf, qayerda isrof bor va uni bir bosishda Claude'ga tuzattirish.
/// Model va sifat o'zgarmaydi — faqat behuda qayta o'qilayotgan kontekst va og'ir sozlamalar kamaytiriladi.
struct ProjectSavingsView: View {
    @EnvironmentObject var store: Store
    @AppStorage(Pref.countMode) private var mode = CountMode.weighted
    @AppStorage("savingsPeriod") private var period = SavingsPeriod.week
    @State private var expanded: Set<String> = []

    var body: some View {
        let reports = ProjectSavings.reports(store.snap, period: period, now: store.snap.updatedAt, mode: mode)
        let total = reports.reduce(0.0) { $0 + $1.tokens.value(mode) }
        let waste = reports.reduce(0.0) { $0 + $1.waste(mode) }
        let worst = reports.max { $0.waste(mode) < $1.waste(mode) }

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    PillSegments(selection: $period, items: SavingsPeriod.allCases.map { .init(id: $0, title: $0.title) })
                    Spacer()
                    Text(tr("Tejash uchun modelni yoki javob sifatini pasaytirish shart emas", "Saving doesn't mean a weaker model or worse answers")).font(.caption).foregroundStyle(.secondary)
                }

                if reports.isEmpty {
                    EmptyStateView(symbol: "leaf",
                                   title: tr("Bu davrda sarf yo'q", "No usage in this period"),
                                   text: tr("Claude Code yoki Cowork'da ish boshlansa, loyihalar shu yerda sarf bo'yicha tartiblanadi.",
                                            "Once you work in Claude Code or Cowork, projects are ranked here by usage."))
                        .frame(maxWidth: .infinity).padding(.top, 40)
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                        MetricTile(title: tr("Jami sarf", "Total usage"), value: Fmt.tokens(total), unit: tr("token", "tokens"),
                                   footnote: tr("\(reports.count) ta loyiha", reports.count == 1 ? "1 project" : "\(reports.count) projects"),
                                   symbol: "sum", tint: Brand.accent)
                        MetricTile(title: tr("Taxminiy isrof", "Estimated waste"), value: Fmt.tokens(waste), unit: tr("token", "tokens"),
                                   footnote: tr("sarfning \(Fmt.percent(waste, of: total)) — tejasa bo'ladi",
                                                "\(Fmt.percent(waste, of: total)) of usage — can be saved"),
                                   symbol: "leaf.fill", tint: Brand.ok)
                        MetricTile(title: tr("Eng ko'p isrof", "Most waste"), value: worst?.project ?? "—",
                                   footnote: worst.map { r in
                                       r.issues.first.map { $0.title } ?? tr("isrof topilmadi", "no waste found")
                                   } ?? "—",
                                   symbol: "flame.fill", tint: Brand.warn)
                    }

                    if let week = store.savingsHistory.cacheWeek(now: store.snap.updatedAt) {
                        CacheWeekCard(week: week, previous: store.savingsHistory.cacheWeek(weeksBack: 1, now: store.snap.updatedAt), mode: mode)
                    }

                    let handoffs = HandoffSavings.summary(HandoffSavings.pairs(store.snap.sessions), since: period.start(now: store.snap.updatedAt))
                    if handoffs.handoffs > 0 { HandoffSavingsCard(summary: handoffs, period: period, mode: mode) }

                    let roles = AgentRoleUsage.summary(store.snap.sessions, since: period.start(now: store.snap.updatedAt))
                    if !roles.rows.isEmpty { AgentRolesCard(summary: roles, period: period, mode: mode) }

                    let free = FreeModelLog.summary(FreeModelLog.load(), since: period.start(now: store.snap.updatedAt))
                    if free.calls > 0 { FreeModelCard(summary: free, period: period) }

                    VStack(alignment: .leading, spacing: 4) {
                        SectionHeader(title: tr("Loyihalar", "Projects"),
                                      subtitle: tr("sarf bo'yicha · bosing — sabablar va tuzatish", "by usage · click for causes and fixes"),
                                      trailing: AnyView(barLegend))
                            .padding(.bottom, 6)
                        ForEach(reports) { r in
                            ProjectSavingsRow(report: r, period: period, mode: mode,
                                              share: total > 0 ? r.tokens.value(mode) / total : 0,
                                              session: r.latestSession.flatMap { id in store.snap.sessions.first { $0.id == id } },
                                              history: store.savingsHistory, now: store.snap.updatedAt,
                                              onFixed: { store.markFixed(r.project) },
                                              expanded: expanded.contains(r.id)) {
                                // Yumshoq prujina: balandlik ravon o'sadi, mazmun biroz kechikib paydo bo'ladi
                                withAnimation(.spring(response: 0.42, dampingFraction: 0.9)) {
                                    if expanded.contains(r.id) { expanded.remove(r.id) } else { expanded.insert(r.id) }
                                }
                            }
                            if r.id != reports.last?.id { Divider().opacity(0.5) }
                        }
                    }
                    .card()

                    OptimizeCommandCard()
                }
            }
            .padding(.horizontal, 24).padding(.bottom, 24)
        }
        // Eng ko'p isrofli loyiha sahifa ochilganda yoyiq turadi
        .onAppear { if expanded.isEmpty, let w = worst, w.waste > 0 { expanded = [w.id] } }
    }

    /// Chiziqdagi ikki rang nimani bildiradi
    private var barLegend: some View {
        HStack(spacing: 12) {
            ForEach([(Brand.warn, tr("isrof", "waste")), (Brand.accent.opacity(0.75), tr("foydali sarf", "useful usage"))], id: \.1) { c, t in
                HStack(spacing: 5) {
                    Capsule().fill(c).frame(width: 12, height: 6)
                    Text(t)
                }
            }
        }
        .font(.caption).foregroundStyle(.secondary)
    }
}

/// Sessiya ko'chirishning haqiqiy foydasi: yangi sessiyalar eski sessiya oxiridagiga qaraganda qancha kam o'qidi (yozuvlardan o'lchanadi)
struct HandoffSavingsCard: View {
    let summary: HandoffSavings.Summary
    let period: SavingsPeriod
    let mode: CountMode

    var body: some View {
        let saved = mode == .weighted ? summary.savedWeighted : Double(summary.savedTokens)
        HStack(spacing: 12) {
            Image(systemName: "arrow.uturn.right.circle.fill").font(.title3).foregroundStyle(Brand.ok).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(tr("Sessiya ko'chirish — haqiqiy o'lchov · \(period.title)", "Session handoff — measured · \(period.title)")).font(.subheadline.weight(.semibold))
                Text(tr("\(summary.handoffs) ta ko'chirish · har javob ~\(Fmt.tokens(Double(summary.medianBefore))) o'rniga ~\(Fmt.tokens(Double(summary.medianAfter))) o'qiydi",
                        "\(summary.handoffs) handoff\(summary.handoffs == 1 ? "" : "s") · each reply reads ~\(Fmt.tokens(Double(summary.medianAfter))) instead of ~\(Fmt.tokens(Double(summary.medianBefore)))"))
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                if summary.rereads > 0 {
                    Text(tr("\(summary.rereads) tasida Claude eski suhbatni qayta o'qidi — xulosada nimadir yetishmagan",
                            "In \(summary.rereads) Claude re-read the old conversation — the summary missed something"))
                        .font(.caption).foregroundStyle(Brand.warn)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Fmt.tokens(max(0, saved))).font(.title3.weight(.semibold)).foregroundStyle(Brand.ok).monospacedDigit()
                Text(tr("token tejaldi · \(Fmt.percent(Double(summary.savedTokens), of: Double(summary.savedTokens + summary.readTokens))) kam",
                        "tokens saved · \(Fmt.percent(Double(summary.savedTokens), of: Double(summary.savedTokens + summary.readTokens))) less"))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .card()
        .help(tr("Sessiya yozuvlaridan o'lchanadi: har ko'chirilgan sessiya o'zi davom ettirgan eski sessiya bilan solishtiriladi. Eski sessiyada qolinsa, har javob kamida eski oxirgi kontekstni o'qirdi — hisob ehtiyotkor. Narx rejimida yangi sessiya kontekstini bir marta keshga yozish ayirilgan.",
                 "Measured from session transcripts: each handed-off session is compared with the session it continued. Staying in the old session, every reply would read at least its last context — a conservative estimate. In cost mode, writing the new session's context to cache once is subtracted."))
    }
}

/// Sarf agent turlari bo'yicha: rahbar (bosh agent) va yordamchilar — og'ir ish arzonroq yordamchilarga tushyaptimi
struct AgentRolesCard: View {
    let summary: AgentRoleUsage.Summary
    let period: SavingsPeriod
    let mode: CountMode

    var body: some View {
        let total = summary.rows.reduce(0.0) { $0 + $1.tokens.value(mode) }
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "person.3.fill").font(.title3).foregroundStyle(Brand.accent).frame(width: 28)
                Text(tr("Agent turlari bo'yicha sarf · \(period.title)", "Usage by agent role · \(period.title)")).font(.subheadline.weight(.semibold))
                Spacer()
            }
            ForEach(summary.rows, id: \.role) { r in
                HStack(spacing: 10) {
                    Text(r.role.title).frame(width: 130, alignment: .leading)
                    GeometryReader { g in
                        Capsule().fill(r.role == .lead ? Brand.accent.opacity(0.75) : Brand.ok)
                            .frame(width: max(3, g.size.width * (total > 0 ? r.tokens.value(mode) / total : 0)))
                    }
                    .frame(height: 6)
                    Text(Fmt.tokens(r.tokens.value(mode))).monospacedDigit().frame(width: 70, alignment: .trailing)
                    Text(Fmt.percent(r.tokens.value(mode), of: total)).monospacedDigit().foregroundStyle(.secondary).frame(width: 44, alignment: .trailing)
                    Text(r.role == .lead ? tr("\(r.agents) sessiya", "\(r.agents) sessions") : tr("\(r.agents) ta", "\(r.agents)"))
                        .foregroundStyle(.secondary).frame(width: 80, alignment: .trailing)
                }
                .font(.caption)
            }
            if summary.heavyLeadSessions > 0 {
                Text(tr("\(summary.heavyLeadSessions) sessiyada rahbar \(AgentRole.heavyLeadReads)+ faylni o'zi o'qidi — izlash ishini «izlovchi»ga berish mumkin edi",
                        "In \(summary.heavyLeadSessions) session(s) the lead read \(AgentRole.heavyLeadReads)+ files itself — the search could have gone to the «izlovchi» helper"))
                    .font(.caption).foregroundStyle(Brand.warn)
            } else if !summary.helpersUsed {
                Text(tr("Yordamchi agentlar hali ishlatilmagan", "No helper agents used yet")).font(.caption).foregroundStyle(.secondary)
            }
        }
        .card()
        .help(tr("Rahbar — asosiy agent (eng kuchli model): rejalaydi va tekshiradi. Izlovchi (tez model) qidiradi, bajaruvchi (o'rta model) aniq vazifani bajaradi, tekshiruvchi kodni mustaqil ko'rib chiqadi, sinovchi (o'rta model) natijani ishga tushirib sinaydi. Turlar Token Kuzatuv plagini bilan o'rnatiladi.",
                 "Lead — the main agent (strongest model): plans and checks. Explorer (fast model) searches, builder (mid model) does a specified task, reviewer checks the code independently, tester (mid model) runs the result to see it works. The roles come with the Token Kuzatuv plugin."))
    }
}

/// Bepul modelga (MCP `ask_free_model`) berilgan ishlar: necha marta va taxminan qancha Claude tokeni tejaldi
private struct FreeModelCard: View {
    let summary: FreeModelLog.Summary
    let period: SavingsPeriod

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "gift.fill").font(.title3).foregroundStyle(Brand.ok).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(tr("Bepul modelga berilgan ishlar · \(period.title)", "Tasks handed to free models · \(period.title)")).font(.subheadline.weight(.semibold))
                Text(tr("\(summary.calls) marta · \(summary.withFiles) tasida faylni Token Kuzatuv o'zi o'qidi",
                        "\(summary.calls == 1 ? "once" : "\(summary.calls) times") · Token Kuzatuv read the file itself in \(summary.withFiles)"))
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("~\(Fmt.tokens(Double(summary.savedTokens)))").font(.title3.weight(.semibold)).foregroundStyle(Brand.ok).monospacedDigit()
                Text(tr("token tejaldi", "tokens saved")).font(.caption).foregroundStyle(.secondary)
            }
        }
        .card()
        .help(tr("Taxminiy hisob: Claude kontekstiga kirmagan fayl matni va Claude o'zi yozmagan javob. Claude bergan ishni (prompt) va javobni o'qishini hisobga olmaydi.",
                 "Estimate: file content that never entered Claude's context plus the answer Claude didn't have to write. Doesn't subtract the prompt Claude wrote or reading the answer."))
    }
}

/// Haftalik o'lchov: tanaffusdan keyin kesh sovib, qaytadan yozilgan kontekst — so'nggi 7 kun va undan oldingi 7 kun.
/// Kesh taymeri va ogohlantirish foyda berayotganini shu raqam ko'rsatadi
private struct CacheWeekCard: View {
    let week: CacheDay
    let previous: CacheDay?
    let mode: CountMode

    private func value(_ c: CacheDay) -> Double { mode == .weighted ? c.weighted : Double(c.tokens) }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath").font(.title3).foregroundStyle(Brand.warn).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(tr("Kesh sovib qayta yozildi · 7 kun", "Cache rewritten after going cold · 7 days")).font(.subheadline.weight(.semibold))
                Text(week.count == 0
                     ? tr("Bu hafta kesh sovimagan", "The cache didn't go cold this week")
                     : tr("\(Fmt.tokens(value(week))) token · \(week.count) marta", "\(Fmt.tokens(value(week))) tokens · \(week.count == 1 ? "once" : "\(week.count) times")"))
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            Spacer()
            if let p = previous {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(tr("oldingi 7 kun: \(Fmt.tokens(value(p)))", "previous 7 days: \(Fmt.tokens(value(p)))"))
                        .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    if value(p) > 0 {
                        let change = (value(week) - value(p)) / value(p)
                        Text("\(change <= 0 ? "−" : "+")\(Int((abs(change) * 100).rounded()))%")
                            .font(.caption.weight(.semibold)).monospacedDigit()
                            .foregroundStyle(change <= 0 ? Brand.ok : Brand.warn)
                    }
                }
            } else {
                Text(tr("oldingi hafta hali yozilmagan", "no previous week yet")).font(.caption).foregroundStyle(.tertiary)
            }
        }
        .card()
        .help(tr("Tanaffus kesh muddatidan (5 daqiqa yoki 1 soat) uzun bo'lsa, keyingi so'rov kontekstni qimmatroq narxda qaytadan yozadi. Raqam transkriptdan olinadi: keyingi chaqiruv eski kontekstni keshdan o'qiy olmagan va qayta yozgan.",
                 "When a break outlasts the cache lifetime (5 minutes or 1 hour), the next prompt rewrites the context at a higher price. Measured from the transcript: the next call couldn't read the old context from cache and wrote it again."))
    }
}

private struct ProjectSavingsRow: View {
    let report: ProjectReport
    let period: SavingsPeriod
    let mode: CountMode
    let share: Double
    let session: SessionSnap?
    let history: ProjectSavingsData
    let now: Date
    let onFixed: () -> Void
    let expanded: Bool
    let onToggle: () -> Void
    @State private var copied = false
    /// Topshiriq nusxalangan — «Qo'llandi» belgisini qo'yish mumkin
    @State private var handed = false

    private var wasteColor: Color {
        let s = report.wasteShare(mode)
        return s >= 0.25 ? Brand.warn : (s >= 0.1 ? Brand.accent : .secondary)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    ProjectAvatar(name: report.project, size: 30)
                        .overlay(alignment: .bottomTrailing) {
                            if report.active {
                                Circle().fill(Brand.ok).frame(width: 9, height: 9)
                                    .overlay(Circle().stroke(Brand.surface, lineWidth: 2)).offset(x: 3, y: 3)
                            }
                        }
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(report.project).font(.callout.weight(.semibold)).lineLimit(1)
                            Text(tr("\(report.sessions) sessiya · \(report.prompts) so'rov",
                                    "\(report.sessions) \(report.sessions == 1 ? "session" : "sessions") · \(report.prompts) \(report.prompts == 1 ? "prompt" : "prompts")"))
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        // Ulush chizig'i: loyiha jami sarfning qancha qismi, ichida — isrof qismi
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Brand.line.opacity(0.5))
                                Capsule().fill(Brand.accent.opacity(0.75)).frame(width: max(4, g.size.width * share))
                                Capsule().fill(Brand.warn.opacity(0.9))
                                    .frame(width: report.waste > 0 ? max(3, g.size.width * share * report.wasteShare(mode)) : 0)
                            }
                        }
                        .frame(height: 6)
                    }
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(Fmt.tokens(report.tokens.value(mode))).font(.callout.weight(.semibold)).monospacedDigit()
                        Text(report.waste > 0
                             ? tr("isrof ~\(Fmt.tokens(report.waste(mode))) · \(Fmt.percent(report.waste(mode), of: report.tokens.value(mode)))",
                                  "waste ~\(Fmt.tokens(report.waste(mode))) · \(Fmt.percent(report.waste(mode), of: report.tokens.value(mode)))")
                             : tr("isrof yo'q", "no waste"))
                            .font(.caption.weight(.medium)).monospacedDigit().foregroundStyle(report.waste > 0 ? wasteColor : .secondary)
                    }
                    .frame(width: 150, alignment: .trailing)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                details.transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(y: -6)).animation(.easeOut(duration: 0.28).delay(0.06)),
                    removal: .opacity.animation(.easeOut(duration: 0.14))))
            }
        }
        // Yopilayotganda mazmun keyingi qator ustiga chiqmasin
        .clipped()
    }

    @ViewBuilder
    private var details: some View {
        VStack(alignment: .leading, spacing: 12) {
            trend
            if report.issues.isEmpty {
                Label(tr("Bu loyihada isrof ko'rinmayapti — kontekst kichik, qadamlar takrorlanmayapti.",
                         "No waste in this project — the context is small and steps aren't repeating."),
                      systemImage: "checkmark.seal.fill")
                    .font(.callout).foregroundStyle(Brand.ok)
            }
            ForEach(report.issues) { issue in
                HStack(alignment: .top, spacing: 12) {
                    ToolTile(symbol: issue.kind.symbol, color: color(issue.level), size: 30)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(issue.title).font(.callout.weight(.semibold))
                            Spacer(minLength: 6)
                            if issue.waste > 0 {
                                Text("~\(Fmt.tokens(mode == .weighted ? issue.weighted : Double(issue.waste)))").font(.caption.weight(.semibold)).monospacedDigit()
                                    .foregroundStyle(color(issue.level))
                            }
                        }
                        Text(issue.remedy).font(.caption).fixedSize(horizontal: false, vertical: true)
                        Text(tr("\(issue.sessions) sessiyada · ", "In \(issue.sessions) \(issue.sessions == 1 ? "session" : "sessions") · ") + issue.detail)
                            .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            .help(issue.detail)
                    }
                }
            }

            HStack(spacing: 10) {
                if !report.issues.isEmpty {
                    Button(action: copyPrompt) {
                        Label(copied ? tr("Nusxalandi — Claude Code'da shu loyihada qo'ying", "Copied — paste it into Claude Code in this project")
                                     : tr("Claude'ga topshirish", "Hand to Claude"),
                              systemImage: copied ? "checkmark.circle.fill" : "wand.and.stars")
                            .font(.callout.weight(.semibold))
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .foregroundStyle(.white)
                            .background(Capsule().fill(copied ? Brand.ok : Brand.accent))
                    }
                    .buttonStyle(.plain)
                    .help(tr("Hisobot va aniq topshiriq nusxalanadi: Claude sabablarni ko'rib, CLAUDE.md va sozlamalarga o'zgarish taklif qiladi "
                             + "va har birini siz tasdiqlagandan keyingina qo'llaydi.",
                             "Copies the report and a precise task: Claude reviews the causes, proposes changes to CLAUDE.md and settings, "
                             + "and applies each only after you approve it."))
                }
                // Nusxalash — hali tuzatish emas: «avval → keyin» sanasi faqat o'zgarish qo'llangach (shu yerda yoki MCP orqali Claude)
                if handed {
                    Button { onFixed(); handed = false } label: {
                        Label(tr("Qo'llandi deb belgilash", "Mark as applied"), systemImage: "checkmark.seal")
                    }
                    .buttonStyle(.link).font(.callout)
                    .help(tr("Claude o'zgarishlarni qo'llagan bo'lsa bosing — shu kundan oldingi va keyingi isrof solishtiriladi.",
                             "Click once Claude has applied the changes — waste before and after this day is compared."))
                }
                if let cwd = report.cwd, FileManager.default.fileExists(atPath: cwd) {
                    Button { openTerminal(cwd) } label: { Label(tr("Terminalda ochish", "Open in Terminal"), systemImage: "terminal") }
                        .buttonStyle(.link).font(.callout)
                        .help(cwd)
                }
                if report.issues.contains(where: { $0.kind == .bigContext }), let session {
                    HandoffButton(session: session, prominent: false)
                }
                Spacer()
            }
        }
        .padding(.leading, 42).padding(.bottom, 10)
    }

    private func color(_ level: SavingsTip.Level) -> Color {
        switch level {
        case .high: return Brand.warn
        case .notable: return Brand.accent
        case .info: return Color(light: 0x8A8A93, dark: 0x6E6E76)
        }
    }

    /// 14 kunlik isrof ulushi (ustunlar) va tuzatishdan keyingi natija — «avval → keyin»
    @ViewBuilder
    private var trend: some View {
        let days = history.series(report.project, count: 14, now: now)
        let ba = history.beforeAfter(report.project, mode: mode)
        if days.contains(where: { $0 != nil }) || ba != nil {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tr("Isrof ulushi · 14 kun", "Waste share · 14 days")).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    MiniBars(values: days.map { ($0?.wasteShare(mode) ?? 0) * 100 }, color: wasteColor, highlightLast: 1)
                        .frame(width: 168, height: 26)
                        .help(tr("Har kun — loyiha sarfining necha foizi isrof bo'lgani", "Each day — what share of the project's usage was waste"))
                }
                if let ba {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(tr("Tuzatish · \(Fmt.shortDay.string(from: ba.fixedAt))", "Fixed · \(Fmt.shortDay.string(from: ba.fixedAt))"))
                            .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                        if let after = ba.after {
                            let before = ba.before
                            HStack(spacing: 6) {
                                Text(before.map { "\(Int(($0 * 100).rounded()))%" } ?? "—").foregroundStyle(.secondary)
                                Image(systemName: "arrow.right").font(.caption2)
                                Text("\(Int((after * 100).rounded()))%")
                                    .foregroundStyle(before.map { after < $0 } ?? true ? Brand.ok : Brand.warn)
                            }
                            .font(.callout.weight(.semibold)).monospacedDigit()
                        } else {
                            Text(tr("natija ertadan ko'rinadi", "results show from tomorrow")).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                } else if let today = days.last ?? nil {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(tr("Bugun", "Today")).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                        Text("\(Int((today.wasteShare(mode) * 100).rounded()))%")
                            .font(.callout.weight(.semibold)).monospacedDigit().foregroundStyle(wasteColor)
                    }
                    Text(tr("Tuzatish qo'llangach bu yerda «avval → keyin» natijasi chiqadi",
                            "Once a fix is applied, the before → after result shows here"))
                        .font(.caption).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
        }
    }

    private func copyPrompt() {
        handed = true
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(ProjectSavings.prompt(for: report, period: period), forType: .string)
        withAnimation(Motion.snappy) { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { withAnimation(Motion.snappy) { copied = false } }
    }

    private func openTerminal(_ path: String) {
        let terminal = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        NSWorkspace.shared.open([URL(fileURLWithPath: path)], withApplicationAt: terminal, configuration: NSWorkspace.OpenConfiguration())
    }
}

/// Plagin bilan bir buyruq: Claude Code'da `/tokenkuzat:optimize` — hisobotni o'zi oladi va tuzatishni boshlaydi
private struct OptimizeCommandCard: View {
    @State private var copied = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ToolTile(symbol: "command", color: Brand.accent, size: 34)
            VStack(alignment: .leading, spacing: 6) {
                Text(tr("Bir buyruq bilan", "With one command")).font(.callout.weight(.semibold))
                Text(tr("Token Kuzatuv plagini o'rnatilgan bo'lsa, loyihada Claude Code'ni oching va yozing — Claude shu loyiha hisobotini "
                        + "MCP orqali o'zi oladi, sabablarni tushuntiradi va tuzatishlarni tasdig'ingiz bilan qo'llaydi.",
                        "With the Token Kuzatuv plugin installed, open Claude Code in the project and type this — Claude fetches the project's "
                        + "report over MCP, explains the causes and applies fixes with your approval."))
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Text("/tokenkuzat:optimize")
                        .font(.system(.callout, design: .monospaced).weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Brand.accentSoft))
                        .textSelection(.enabled)
                    Button(copied ? tr("Nusxalandi", "Copied") : tr("Nusxa olish", "Copy")) {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString("/tokenkuzat:optimize", forType: .string)
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                    }
                    .buttonStyle(.link).font(.caption)
                }
            }
            Spacer(minLength: 0)
        }
        .card()
    }
}
