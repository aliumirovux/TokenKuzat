import Foundation

// Claude Code suhbatni qaysi kontekstda o'zi qisqartirishi: settings.json dagi `autoCompactWindow`
// (100000–1000000 yoki "auto"), model bo'yicha `modelSettings.<model>.autoCompactWindow` va
// CLAUDE_CODE_AUTO_COMPACT_WINDOW muhit o'zgaruvchisi. "auto" — model uchun moslangan oyna, aniq son emas.
// Qisqartirish ko'chirish chegarasidan oldin bo'lsa — Sozlamalarda ogohlantiriladi.

public enum AutoCompactWindow {
    public static let range = 100_000...1_000_000
    public static let envKey = "CLAUDE_CODE_AUTO_COMPACT_WINDOW"

    public struct Found: Equatable, Sendable {
        public let tokens: Int
        /// Qayerdan: autoCompactWindow, modelSettings.<model>, CLAUDE_CODE_AUTO_COMPACT_WINDOW
        public let source: String
    }

    /// Aniq berilgan oynalarning eng kichigi (qaysi model ishlatilishi oldindan noma'lum). Hech biri bo'lmasa — nil
    public static func smallest(settings: [String: Any], env: [String: String] = ProcessInfo.processInfo.environment) -> Found? {
        var all: [Found] = []
        // Muhit o'zgaruvchisi settings.json dagi «env» bo'limida ham berilishi mumkin
        let fromSettings = (settings["env"] as? [String: Any])?[envKey]
        if let v = value(env[envKey]) ?? value(fromSettings) { all.append(Found(tokens: v, source: envKey)) }
        if let v = value(settings["autoCompactWindow"]) { all.append(Found(tokens: v, source: "autoCompactWindow")) }
        for (model, o) in (settings["modelSettings"] as? [String: Any] ?? [:]).sorted(by: { $0.key < $1.key }) {
            if let v = value((o as? [String: Any])?["autoCompactWindow"]) {
                all.append(Found(tokens: v, source: "modelSettings.\(model)"))
            }
        }
        return all.min { $0.tokens < $1.tokens }
    }

    static func value(_ v: Any?) -> Int? {
        guard let n = (v as? NSNumber)?.intValue ?? (v as? String).flatMap({ Int($0) }), range.contains(n) else { return nil }
        return n
    }
}
