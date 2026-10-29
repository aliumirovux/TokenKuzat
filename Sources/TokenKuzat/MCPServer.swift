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
            // Bepul model asbobi faqat FreeLLMAPI sozlangan bo'lsa ko'rinadi
            return ok(id, ["tools": tools + (FreeModels.load() != nil ? [freeTool] : [])])
        case "tools/call":
            let name = params["name"] as? String ?? ""
            let args = params["arguments"] as? [String: Any] ?? [:]
            if name == freeTool["name"] as? String {
                let (text, failed) = askFree(args)
                return ok(id, ["content": [["type": "text", "text": text]], "isError": failed])
            }
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
        [
            "name": "savings_report",
            "description": "Where tokens go by project and where they are wasted. Ranks projects by usage for the period and, for one project (the given one, or the one with the most waste), lists waste causes with estimated wasted tokens, the number of sessions affected, a remedy and the fix type (new_session, claude_rules = add rules to CLAUDE.md, connectors = disable unused MCP servers/plugins, habit). Also returns a ready task text for fixing it. Use it to reduce token usage without changing the model or quality; apply file changes only after the user approves them.",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "project": ["type": "string", "description": "Project folder name or path (e.g. the current working directory). Default: the project with the most waste"],
                    "period": ["type": "string", "enum": ["today", "week"], "description": "today or week (last 7 days, default)"],
                    "applied": ["type": "boolean", "description": "Set true after you applied fixes in this project (with the user's approval) — records the date so Token Kuzatuv can compare waste before and after"],
                ],
            ],
        ],
    ]

    private static let freeTool: [String: Any] = [
        "name": "ask_free_model",
        "description": "Send a small, self-contained text task to a free model through the user's local FreeLLMAPI gateway, to save the Claude limit: translating text, summarizing a long log or document you paste in, drafting boilerplate prose, classifying or extracting from given text. The free model sees ONLY the prompt (not this conversation or files), is weaker than Claude and may be wrong — put every needed piece of text in the prompt and check the answer before using it. Don't use it for code changes, decisions, or anything needing this conversation's context. Free providers may log or train on inputs: never send secrets, credentials, keys or private/customer data.",
        "inputSchema": [
            "type": "object",
            "properties": [
                "prompt": ["type": "string", "description": "The complete task with all text the model needs"],
                "system": ["type": "string", "description": "Optional system instruction (role, output format)"],
                "model": ["type": "string", "description": "Model id from the gateway; default auto (the gateway picks the best available free model)"],
                "max_tokens": ["type": "integer", "description": "Optional cap on the answer length"],
            ],
            "required": ["prompt"],
        ],
    ]

    /// FreeLLMAPI'ning `/v1/chat/completions` iga so'rov. Javob matni va xato bormi
    private static func askFree(_ args: [String: Any]) -> (String, Bool) {
        guard let c = FreeModels.load() else {
            return ("Free models are not set up: Token Kuzatuv → Settings → «Free models».", true)
        }
        guard let prompt = args["prompt"] as? String, !prompt.isEmpty else { return ("prompt is required", true) }
        guard let url = URL(string: FreeModels.rootURL(c.url) + "/v1/chat/completions"),
              let body = try? JSONSerialization.data(withJSONObject: FreeModels.chatRequest(
                prompt: prompt, system: args["system"] as? String, model: args["model"] as? String,
                maxTokens: (args["max_tokens"] as? NSNumber)?.intValue)) else { return ("Bad gateway address: \(c.url)", true) }
        var req = URLRequest(url: url, timeoutInterval: 120)
        req.httpMethod = "POST"
        req.httpBody = body
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(c.key)", forHTTPHeaderField: "Authorization")
        func send() -> (Data?, URLResponse?, Error?) {
            var out: (Data?, URLResponse?, Error?) = (nil, nil, nil)
            let done = DispatchSemaphore(value: 0)
            URLSession.shared.dataTask(with: req) { out = ($0, $1, $2); done.signal() }.resume()
            done.wait()
            return out
        }
        var out = send()
        // FreeLLMAPI ilovasi yopiq — ochib, bir marta qayta urinadi
        if (out.2 as? URLError)?.code == .cannotConnectToHost, FreeFallback.launchIfNeeded(c) { out = send() }
        if let err = out.2 { return ("FreeLLMAPI is not reachable at \(c.url): \(err.localizedDescription)", true) }
        let http = out.1 as? HTTPURLResponse
        guard let data = out.0, http?.statusCode == 200, let reply = FreeModels.chatReply(data) else {
            let why = out.0.flatMap(FreeModels.errorText) ?? "HTTP \(http?.statusCode ?? 0)"
            return ("FreeLLMAPI error: \(why)", true)
        }
        // Qaysi provayder javob bergani: «X-Routed-Via: groq/llama-…»
        let served = http?.value(forHTTPHeaderField: "X-Routed-Via") ?? reply.model ?? "unknown"
        if reply.thinkingOnly {
            return ("The free model (\(served)) spent its whole max_tokens on reasoning and gave no answer. "
                    + "Retry with a larger max_tokens (e.g. 2000) or leave it unset.", true)
        }
        var meta = "[free model: \(served)"
        if let t = reply.tokens { meta += ", \(t) tokens" }
        if reply.truncated { meta += ", cut off at max_tokens — the answer is incomplete" }
        meta += " — not Claude; verify before using]"
        return (reply.text + "\n\n" + meta, false)
    }

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
        case "savings_report": return savingsReport(snap, args, now: now)
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

    private static func savingsReport(_ s: Snapshot, _ args: [String: Any], now: Date) -> [String: Any] {
        let period = SavingsPeriod(rawValue: (args["period"] as? String) ?? "") ?? .week
        let reports = ProjectSavings.reports(s, period: period, now: now)
        guard !reports.isEmpty else { return ["error": "No Claude usage in this period"] }
        // Loyiha nomi yoki yo'li (joriy papka) bo'yicha; berilmasa — isrofi eng katta loyiha
        let want = (args["project"] as? String)?.trimmingCharacters(in: .whitespaces)
        let chosen = want.flatMap { w -> ProjectReport? in
            let name = (w as NSString).lastPathComponent.lowercased()
            return reports.first { $0.cwd == w || $0.project.lowercased() == w.lowercased() || $0.project.lowercased() == name }
        } ?? reports.max { $0.waste < $1.waste }!
        let total = reports.reduce(0) { $0 + $1.tokens.total }
        func fix(_ f: ProjectIssue.Fix) -> String {
            switch f {
            case .newSession: return "new_session"
            case .claudeRules: return "claude_rules"
            case .connectors: return "connectors"
            case .habit: return "habit"
            }
        }
        var o: [String: Any] = [
            "period": period.rawValue,
            "note": "Waste is an estimate of avoidable tokens: context above 150K re-read on every call, session starts above 80K, repeated reads, large results kept in context. Most of it is cache reads, so estimated_waste_weighted (by price) is much smaller than the raw number. Fixing it doesn't change the model or quality.",
            "projects": reports.map { r -> [String: Any] in
                ["project": r.project, "tokens": r.tokens.total, "share_percent": total > 0 ? Int((Double(r.tokens.total) / Double(total) * 100).rounded()) : 0,
                 "estimated_waste": r.waste, "estimated_waste_weighted": Int(r.waste(.weighted)), "sessions": r.sessions, "prompts": r.prompts, "active": r.active]
            },
        ]
        var p: [String: Any] = [
            "project": chosen.project,
            "tokens": tokens(chosen.tokens),
            "estimated_waste": chosen.waste,
            "estimated_waste_weighted": Int(chosen.waste(.weighted)),
            "waste_share_by_price_percent": Int((chosen.wasteShare(.weighted) * 100).rounded()),
            "issues": chosen.issues.map { i -> [String: Any] in
                ["kind": i.kind.rawValue, "title": i.title, "estimated_waste": i.waste, "estimated_waste_weighted": Int(i.weighted), "sessions": i.sessions,
                 "remedy": i.remedy, "detail": i.detail, "fix": fix(i.fix)]
            },
            "task": ProjectSavings.prompt(for: chosen, period: period),
        ]
        if let cwd = chosen.cwd { p["cwd"] = cwd }
        // Tuzatish qo'llangani belgilanadi — ilova shu sanadan oldingi va keyingi isrofni solishtiradi
        if args["applied"] as? Bool == true {
            ProjectSavingsHistory().markFixed(chosen.project)
            p["fix_recorded"] = true
        }
        if let ba = ProjectSavingsHistory().load().beforeAfter(chosen.project, mode: .weighted) {
            var b: [String: Any] = ["fixed_at": iso(ba.fixedAt)]
            if let v = ba.before { b["waste_share_before_percent"] = Int((v * 100).rounded()) }
            if let v = ba.after { b["waste_share_after_percent"] = Int((v * 100).rounded()) }
            p["last_fix"] = b
        }
        if want != nil, chosen.cwd != want, chosen.project.lowercased() != want?.lowercased(),
           chosen.project.lowercased() != (want.map { ($0 as NSString).lastPathComponent.lowercased() }) {
            p["note"] = "Requested project not found in this period; showing the project with the most waste"
        }
        o["project_report"] = p
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
