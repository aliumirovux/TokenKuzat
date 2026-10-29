import SwiftUI
import AppKit
import TokenKuzatCore

/// «Tejash» sahifasi: loyihalar bo'yicha sarf, qayerda isrof bor va uni bir bosishda Claude'ga tuzattirish.
/// Model va sifat o'zgarmaydi — faqat behuda qayta o'qilayotgan kontekst va og'ir sozlamalar kamaytiriladi.
struct ProjectSavingsView: View {
    @EnvironmentObject var store: Store
    @AppStorage(Pref.countMode) private var mode = CountMode.raw
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
                    Picker(tr("Davr", "Period"), selection: $period) {
                        ForEach(SavingsPeriod.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().fixedSize()
                    Spacer()
                    Text(tr("model va sifat o'zgarmaydi", "model and quality stay the same")).font(.caption).foregroundStyle(.secondary)
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
                                   symbol: "sum", tint: .blue)
                        MetricTile(title: tr("Taxminiy isrof", "Estimated waste"), value: Fmt.tokens(waste), unit: tr("token", "tokens"),
                                   footnote: tr("sarfning \(Fmt.percent(waste, of: total)) — tejasa bo'ladi",
                                                "\(Fmt.percent(waste, of: total)) of usage — can be saved"),
                                   symbol: "leaf.fill", tint: Brand.ok)
                        MetricTile(title: tr("Eng ko'p isrof", "Most waste"), value: worst?.project ?? "—",
                                   footnote: worst.map { r in
                                       r.issues.first.map { $0.title } ?? tr("isrof topilmadi", "no waste found")
                                   } ?? "—",
                                   symbol: "flame.fill", tint: .orange)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        SectionHeader(title: tr("Loyihalar", "Projects"),
                                      subtitle: tr("sarf bo'yicha · bosing — sabablar va tuzatish", "by usage · click for causes and fixes"))
                            .padding(.bottom, 6)
                        ForEach(reports) { r in
                            ProjectSavingsRow(report: r, period: period, mode: mode,
                                              share: total > 0 ? r.tokens.value(mode) / total : 0,
                                              session: r.latestSession.flatMap { id in store.snap.sessions.first { $0.id == id } },
                                              expanded: expanded.contains(r.id)) {
                                withAnimation(Motion.snappy) {
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
}

private struct ProjectSavingsRow: View {
    let report: ProjectReport
    let period: SavingsPeriod
    let mode: CountMode
    let share: Double
    let session: SessionSnap?
    let expanded: Bool
    let onToggle: () -> Void
    @State private var copied = false

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
                                Capsule().fill(wasteColor.opacity(0.9))
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

            if expanded { details.transition(.opacity.combined(with: .move(edge: .top))) }
        }
    }

    @ViewBuilder
    private var details: some View {
        VStack(alignment: .leading, spacing: 12) {
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

    private func copyPrompt() {
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
