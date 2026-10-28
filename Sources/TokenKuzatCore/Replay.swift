import Foundation

// Replay: sessiya `t` paytda qanday ko'rinishda bo'lgan — faqat o'sha paytgacha bo'lgan qadamlar va tokenlar,
// o'sha paytda tugamagan qadam «bajarilmoqda», hali boshlanmagan yordamchi agent esa umuman yo'q.
// Hamma narsa snapshot'dagi ma'lumotdan qayta quriladi — diskka murojaat yo'q, shuning uchun slayderni
// surish tez ishlaydi.

extension StepSnap {
    /// Qadam tugagan vaqt (ma'lum bo'lsa)
    var end: Date? {
        guard status != .running, let d = duration else { return nil }
        return date.addingTimeInterval(d)
    }

    func at(_ t: Date) -> StepSnap? {
        guard date <= t else { return nil }
        let finished = end.map { $0 <= t } ?? false
        if finished || (status != .running && duration == nil) { return self }
        // Hali tugamagan: davomiyligi — shu paytgacha, xato ham hali ma'lum emas
        return StepSnap(id: id, date: date, symbol: symbol, text: text, category: category, targetName: targetName,
                        targetKey: targetKey, targetDetail: targetDetail, access: access,
                        duration: t.timeIntervalSince(date), status: .running, turn: turn)
    }
}

extension SessionSnap {
    /// Sessiyaning `t` paytdagi holati
    public func replay(at t: Date) -> SessionSnap {
        var replayed: [AgentSnap] = []
        for a in agents {
            let steps = a.steps.compactMap { $0.at(t) }
            let usage = a.usage.filter { $0.date <= t }
            let started = a.isMain || (a.firstActivity.map { $0 <= t } ?? false)
            guard started else { continue }
            let tokens = usage.reduce(TokenCounts()) { $0 + $1.tokens }
            let lastSeen = ([steps.last.map(\.date), usage.last?.date, a.firstActivity.flatMap { $0 <= t ? $0 : nil }]
                .compactMap { $0 }).max()
            let running = steps.last?.status == .running
            let state: AgentState
            if running {
                state = .running
            } else if let ls = lastSeen, t.timeIntervalSince(ls) < 15,
                      a.lastActivity.map({ $0 > t }) ?? false {
                state = .running
            } else if let ls = lastSeen, a.lastActivity.map({ $0 > t }) ?? false, t.timeIntervalSince(ls) < 300 {
                // Keyin yana harakat bor — demak hozir model o'ylayapti
                state = .running
            } else {
                state = .idle
            }
            replayed.append(AgentSnap(
                id: a.id, title: a.title, subtitle: a.subtitle, kind: a.kind, isMain: a.isMain,
                tokens: tokens, calls: usage.count, topTools: SessionSnap.topTools(steps),
                lastAction: steps.last?.text ?? (a.isMain ? "So'rov oldi" : "Boshlandi"),
                state: state, lastActivity: lastSeen, firstActivity: a.firstActivity,
                steps: steps, resources: SessionSnap.resourceGroups(steps, now: t), usage: usage,
                bigResults: a.bigResults.filter { $0.date <= t }, outputs: a.outputs.filter { $0.value <= t }))
        }

        let main = replayed.filter(\.isMain).reduce(TokenCounts()) { $0 + $1.tokens }
        let sub = replayed.filter { !$0.isMain }.reduce(TokenCounts()) { $0 + $1.tokens }
        let best = replayed.map(\.state).max() ?? .idle
        let allUsage = replayed.flatMap(\.usage)
        let allSteps = replayed.flatMap(\.steps)
        let visibleTurns = turns.filter { $0.start <= t }
        let turnsAtT: [TurnSnap] = visibleTurns.enumerated().map { i, turn in
            let nextStart = i + 1 < visibleTurns.count ? visibleTurns[i + 1].start : Date.distantFuture
            let inTurn: (Date) -> Bool = { $0 >= turn.start && $0 < nextStart }
            let steps = allSteps.filter { inTurn($0.date) }
            let usage = allUsage.filter { inTurn($0.date) }
            let end = ([turn.start] + steps.map { $0.end ?? $0.date } + usage.map(\.date)).max() ?? turn.start
            return TurnSnap(id: turn.id, prompt: turn.prompt, start: turn.start, end: min(end, t),
                            tokens: usage.reduce(TokenCounts()) { $0 + $1.tokens }, steps: steps.count,
                            errors: steps.filter { $0.status == .failed }.count,
                            active: best != .idle && i == visibleTurns.count - 1,
                            tools: Self.tools(steps),
                            helpers: turn.helpers)
        }
        let context = replayed.first(where: \.isMain)?.usage.last.map { $0.tokens.input + $0.tokens.cacheRead + $0.tokens.cacheWrite } ?? 0

        return SessionSnap(id: id, project: project, title: title, model: model, contextTokens: context,
                           tokens: main + sub, mainTokens: main, agentTokens: sub, agents: replayed,
                           lastActivity: replayed.compactMap(\.lastActivity).max(), state: best, turns: turnsAtT,
                           contextWindow: contextWindow, notes: notes.filter { $0.date <= t }, cwd: cwd)
    }

    /// Replay oralig'i: birinchi harakatdan oxirgisigacha
    public var timeRange: ClosedRange<Date>? {
        let dates = agents.flatMap { a in [a.firstActivity, a.lastActivity].compactMap { $0 } + a.steps.map(\.date) }
            + turns.map(\.start)
        guard let lo = dates.min(), let hi = dates.max(), hi > lo else { return nil }
        return lo...hi
    }

    static func topTools(_ steps: [StepSnap]) -> [(name: String, count: Int)] {
        Dictionary(grouping: steps, by: { $0.category.title }).map { (name: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    /// Qadamlardan resurslar (Engine'dagi bilan bir xil ko'rinishda)
    static func resourceGroups(_ steps: [StepSnap], now: Date) -> [ResourceGroup] {
        Dictionary(grouping: steps, by: \.category).map { cat, list -> ResourceGroup in
            let byKey = Dictionary(grouping: list, by: \.targetKey)
            let items = byKey.map { key, ss -> ResourceItem in
                ResourceItem(id: key, name: ss[0].targetName, detail: ss[0].targetDetail, calls: ss.count,
                             reads: ss.filter { $0.access == .read }.count,
                             writes: ss.filter { $0.access == .write }.count,
                             errors: ss.filter { $0.status == .failed }.count,
                             lastActivity: ss.map(\.date).max())
            }
            .sorted { ($0.lastActivity ?? .distantPast) > ($1.lastActivity ?? .distantPast) }
            return ResourceGroup(category: cat, calls: list.count, errors: list.filter { $0.status == .failed }.count,
                                 lastActivity: items.first?.lastActivity, items: items,
                                 busy: list.contains { $0.status == .running })
        }
        .sorted { ($0.lastActivity ?? .distantPast) > ($1.lastActivity ?? .distantPast) }
    }

    /// Replay'dagi so'rov uchun asbob turlari xulosasi (ko'rinib turgan qadamlardan)
    static func tools(_ steps: [StepSnap]) -> [TurnTool] {
        Dictionary(grouping: steps, by: \.category).map { cat, list in
            let top = Dictionary(grouping: list, by: \.targetName).max { $0.value.count < $1.value.count }?.key ?? ""
            return TurnTool(category: cat, calls: list.count, errors: list.filter { $0.status == .failed }.count,
                            top: top, busy: list.contains { $0.status == .running })
        }
        .sorted { $0.calls > $1.calls }
    }
}
