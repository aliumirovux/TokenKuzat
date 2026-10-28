import Foundation
import TokenKuzatCore

/// Xaritadan Claude Code sessiyasiga xabar yuborish: `claude -p --resume <id> --permission-mode auto`.
///
/// Javob alohida ko'rsatilmaydi — Claude uni sessiya transkriptiga yozadi va xarita (robot, qadamlar, kartalar)
/// uni o'zi chizadi. Model sessiyadagi bilan bir xil oiladan (Opus → opus), kontekst — o'sha sessiyaniki.
@MainActor
final class MapChat: ObservableObject {
    static let shared = MapChat()

    enum Phase: Equatable {
        case idle
        case running(since: Date)
        case failed(String)
    }

    @Published private(set) var phases: [String: Phase] = [:]
    /// Claude ilovasi yoki terminalda ochiq turgan sessiyalar (boshqa `claude --resume <id>` jarayoni bor)
    @Published private(set) var openElsewhere: Set<String> = []
    private var procs: [String: Process] = [:]

    func phase(_ sid: String) -> Phase { phases[sid] ?? .idle }

    var isRunningAny: Bool { !procs.isEmpty }

    // MARK: Yuborish

    func send(_ text: String, to s: SessionSnap) {
        let msg = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !msg.isEmpty, procs[s.id] == nil else { return }
        guard let exe = Self.claudePath() else {
            phases[s.id] = .failed("Claude Code (claude) topilmadi — terminalda o'rnatilganini tekshiring")
            return
        }
        guard let cwd = s.cwd, FileManager.default.fileExists(atPath: cwd) else {
            phases[s.id] = .failed("Sessiya papkasi topilmadi — sessiya o'chirilgan bo'lishi mumkin")
            return
        }

        let p = Process()
        p.executableURL = URL(fileURLWithPath: exe)
        var args = ["-p", "--resume", s.id, "--permission-mode", "auto", "--output-format", "stream-json", "--verbose"]
        if let m = Self.modelAlias(s.model) { args += ["--model", m] }
        p.arguments = args
        p.currentDirectoryURL = URL(fileURLWithPath: cwd)
        var env = ProcessInfo.processInfo.environment
        let extra = ["/usr/local/bin", "/opt/homebrew/bin", NSHomeDirectory() + "/.local/bin", "/usr/bin", "/bin"]
        env["PATH"] = (extra + [env["PATH"] ?? ""]).joined(separator: ":")
        p.environment = env

        let stdin = Pipe(), stdout = Pipe(), stderr = Pipe()
        p.standardInput = stdin
        p.standardOutput = stdout
        p.standardError = stderr

        // Oxirgi «result» hodisasi va stderr — xato bo'lsa ko'rsatish uchun
        let collector = OutputCollector()
        stdout.fileHandleForReading.readabilityHandler = { h in collector.add(h.availableData) }
        stderr.fileHandleForReading.readabilityHandler = { h in collector.addError(h.availableData) }

        let sid = s.id
        p.terminationHandler = { proc in
            stdout.fileHandleForReading.readabilityHandler = nil
            stderr.fileHandleForReading.readabilityHandler = nil
            let status = proc.terminationStatus, reason = proc.terminationReason
            let err = collector.failure(useStderr: proc.terminationStatus != 0)
            Task { @MainActor in
                let me = MapChat.shared
                me.procs[sid] = nil
                if reason == .uncaughtSignal || status == 130 || status == 143 {
                    me.phases[sid] = .idle          // foydalanuvchi to'xtatdi
                } else if let err {
                    me.phases[sid] = .failed(err)
                } else if status != 0 {
                    me.phases[sid] = .failed("Claude Code xato bilan tugadi (kod \(status))")
                } else {
                    me.phases[sid] = .idle
                }
            }
        }

        do {
            try p.run()
        } catch {
            phases[s.id] = .failed("Ishga tushmadi: \(error.localizedDescription)")
            return
        }
        // Xabar stdin orqali — «-» bilan boshlansa ham bayroq deb o'qilmaydi
        stdin.fileHandleForWriting.write(Data(msg.utf8))
        try? stdin.fileHandleForWriting.close()
        procs[s.id] = p
        phases[s.id] = .running(since: Date())
    }

