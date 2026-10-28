import Foundation

/// Tokenlarni qanday sanash: hammasi teng yoki taxminiy narx bo'yicha.
public enum CountMode: String, CaseIterable, Codable, Sendable {
    case raw
    case weighted

    public var title: String {
        switch self {
        case .raw: return tr("Xom", "Raw")
        case .weighted: return tr("Vaznli", "Weighted")
        }
    }
}

/// Bitta API javobining (yoki yig'indining) token tarkibi.
public struct TokenCounts: Equatable, Codable, Sendable {
    public var input = 0
    public var output = 0
    /// `output` ichidagi fikrlash qismi (transcript bersa)
    public var thinking = 0
    public var cacheWrite = 0
    public var cacheRead = 0
    /// Taxminiy narx vazni — `Pricing` bo'yicha
    public var weighted: Double = 0

    public init(input: Int = 0, output: Int = 0, thinking: Int = 0,
                cacheWrite: Int = 0, cacheRead: Int = 0, weighted: Double = 0) {
        self.input = input
        self.output = output
        self.thinking = thinking
        self.cacheWrite = cacheWrite
        self.cacheRead = cacheRead
        self.weighted = weighted
    }

    public var total: Int { input + output + cacheWrite + cacheRead }
    public var isEmpty: Bool { total == 0 }

    public func value(_ mode: CountMode) -> Double {
        mode == .weighted ? weighted : Double(total)
    }

    public mutating func add(_ o: TokenCounts) {
        input += o.input
        output += o.output
        thinking += o.thinking
        cacheWrite += o.cacheWrite
        cacheRead += o.cacheRead
        weighted += o.weighted
    }

    public static func + (a: TokenCounts, b: TokenCounts) -> TokenCounts {
        var r = a
        r.add(b)
        return r
    }
}

/// Narx nisbatlari (kiritish = 1). Anthropic narxlari modeldan qat'i nazar shu nisbatda.
public enum Pricing {
    public static let output = 5.0
    public static let cacheRead = 0.1
    public static let cacheWrite5m = 1.25
    public static let cacheWrite1h = 2.0

    /// Kesh yozish turi berilmasa — 5 daqiqalik deb olinadi.
    public static func weigh(input: Int, output: Int, cacheRead: Int, cacheWrite: Int,
                             write1h: Int = 0, write5m: Int = 0) -> Double {
        let cw = (write1h + write5m) > 0
            ? Double(write1h) * cacheWrite1h + Double(write5m) * cacheWrite5m
            : Double(cacheWrite) * cacheWrite5m
        return Double(input) + Double(output) * Self.output + cw + Double(cacheRead) * Self.cacheRead
    }
}
