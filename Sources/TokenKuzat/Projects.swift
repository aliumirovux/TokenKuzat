import Foundation
import SwiftUI
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
    /// Loyihalar sahifasi yoki menyu ochiq — git faqat shunda so'raladi: loyiha «Hujjatlar»da bo'lsa macOS ruxsat so'raydi,
    /// bu so'rov ilova ochilishida emas, loyihalarga qaraganda chiqsin
    private var viewers: Set<String> = []

    /// Oyna haqiqatan ekranda ko'rinadimi — WindowVisibility xabar beradi (menyu oynasi yopilganda ham)
    func setViewer(_ id: String, visible: Bool) {
        let was = viewers.isEmpty
        if visible { viewers.insert(id) } else { viewers.remove(id) }
        if was && !viewers.isEmpty { lastRun = .distantPast }
    }

    /// Store har yangilanishda chaqiradi; o'zi 5 soniyada bir martadan ko'p ishlamaydi
    func update(_ snap: Snapshot, now: Date = Date()) {
        guard snap.initialScanDone, !busy, now.timeIntervalSince(lastRun) >= 5 else { return }
        busy = true
        lastRun = now
        let sessions = snap.sessions
        let wantGit = !viewers.isEmpty
        queue.async { [self] in
            var cards = ProjectBoard.cards(sessions)
            for i in cards.indices {
                let f = cards[i].folder
                if let (g, at) = gitCache[f], !wantGit || now.timeIntervalSince(at) < Self.gitTTL || cards[i].running {
                    cards[i].git = g
                } else if wantGit {
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
            // Ilova qayta ochilganda: xulosa avvalgi ishga tushishda yozilgan bo'lsa — qayta yozilmaydi (git ham chaqirilmaydi)
            if written[c.folder] == nil, let saved = ResumeStore.load(folder: c.folder), saved.sourceSession == c.sessionId,
               abs(saved.created.timeIntervalSince(c.lastActivity)) < 1 {
                written[c.folder] = (c.sessionId, c.lastActivity)
            }
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

    /// Ko'rinish joylashgan oyna ekranda ko'rinadimi: onAppear/onDisappear menyu oynasida ishonchsiz (ko'rinish yopilganda
    /// yo'q qilinmaydi), shuning uchun oynaning occlusion holati kuzatiladi
    struct WindowVisibility: NSViewRepresentable {
        let id: String

        func makeNSView(context: Context) -> Probe { Probe(id: id) }
        func updateNSView(_ view: Probe, context: Context) {}
        static func dismantleNSView(_ view: Probe, coordinator: ()) { view.report(false) }

        final class Probe: NSView {
            let id: String
            private var observer: NSObjectProtocol?

            init(id: String) {
                self.id = id
                super.init(frame: .zero)
            }
            required init?(coder: NSCoder) { fatalError() }

            override func viewDidMoveToWindow() {
                super.viewDidMoveToWindow()
                if let observer { NotificationCenter.default.removeObserver(observer) }
                observer = nil
                guard let w = window else { report(false); return }
                report(w.occlusionState.contains(.visible))
                observer = NotificationCenter.default.addObserver(forName: NSWindow.didChangeOcclusionStateNotification,
                                                                  object: w, queue: .main) { [weak self] _ in
                    guard let self, let w = self.window else { return }
                    self.report(w.occlusionState.contains(.visible))
                }
            }

            func report(_ visible: Bool) { ProjectTracker.shared.setViewer(id, visible: visible) }

            deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
        }
    }

    /// Sozlama o'chirilganda — saqlangan xulosalar o'chiriladi
    func disableResume() {
        queue.async { [self] in
            written = [:]
            ResumeStore.clear()
        }
    }
}
