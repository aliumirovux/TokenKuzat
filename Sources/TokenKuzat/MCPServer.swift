import Foundation
import TokenKuzatCore

/// MCP server (`--mcp`): Claude Code'ga token sarfi va sessiyalar haqida asboblar beradi.
///
/// stdio orqali JSON-RPC 2.0, har xabar — bitta qator. Oynasiz ishlaydi, ilova ochiq bo'lishi shart emas:
/// o'z Engine'ini yurgizadi va ilova bilan bir xil fayllarni (`~/.claude/projects` va h.k.) faqat o'qiydi.
/// Tarixga yozmaydi — kunlik tarixni faqat ilovaning o'zi saqlaydi.
enum MCPServer {
    static let flag = "--mcp"

    /// Birinchi asbob chaqirilganda yaratiladi (ishga tushish tez bo'lsin), keyin faqat yangi baytlarni o'qiydi
    private static var engine: Engine?

    static func runAndExit() -> Never {
        setvbuf(stdout, nil, _IOLBF, 0)
        while let line = readLine(strippingNewline: true) {
            guard !line.isEmpty, let data = line.data(using: .utf8),
                  let msg = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { continue }
            if let reply = handle(msg) { send(reply) }
        }
        exit(0)
    }

    // MARK: JSON-RPC

    private static func handle(_ msg: [String: Any]) -> [String: Any]? {
        let id = msg["id"]
        let method = msg["method"] as? String ?? ""
        let params = msg["params"] as? [String: Any] ?? [:]
        // Bildirishnomalarga (id yo'q) javob berilmaydi
        guard let id else { return nil }
        switch method {
        case "initialize":
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
            return ok(id, [
                "protocolVersion": params["protocolVersion"] as? String ?? "2025-06-18",
                "capabilities": ["tools": [String: Any]()],
                "serverInfo": ["name": "tokenkuzat", "version": version],
                "instructions": "Token Kuzatuv: Claude Code token sarfi, limit va sessiyalar. Javoblarni foydalanuvchi tilida bering.",
            ])
        case "ping":
            return ok(id, [String: Any]())
        case "tools/list":
            return ok(id, ["tools": tools])
        case "tools/call":
            let name = params["name"] as? String ?? ""
            let args = params["arguments"] as? [String: Any] ?? [:]
            guard let result = call(name, args) else {
                return ok(id, ["content": [["type": "text", "text": "Noma'lum asbob: \(name)"]], "isError": true])
            }
            let text = (try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
            return ok(id, ["content": [["type": "text", "text": text]], "isError": false])
        default:
            return ["jsonrpc": "2.0", "id": id, "error": ["code": -32601, "message": "Method not found: \(method)"]]
        }
    }

    private static func ok(_ id: Any, _ result: [String: Any]) -> [String: Any] {
        ["jsonrpc": "2.0", "id": id, "result": result]
    }

    private static func send(_ o: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: o),
              let s = String(data: data, encoding: .utf8) else { return }
        print(s)
    }

    // MARK: Asboblar

