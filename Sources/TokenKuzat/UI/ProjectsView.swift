import SwiftUI
import AppKit
import TokenKuzatCore

/// «Loyihalar» sahifasi: har loyiha — bitta karta. Qayerda qolgani, nima qolgani, sizdan nima kutilyapti va
/// git'da saqlanmagan ish. «Davom ettirish» Claude ilovasida shu papkada yangi sessiyani xulosa bilan ochadi.
struct ProjectsView: View {
    @EnvironmentObject var store: Store
    @ObservedObject private var tracker = ProjectTracker.shared
    @AppStorage(Pref.autoResume) private var autoResume = true

    var body: some View {
        let cards = tracker.cards
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: autoResume ? "arrow.uturn.forward.circle.fill" : "arrow.uturn.forward.circle")
                        .foregroundStyle(autoResume ? Brand.ok : .secondary)
                    Text(autoResume
                         ? tr("Avtomatik davom yoqilgan: loyiha papkasida yangi `claude` ochsangiz, Claude qayerda qolganini o'zi biladi (24 soat ichida).",
                              "Auto-resume is on: open a new `claude` in a project folder and Claude knows where things stopped (within 24 hours).")
                         : tr("Avtomatik davom o'chiq — Sozlamalarda yoqish mumkin.", "Auto-resume is off — turn it on in Settings."))
                        .font(.callout).foregroundStyle(.secondary)
                    Spacer()
                    Text(tr("So'nggi 7 kun · \(cards.count) ta loyiha", cards.count == 1 ? "Last 7 days · 1 project" : "Last 7 days · \(cards.count) projects"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                if cards.isEmpty {
                    EmptyStateView(symbol: "folder",
                                   title: store.snap.initialScanDone ? tr("Hali loyiha yo'q", "No projects yet") : tr("Yuklanmoqda…", "Loading…"),
                                   text: tr("Claude Code'da biror papkada ishlasangiz, loyiha shu yerda chiqadi.",
                                            "Work in Claude Code in any folder and the project shows up here."))
                        .padding(.top, 40)
                } else {
                    ForEach(cards) { ProjectCardView(card: $0, now: store.snap.updatedAt) }
                }
            }
            .padding(.horizontal, 24).padding(.bottom, 24)
        }
    }
}

private struct ProjectCardView: View {
    let card: ProjectCard
    let now: Date
    @State private var opening = false
    @State private var failed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ProjectAvatar(name: card.name, size: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.name).font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text(meta).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                statusBadge
            }
            if let task = card.task {
                line(tr("Ish", "Task"), task)
            }
            if let r = card.remaining {
                line(tr("Qolgan", "Left"), r)
            }
            if let q = card.question {
                line(tr("Savol", "Question"), q, color: Brand.warn)
            }
            if let g = card.git, g.dirty > 0 || (g.ahead ?? 0) > 0 {
                line("Git", gitText(g))
            }
            HStack {
                Button { NSWorkspace.shared.open(URL(fileURLWithPath: card.folder)) } label: {
                    Text(card.folder.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                }
                .buttonStyle(.plain)
                .help(tr("Finder'da ochish", "Open in Finder"))
                Spacer()
                if !card.running { continueButton }
            }
        }
        .card(highlight: card.status == .waiting ? Brand.warn : nil)
    }

    private var meta: String {
        let place = card.isTerminal ? "Terminal" : (card.origin == "claude-desktop" ? tr("Claude ilovasi", "Claude app") : (card.origin ?? "—"))
        let when = card.running ? tr("hozir ishlayapti", "working now") : Fmt.ago(card.lastActivity, now: now)
        let count = card.sessions > 1 ? tr(" · \(card.sessions) sessiya", " · \(card.sessions) sessions") : ""
        return "\(when) · \(place)\(count)"
    }

    @ViewBuilder
    private var statusBadge: some View {
        let (text, color): (String, Color) = {
            switch card.status {
            case .running: return (tr("Ishlayapti", "Working"), Brand.ok)
            case .waiting: return (tr("Javobingiz kutilyapti", "Waiting for you"), Brand.warn)
            case .unsaved: return (tr("Saqlanmagan ish bor", "Unsaved work"), Brand.accent)
            case .calm: return (tr("Tinch", "Idle"), Color.secondary)
            }
        }()
        Text(text)
            .font(.caption.weight(.semibold)).foregroundStyle(color)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.12)))
    }

    private func line(_ label: String, _ text: String, color: Color = .primary) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary).frame(width: 52, alignment: .leading)
            Text(text).font(.callout).foregroundStyle(color).lineLimit(3).textSelection(.enabled)
        }
    }

    private func gitText(_ g: ProjectGit) -> String {
        var parts: [String] = []
        if g.dirty > 0 { parts.append(tr("\(g.dirty) ta fayl commit qilinmagan", g.dirty == 1 ? "1 uncommitted file" : "\(g.dirty) uncommitted files")) }
        if let a = g.ahead, a > 0 { parts.append(tr("\(a) ta commit GitHub'ga yuborilmagan", a == 1 ? "1 commit not pushed" : "\(a) commits not pushed")) }
        return parts.joined(separator: " · ")
    }

    private var continueButton: some View {
        Button(action: open) {
            Label(failed ? tr("Ochib bo'lmadi", "Couldn't open") : tr("Davom ettirish", "Continue"),
                  systemImage: failed ? "exclamationmark.triangle.fill" : "arrow.right.circle")
                .font(.callout.weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .foregroundStyle(Brand.accent)
                .background(Capsule().fill(Brand.accentSoft))
        }
        .buttonStyle(.plain)
        .disabled(opening)
        .help(tr("Claude ilovasida shu papkada yangi sessiya ochiladi, xulosa yozib qo'yiladi — Enter bosing, Claude qayerda qolganini birinchi javobda aytadi.",
                 "Opens a new session in this folder in the Claude app with the summary filled in — press Enter and Claude says where things stopped in its first reply."))
    }

    private func open() {
        guard let sess = Store.shared.snap.sessions.first(where: { $0.id == card.sessionId }) else { failed = true; return }
        opening = true
        let folder = card.folder
        AutoHandoff.summary(for: sess) { summary in
            let english = SavingsAdvisor.conversationEnglish(sess)
            let ok = AutoHandoff.openInApp(cwd: folder, message: ProjectsView.resumeMessage(summary: summary, english: english))
            opening = false
            failed = !ok
        }
    }
}

extension ProjectsView {
    /// «Davom ettirish» tugmasidagi birinchi xabar: holatni aytib, kutadi
    static func resumeMessage(summary: String, english: Bool) -> String {
        Lang.with(english: english) {
            tr("Token Kuzatuv: foydalanuvchi shu loyihadagi oldingi ishni davom ettirish uchun yangi sessiya ochdi. "
               + "Quyidagi xulosaga tayan. 2–3 jumlada qayerda qolganini ayt: nima qilindi, nima qoldi, sizdan nima kutilyapti. "
               + "Keyin hech narsa boshlamay, foydalanuvchining javobini kut.",
               "Token Kuzatuv: the user opened a new session to continue earlier work in this project. "
               + "Rely on the summary below. In 2–3 sentences say where things stopped: what was done, what's left, what's pending "
               + "from the user. Then don't start anything — wait for the user.")
        } + "\n\n" + String(summary.prefix(8000))
    }
}
