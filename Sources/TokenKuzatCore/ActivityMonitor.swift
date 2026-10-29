import Foundation

/// Foydalanuvchiga xabar berishga arziydigan hodisa.
public struct ActivityEvent: Equatable {
    public enum Kind: Equatable {
        /// Sessiya ishni tugatdi va javobingizni kutyapti
        case finished(duration: TimeInterval, tokens: Int, steps: Int)
        /// Qadam uzoq vaqtdan beri tugamadi (ruxsat so'rayotgan yoki osilib qolgan bo'lishi mumkin)
        case stuck(step: String, duration: TimeInterval)
        /// Agent ketma-ket bir necha marta xato oldi
        case errorStreak(count: Int, lastStep: String)
        /// Yordamchi agent ishini tugatdi, asosiy agent esa hali ishlayapti
        case helperFinished(duration: TimeInterval, tokens: Int, steps: Int)
    }

    public let kind: Kind
    public let sessionId: String
    public let project: String
    public let title: String
    public let agentTitle: String
}

/// Snapshot'larni ketma-ket solishtirib, holat o'zgarishlaridan hodisa chiqaradi.
/// Ilova ochilgandagi birinchi snapshot faqat «eslab qolinadi» — eski holatlar uchun xabar yuborilmaydi.
public final class ActivityMonitor {
    public struct Config: Equatable {
        /// Shundan qisqa ish uchun «tugadi» xabari yuborilmaydi
        public var finishMin: TimeInterval = 60
        public var stuckAfter: TimeInterval = 90
        public var errorStreak = 3

        public init(finishMin: TimeInterval = 60, stuckAfter: TimeInterval = 90, errorStreak: Int = 3) {
            self.finishMin = finishMin
            self.stuckAfter = stuckAfter
            self.errorStreak = errorStreak
        }
    }

    private struct Run {
        let start: Date
        let tokens: Int
        let steps: Int
    }

    private var runs: [String: Run] = [:]
    /// Yordamchi agentlar: «sessiya/agent» → ishga tushgan payt
    private var helperRuns: [String: Run] = [:]
    private var seenStuck = Set<String>()
    private var seenStreak = Set<String>()
    private var primed = false

    public init() {}

    public func process(_ s: Snapshot, config: Config = Config()) -> [ActivityEvent] {
        guard s.initialScanDone else { return [] }
        let now = s.updatedAt
        var events: [ActivityEvent] = []
        let priming = !primed
        primed = true

        for session in s.sessions {
            let steps = session.agents.reduce(0) { $0 + $1.steps.count }
            func event(_ kind: ActivityEvent.Kind, _ agent: AgentSnap?) -> ActivityEvent {
                ActivityEvent(kind: kind, sessionId: session.id, project: session.project, title: session.title,
                              agentTitle: agent.map { $0.isMain ? tr("Asosiy agent", "Main agent") : $0.title } ?? "")
            }

            // Tugadi: faol → tinch
            if session.state != .idle {
                if runs[session.id] == nil {
                    runs[session.id] = Run(start: now, tokens: session.tokens.total, steps: steps)
                }
            } else if let run = runs.removeValue(forKey: session.id) {
                let duration = (session.lastActivity ?? now).timeIntervalSince(run.start)
                if duration >= config.finishMin {
                    events.append(event(.finished(duration: duration, tokens: session.tokens.total - run.tokens,
                                                  steps: steps - run.steps), session.main))
                }
            }

            for agent in session.agents where !agent.isMain {
                let key = session.id + "/" + agent.id
                if agent.state != .idle {
                    if helperRuns[key] == nil { helperRuns[key] = Run(start: now, tokens: agent.tokens.total, steps: agent.steps.count) }
                } else if let run = helperRuns.removeValue(forKey: key), session.state != .idle {
                    // Sessiya ham tinchisa — umumiy «tugadi» xabari yetadi
                    let duration = (agent.lastActivity ?? now).timeIntervalSince(run.start)
                    if duration >= config.finishMin {
                        events.append(event(.helperFinished(duration: duration, tokens: agent.tokens.total - run.tokens,
                                                            steps: agent.steps.count - run.steps), agent))
                    }
                }
            }

            for agent in session.agents {
                // Osilib qolgan qadam
                if let last = agent.steps.last, last.status == .running, let d = last.duration, d >= config.stuckAfter,
                   seenStuck.insert(last.id).inserted, !priming {
                    events.append(event(.stuck(step: last.text, duration: d), agent))
                }
                // Ketma-ket xatolar
                let tail = agent.steps.suffix(config.errorStreak)
                if tail.count == config.errorStreak, tail.allSatisfy({ $0.status == .failed }),
                   let last = tail.last, seenStreak.insert(last.id).inserted, !priming {
                    events.append(event(.errorStreak(count: config.errorStreak, lastStep: last.text), agent))
                }
            }
        }
        // Yo'qolgan sessiya va agentlar eslab qolinmaydi
        let alive = Set(s.sessions.flatMap { sess in sess.agents.map { sess.id + "/" + $0.id } })
        helperRuns = helperRuns.filter { alive.contains($0.key) }
        return events
    }
}