    private static let tools: [[String: Any]] = [
        [
            "name": "usage_summary",
            "description": "Today's and last-5-hours Claude token usage, current burn rate, real plan limits (5-hour and weekly %, reset times) if connected, estimated share of the limit used outside this Mac (claude.ai/desktop chats, cloud sessions), and which sessions are running or waiting for permission.",
            "inputSchema": ["type": "object", "properties": [String: Any]()],
        ],
        [
            "name": "list_sessions",
            "description": "Recent Claude Code / Cowork sessions, newest first: project, state, model, tokens, context fill, number of prompts, last prompt and helper agents.",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "limit": ["type": "integer", "description": "How many sessions (default 10, max 50)"],
                    "project": ["type": "string", "description": "Only sessions of this project (folder name)"],
                ],
            ],
        ],
        [
            "name": "session_details",
            "description": "One session in detail: every prompt (turn) with duration, tokens, steps, errors and tools used; agents with their token use and top tools; large tool results that bloat the context. Pass session_id, or project to get its latest session.",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "session_id": ["type": "string", "description": "Session id from list_sessions"],
                    "project": ["type": "string", "description": "Project name — its most recent session is used"],
                ],
            ],
        ],
    ]

    private static func call(_ name: String, _ args: [String: Any]) -> [String: Any]? {
        let e = engine ?? Engine()
        engine = e
        let now = Date()
        var snap = e.tick(now: now)
        snap.limits = RateLimitsReader().read()?.active(at: now)
        // Ilova yozgan holatdan faqat o'qiladi
        let out = OutsideUsageTracker().summary(now: now)
        if out.hasWindow || out.outsideTodayPct > 0 { snap.outside = out }
        let notices = HookEvents.read()
        for s in snap.sessions {
            if let n = notices[s.id], n.isPending(lastActivity: s.lastActivity, now: now) { snap.permissionWaits[s.id] = n }
        }
        switch name {
        case "usage_summary": return summary(snap, now: now)
        case "list_sessions": return sessions(snap, args, now: now)
        case "session_details": return details(snap, args, now: now)
        default: return nil
        }
    }

    private static func summary(_ s: Snapshot, now: Date) -> [String: Any] {
        var o: [String: Any] = [
            "today": tokens(s.today),
            "last_5_hours": tokens(s.lastFiveHours),
            "tokens_per_minute": ["raw": Int(s.rateRaw), "weighted": Int(s.rateWeighted)],
            "active_minutes_today": s.activeMinutesToday,
            "running_sessions": s.sessions.filter { $0.state != .idle }.map { brief($0, s, now: now) },
            "waiting_for_permission": s.sessions.filter { s.permissionWaits[$0.id] != nil }.map(\.project),
            "updated_at": iso(now),
        ]
        if let l = s.limits {
            var lim: [String: Any] = ["updated_at": iso(l.updatedAt)]
            if let w = l.fiveHour { lim["five_hour"] = window(w) }
            if let w = l.sevenDay { lim["weekly"] = window(w) }
            if let p = l.plan { lim["plan"] = p }
            o["limits"] = lim
        } else {
            o["limits"] = "Ulanmagan: Token Kuzatuv → Sozlamalar → «Claude Code'ga ulash»"
        }
        if let x = s.outside {
            func r(_ v: Double) -> Double { (v * 10).rounded() / 10 }
            var d: [String: Any] = [
                "note": "Estimate. Chats and cloud sessions are not written to this Mac; their share is the real limit growth minus this Mac's usage. Percent of the 5-hour limit.",
                "today_outside_percent": r(x.outsideTodayPct),
            ]
            if x.hasWindow {
                d["current_window"] = ["mac_percent": r(x.macPct), "chat_and_cloud_percent": r(x.outsidePct),
                                       "not_yet_split_percent": r(x.uncertainPct), "before_tracking_percent": r(x.unobservedPct)]
            }
            if let t = x.outsideTodayTokens { d["today_outside_weighted_tokens"] = Int(t) }
            if let k = x.tokensPerPct { d["weighted_tokens_per_percent"] = Int(k) }
            o["chat_and_cloud"] = d
        }
        return o
    }

    private static func sessions(_ s: Snapshot, _ args: [String: Any], now: Date) -> [String: Any] {
        let limit = min(50, max(1, (args["limit"] as? Int) ?? 10))
        let project = (args["project"] as? String)?.lowercased()
        let list = s.sessions
            .filter { project == nil || $0.project.lowercased() == project }
            .sorted { ($0.lastActivity ?? .distantPast) > ($1.lastActivity ?? .distantPast) }
            .prefix(limit)
        return ["sessions": list.map { brief($0, s, now: now) }]
    }

    private static func details(_ s: Snapshot, _ args: [String: Any], now: Date) -> [String: Any] {
        let byId = (args["session_id"] as? String).flatMap { id in s.sessions.first { $0.id == id } }
        let byProject = (args["project"] as? String).flatMap { p in
            s.sessions.filter { $0.project.lowercased() == p.lowercased() }
                .max { ($0.lastActivity ?? .distantPast) < ($1.lastActivity ?? .distantPast) }
        }
        guard let sess = byId ?? byProject ?? s.sessions.max(by: { ($0.lastActivity ?? .distantPast) < ($1.lastActivity ?? .distantPast) }) else {
            return ["error": "Sessiya topilmadi"]
        }
        var o = brief(sess, s, now: now)
        o["turns"] = sess.turns.suffix(30).map { t -> [String: Any] in
            [
                "number": t.id,
                "prompt": clip(t.prompt, 300),
                "started_at": iso(t.start),
                "duration_seconds": Int(t.end.timeIntervalSince(t.start)),
                "tokens": tokens(t.tokens),
                "steps": t.steps,
                "errors": t.errors,
                "active": t.active,
                "tools": t.tools.map { ["category": $0.category.title, "calls": $0.calls, "errors": $0.errors, "top": $0.top] },
                "helper_agents": t.helpers,
            ]
        }
        o["agents"] = sess.agents.map { a -> [String: Any] in
            [
                "title": a.title,
                "kind": a.subtitle,
                "main": a.isMain,
                "state": state(a.state),
                "tokens": tokens(a.tokens),
                "tool_calls": a.calls,
                "top_tools": a.topTools.prefix(5).map { ["name": $0.name, "count": $0.count] },
                "last_action": a.lastAction,
            ]
        }
        let big = sess.agents.flatMap(\.bigResults).sorted { $0.tokens > $1.tokens }.prefix(10)
        if !big.isEmpty {
            o["large_tool_results"] = big.map { ["tokens": $0.tokens, "step": $0.label, "at": iso($0.date)] }
        }
        return o
    }

    // MARK: Yordamchilar

    private static func brief(_ x: SessionSnap, _ s: Snapshot, now: Date) -> [String: Any] {
        var o: [String: Any] = [
            "session_id": x.id,
            "project": x.project,
            "title": x.title,
            "model": Fmt.model(x.model),
            "state": s.permissionWaits[x.id] != nil ? "waiting_for_permission" : state(x.state),
            "tokens": tokens(x.tokens),
            "context_percent": Int((x.contextFraction * 100).rounded()),
            "prompts": x.turns.count,
            "helper_agents": x.agents.filter { !$0.isMain }.map(\.title),
        ]
        if let d = x.lastActivity { o["last_activity"] = iso(d); o["last_activity_ago"] = Fmt.ago(d, now: now) }
        if let t = x.turns.last { o["last_prompt"] = clip(t.prompt, 200) }
        if let a = x.main?.lastAction, !a.isEmpty { o["current_action"] = a }
        if let c = s.limits?.costBySession[x.id] { o["cost_usd"] = (c * 100).rounded() / 100 }
        return o
    }

    private static func tokens(_ t: TokenCounts) -> [String: Any] {
        ["total": t.total, "input": t.input, "output": t.output, "cache_read": t.cacheRead, "cache_write": t.cacheWrite,
         "weighted": Int(t.value(.weighted))]
    }

    private static func window(_ w: LimitWindow) -> [String: Any] {
        ["used_percent": Int(w.usedPercentage.rounded()), "resets_at": iso(w.resetsAt)]
    }

    private static func state(_ s: AgentState) -> String {
        switch s {
        case .running: return "running"
        case .waiting: return "waiting_for_tool"
        case .idle: return "idle"
        }
    }

    private static func clip(_ s: String, _ n: Int) -> String { s.count > n ? String(s.prefix(n)) + "…" : s }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.timeZone = .current
        return f
    }()

    private static func iso(_ d: Date) -> String { isoFormatter.string(from: d) }
}