    /// Ctrl-C kabi: Claude Code joriy ishni to'xtatadi va sessiyani saqlaydi
    func stop(_ sid: String) {
        procs[sid]?.interrupt()
    }

    func dismissError(_ sid: String) {
        if case .failed = phase(sid) { phases[sid] = .idle }
    }

    // MARK: Yordamchilar

    /// Sessiya boshqa joyda (Claude ilovasi, terminal) ochiqmi — u yerda bu xabarlar darhol ko'rinmaydi
    func refreshOpenElsewhere(_ sid: String) async {
        let ours = procs[sid]?.processIdentifier
        let found = await Task.detached { () -> Bool in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/ps")
            p.arguments = ["-axo", "pid=,command="]
            let out = Pipe()
            p.standardOutput = out
            p.standardError = FileHandle.nullDevice
            guard (try? p.run()) != nil else { return false }
            let data = out.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            return String(decoding: data, as: UTF8.self).split(separator: "\n").contains { line in
                let l = line.trimmingCharacters(in: .whitespaces)
                guard l.contains("--resume=\(sid)") || l.contains("--resume \(sid)") else { return false }
                return Int32(l.split(separator: " ").first ?? "") != ours
            }
        }.value
        if found { openElsewhere.insert(sid) } else { openElsewhere.remove(sid) }
    }

    static func modelAlias(_ model: String) -> String? {
        let m = model.lowercased()
        for alias in ["opus", "sonnet", "haiku"] where m.contains(alias) { return alias }
        return nil
    }

    private static var cachedPath: String??
    static func claudePath() -> String? {
        if let c = cachedPath { return c }
        let home = NSHomeDirectory()
        let candidates = ["/usr/local/bin/claude", "/opt/homebrew/bin/claude", home + "/.local/bin/claude",
                          home + "/.claude/local/claude", home + "/.npm-global/bin/claude"]
        var found = candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
        if found == nil {
            // Ilova Finder'dan ochilganda PATH qisqa — login shell orqali qidiriladi
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/zsh")
            p.arguments = ["-lc", "command -v claude"]
            let out = Pipe()
            p.standardOutput = out
            p.standardError = FileHandle.nullDevice
            if (try? p.run()) != nil {
                p.waitUntilExit()
                let s = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !s.isEmpty, FileManager.default.isExecutableFile(atPath: s) { found = s }
            }
        }
        cachedPath = .some(found)
        return found
    }
}

/// stream-json chiqishidan faqat yakuniy natija va xato matni olinadi (javob transkriptdan o'qiladi)
private final class OutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()
    private var resultError: String?
    private var errText = ""

    func add(_ d: Data) {
        guard !d.isEmpty else { return }
        lock.lock(); defer { lock.unlock() }
        buffer.append(d)
        while let nl = buffer.firstIndex(of: 0x0A) {
            let line = buffer.subdata(in: buffer.startIndex..<nl)
            buffer.removeSubrange(buffer.startIndex...nl)
            guard let o = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any],
                  o["type"] as? String == "result" else { continue }
            if (o["is_error"] as? Bool) == true {
                resultError = (o["result"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? (o["subtype"] as? String ?? "xato")
            }
        }
    }

    func addError(_ d: Data) {
        guard !d.isEmpty else { return }
        lock.lock(); defer { lock.unlock() }
        errText += String(decoding: d, as: UTF8.self)
        if errText.count > 4000 { errText = String(errText.suffix(2000)) }
    }

    /// stderr faqat jarayon xato kod bilan tugaganda hisobga olinadi — muvaffaqiyatda ogohlantirishlar bo'lishi mumkin
    func failure(useStderr: Bool) -> String? {
        lock.lock(); defer { lock.unlock() }
        if let r = resultError { return String(r.prefix(300)) }
        guard useStderr else { return nil }
        let e = errText.trimmingCharacters(in: .whitespacesAndNewlines)
        return e.isEmpty ? nil : String(e.split(separator: "\n").last.map(String.init)?.prefix(300) ?? "")
    }
}
