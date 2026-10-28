import XCTest
@testable import TokenKuzatCore

final class OutsideUsageTests: XCTestCase {
    /// Daqiqa boshiga to'g'ri keladigan vaqt
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000 - 1_800_000_000.truncatingRemainder(dividingBy: 60))

    private var resets: Date { t0.addingTimeInterval(4 * 3600) }

    private func at(_ min: Double) -> Date { t0.addingTimeInterval(min * 60) }

    /// Daqiqalar: [daqiqa: vaznli token]
    private func minutes(_ m: [Int: Double]) -> [MinutePoint] {
        (-60...300).map { i in
            MinutePoint(id: i, date: at(Double(i)), main: TokenCounts(weighted: m[i] ?? 0), agents: TokenCounts())
        }
    }

    private func w(_ pct: Double) -> LimitWindow { LimitWindow(usedPercentage: pct, resetsAt: resets) }

    func testFirstObservationIsUnobserved() {
        let tr = OutsideUsageTracker(url: nil)
        tr.observe(w(12), at: at(0), minutes: minutes([:]))
        let s = tr.summary(now: at(1))
        XCTAssertEqual(s.unobservedPct, 12)
        XCTAssertEqual(s.observedPct, 0)
        XCTAssertTrue(s.hasWindow)
    }

    func testGrowthWithoutMacActivityIsOutside() {
        let tr = OutsideUsageTracker(url: nil)
        tr.observe(w(10), at: at(0), minutes: minutes([:]))
        tr.observe(w(13), at: at(2), minutes: minutes([:]))
        let s = tr.summary(now: at(3))
        XCTAssertEqual(s.outsidePct, 3, accuracy: 1e-9)
        XCTAssertEqual(s.macPct, 0)
        XCTAssertEqual(s.uncertainPct, 0)
    }

    func testMixedGrowthIsUncertainUntilCalibrated() {
        let tr = OutsideUsageTracker(url: nil)
        tr.observe(w(10), at: at(0), minutes: minutes([:]))
        tr.observe(w(11), at: at(2), minutes: minutes([0: 1000]))
        let s = tr.summary(now: at(3))
        XCTAssertFalse(s.calibrated)
        XCTAssertEqual(s.uncertainPct, 1, accuracy: 1e-9)
    }

    /// Butun foizlar: o'zgarmagan o'lchovlardagi Mac sarfi keyingi o'sishgacha yig'iladi
    func testPendingLocalCarriesAcrossFlatSamples() {
        let tr = OutsideUsageTracker(url: nil)
        let m = minutes([0: 400, 2: 300, 4: 300])
        tr.observe(w(10), at: at(0), minutes: m)
        tr.observe(w(10), at: at(2), minutes: m)
        tr.observe(w(10), at: at(4), minutes: m)
        tr.observe(w(11), at: at(6), minutes: m)
        XCTAssertEqual(tr.state.pairs.count, 1)
        XCTAssertEqual(tr.state.pairs[0].local, 1000)
        XCTAssertEqual(tr.state.pairs[0].d, 1)
    }

    func testCalibratedSplit() {
        let tr = OutsideUsageTracker(url: nil)
        // Faqat Mac: 1% = 1000 vaznli token (3 marta), keyin aralash: 1000 token, lekin +3%
        var m: [Int: Double] = [:]
        for i in [0, 2, 4, 6] { m[i] = 1000 }
        let mm = minutes(m)
        tr.observe(w(10), at: at(0), minutes: mm)
        tr.observe(w(11), at: at(2), minutes: mm)
        tr.observe(w(12), at: at(4), minutes: mm)
        tr.observe(w(13), at: at(6), minutes: mm)
        tr.observe(w(16), at: at(8), minutes: mm)
        let s = tr.summary(now: at(9))
        XCTAssertEqual(s.tokensPerPct ?? 0, 1000, accuracy: 1e-9)
        XCTAssertEqual(s.macPct, 4, accuracy: 1e-9)
        XCTAssertEqual(s.outsidePct, 2, accuracy: 1e-9)
        XCTAssertEqual(s.unobservedPct, 10)
        XCTAssertEqual(s.observedPct + s.unobservedPct, 16, accuracy: 1e-9)
        XCTAssertEqual(s.outsideTodayTokens ?? 0, s.outsideTodayPct * 1000, accuracy: 1e-9)
    }

    /// Chat bilan aralash juftlar k ni pastga tortmasin — yuqori chorak olinadi
    func testCalibrationIgnoresMixedLowRatios() {
        let tr = OutsideUsageTracker(url: nil)
        var m: [Int: Double] = [:]
        for i in stride(from: 0, through: 20, by: 2) { m[i] = 1000 }
        let mm = minutes(m)
        tr.observe(w(0.5), at: at(0), minutes: mm)
        // 6 ta faqat-Mac (+1%) va 2 ta aralash (+4%)
        var pct = 0.5
        for (i, d) in [1.0, 1, 4, 1, 1, 4, 1, 1].enumerated() {
            pct += d
            tr.observe(w(pct), at: at(Double((i + 1) * 2)), minutes: mm)
        }
        XCTAssertEqual(tr.summary(now: at(30)).tokensPerPct ?? 0, 1000, accuracy: 1e-9)
    }

    func testNewWindowAfterResetDuringObservation() {
        let tr = OutsideUsageTracker(url: nil)
        tr.observe(w(80), at: at(0), minutes: minutes([:]))
        // Oyna tugadi, yangisi chat bilan boshlandi, 2 daqiqadan keyin o'lchov
        let next = LimitWindow(usedPercentage: 2, resetsAt: at(2 + 5 * 60 - 1))
        tr.observe(next, at: at(2), minutes: minutes([:]))
        let s = tr.summary(now: at(3))
        XCTAssertEqual(s.unobservedPct, 0)
        XCTAssertEqual(s.outsidePct, 2, accuracy: 1e-9)
    }

    func testNewWindowAfterLongGapIsUnobserved() {
        let tr = OutsideUsageTracker(url: nil)
        tr.observe(w(80), at: at(0), minutes: minutes([:]))
        let next = LimitWindow(usedPercentage: 7, resetsAt: at(300 + 4 * 60))
        tr.observe(next, at: at(300), minutes: minutes([:]))
        let s = tr.summary(now: at(301))
        XCTAssertEqual(s.unobservedPct, 7)
        XCTAssertEqual(s.observedPct, 0)
    }

    func testStaleAndRepeatedSamplesIgnored() {
        let tr = OutsideUsageTracker(url: nil)
        XCTAssertTrue(tr.observe(w(10), at: at(2), minutes: minutes([:])))
        XCTAssertFalse(tr.observe(w(12), at: at(2), minutes: minutes([:])))
        XCTAssertFalse(tr.observe(w(12), at: at(1), minutes: minutes([:])))
        XCTAssertEqual(tr.summary(now: at(3)).observedPct, 0)
    }

    func testPersistence() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("outside-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let a = OutsideUsageTracker(url: url)
        a.observe(w(10), at: at(0), minutes: minutes([:]))
        a.observe(w(14), at: at(2), minutes: minutes([:]))
        let b = OutsideUsageTracker(url: url)
        XCTAssertEqual(b.state, a.state)
        XCTAssertEqual(b.summary(now: at(3)).outsidePct, 4, accuracy: 1e-9)
    }

    func testExpiredWindowHasNoWindowButKeepsToday() {
        let tr = OutsideUsageTracker(url: nil)
        tr.observe(w(10), at: at(0), minutes: minutes([:]))
        tr.observe(w(13), at: at(2), minutes: minutes([:]))
        let later = resets.addingTimeInterval(60)
        let s = tr.summary(now: later)
        XCTAssertFalse(s.hasWindow)
        if Calendar.current.isDate(later, inSameDayAs: at(2)) {
            XCTAssertEqual(s.outsideTodayPct, 3, accuracy: 1e-9)
        }
    }

    func testSegmentsSpanFromPreviousRecordAndFeedLivePage() {
        let tr = OutsideUsageTracker(url: nil)
        tr.observe(w(10), at: at(0), minutes: minutes([:]))
        tr.observe(w(10), at: at(2), minutes: minutes([:]))
        tr.observe(w(12), at: at(4), minutes: minutes([:]))
        tr.observe(w(15), at: at(10), minutes: minutes([:]))
        let s = tr.summary(now: at(11))
        XCTAssertEqual(s.segments.count, 2)
        XCTAssertEqual(s.segments.first?.start, at(0))
        XCTAssertEqual(s.segments.first?.end, at(4))
        XCTAssertEqual(s.segments.last?.start, at(4))
        XCTAssertEqual(s.segments.map(\.percent), [2, 3])
        XCTAssertTrue(s.isActive(now: at(11)))
        XCTAssertFalse(s.isActive(now: at(40)))
        XCTAssertEqual(s.percent(within: 7 * 60, now: at(11)), 3, accuracy: 1e-9)
    }
}
