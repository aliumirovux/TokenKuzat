import Foundation
import TokenKuzatCore

/// «Loyihalar» ro'yxati va «Avtomatik davom» xulosalari. Fon navbatida: git va xulosa yasash sekin bo'lishi mumkin.
final class ProjectTracker: ObservableObject {
    static let shared = ProjectTracker()

    @Published private(set) var cards: [ProjectCard] = []

    private let queue = DispatchQueue(label: "uz.ali.tokenkuzat.projects", qos: .utility)
    private var busy = false
    private var lastRun = Date.distantPast
    /// Papka → git holati va qachon olingani
    private var gitCache: [String: (ProjectGit?, Date)] = [:]
    /// Papka → xulosa yozilgan sessiya va uning oxirgi harakati
    private var written: [String: (String, Date)] = [:]

    /// Sessiya shuncha jim tursa — xulosa yoziladi (javob yarmida ham: oyna yopilgan bo'lishi mumkin)
    static let quiet: TimeInterval = 20
    private static let gitTTL: TimeInterval = 30

    /// Store har yangilanishda chaqiradi; o'zi 5 soniyada bir martadan ko'p ishlamaydi
    func update(_ snap: Snapshot, now: Date = Date()) {
        guard snap.initialScanDone, !busy, now.timeIntervalSince(lastRun) >= 5 else { return }
        busy = true
        lastRun = now
        let sessions = snap.sessions
        queue.async { [self] in
            var cards = ProjectBoard.cards(sessions)
            for i in cards.indices {
                let f = cards[i].folder
                if let (g, at) = gitCache[f], now.timeIntervalSince(at) < Self.gitTTL || cards[i].running {
                    cards[i].git = g
                } else {
                    let g = ProjectBoard.git(f)
                    gitCache[f] = (g, now)
                    cards[i].git = g
                }
            }
            if UserDefaults.standard.bool(forKey: Pref.autoResume) {
                writeResume(cards, sessions: sessions, now: now)
            }
            DispatchQueue.main.async {
                if cards != self.cards { self.cards = cards }
                self.busy = false
            }
        }
    }

    private func writeResume(_ cards: [ProjectCard], sessions: [SessionSnap], now: Date) {
        for c in cards where now.timeIntervalSince(c.lastActivity) < ResumeStore.lifetime
            && now.timeIntervalSince(c.lastActivity) >= Self.quiet {
            if let w = written[c.folder], w.0 == c.sessionId, w.1 == c.lastActivity { continue }
            // «salom», «davom et» kabi qisqa xabarli sessiya oldingi xulosani almashtirmaydi — u hali o'sha ishda
            guard let s = sessions.first(where: { $0.id == c.sessionId }),
                  s.turns.contains(where: { $0.prompt.count >= AutoHandoffRule.meaningfulLength
                                              && !AutoHandoffRule.isHandoffPrompt($0.prompt) && !$0.isContinuation })
            else { continue }
            let text = SavingsAdvisor.handoff(for: s)
            try? ResumeStore.save(PendingHandoff(text: text, sourceSession: s.id, cwd: c.folder, created: c.lastActivity,
                                                 english: SavingsAdvisor.conversationEnglish(s)))
            written[c.folder] = (c.sessionId, c.lastActivity)
        }
        ResumeStore.prune(keep: Set(cards.map(\.folder)), now: now)
    }

    /// Sozlama o'chirilganda — saqlangan xulosalar o'chiriladi
    func disableResume() {
        queue.async { [self] in
            written = [:]
            ResumeStore.clear()
        }
    }
}
