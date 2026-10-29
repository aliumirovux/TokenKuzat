import Foundation

/// Avtomatik yangi sessiya: kontekst chegaradan oshgan sessiyada Claude javobini tugatgan zahoti
/// xulosa saqlanadi va yangi sessiya ochiladi. Ish o'rtasida hech qachon — faqat ishlayotgan holatdan
/// bo'sh holatga o'tganda; har sessiyada bir marta.
public enum AutoHandoffRule {
    public static let defaultThresholdK: Double = 200
    public static let thresholdOptionsK: [Double] = [150, 200, 300, 500]

    /// Shu yangilanishda yangi sessiya ochilsinmi
    public static func shouldTrigger(previous: AgentState?, state: AgentState, context: Int, thresholdK: Double,
                                     waitingPermission: Bool, alreadyDone: Bool) -> Bool {
        guard !alreadyDone, !waitingPermission, state == .idle else { return false }
        guard let previous, previous != .idle else { return false }
        return Double(context) >= thresholdK * 1000
    }
}

/// Yangi sessiya qayerda ochiladi
public enum AutoHandoffTarget: String, CaseIterable, Identifiable, Sendable {
    case app, terminal
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .app: return tr("Claude ilovasida", "In the Claude app")
        case .terminal: return tr("Terminalda (claude)", "In Terminal (claude)")
        }
    }
}
