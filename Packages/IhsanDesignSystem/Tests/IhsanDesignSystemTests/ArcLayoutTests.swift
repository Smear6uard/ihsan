import CoreGraphics
import Foundation
import Testing
@testable import IhsanDesignSystem

/// The strip's spacing contract: positions are time-true until two
/// marks would fuse, then they yield exactly enough to stay two
/// marks — and the crowded evening pair's labels drop to the second
/// tier instead of colliding.
struct ArcLayoutTests {

    private func chicago(_ hour: Int, _ minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        let day = calendar.date(from: DateComponents(year: 2026, month: 7, day: 30))!
        return calendar.date(byAdding: DateComponents(hour: hour, minute: minute), to: day)!
    }

    /// The canonical summer day: Maghrib and Isha 92 minutes apart in
    /// a 17.5-hour span — ~8.8% of the arc, under a 24 pt ornament's
    /// footprint on a medium strip.
    private var summerTimes: [Date] {
        [
            chicago(4, 10), chicago(12, 58), chicago(16, 53),
            chicago(20, 11), chicago(21, 43),
        ]
    }

    @Test
    func uncrowdedFractionsStayTimeTrue() {
        let times = summerTimes
        let fractions = ArcLayout.fractions(times: times, span: times[0]...times[4])
        #expect(fractions[0] == 0)
        #expect(fractions[4] == 1)
        // Dhuhr at 12:58 across 4:10→21:43 is 50.17% of the day.
        #expect(abs(fractions[1] - 0.5017) < 0.001)
        // No separation needed at a generous gap of 2%.
        #expect(ArcLayout.separated(fractions, minimumGap: 0.02) == fractions)
    }

    @Test
    func crowdedEveningSeparatesWithoutLeavingTheSpan() {
        let times = summerTimes
        let fractions = ArcLayout.fractions(times: times, span: times[0]...times[4])
        // A 24 pt ornament on a ~272 pt arc: gap ≈ 9.6%.
        let separated = ArcLayout.separated(fractions, minimumGap: 0.096)

        for (a, b) in zip(separated, separated.dropFirst()) {
            #expect(b - a >= 0.0959, "marks fused: \(a) → \(b)")
        }
        #expect(separated.first! >= 0)
        #expect(separated.last! <= 1)
        // The early day barely moves — separation is local to the crowd.
        #expect(abs(separated[0] - fractions[0]) < 0.001)
        #expect(abs(separated[1] - fractions[1]) < 0.001)
    }

    @Test
    func impossibleGapDegradesToEvenSpacing() {
        let times = summerTimes
        let fractions = ArcLayout.fractions(times: times, span: times[0]...times[4])
        // Five marks cannot all keep 40% gaps in a unit span; the
        // layout degrades to the widest gap that fits (25%).
        let separated = ArcLayout.separated(fractions, minimumGap: 0.4)
        for (a, b) in zip(separated, separated.dropFirst()) {
            #expect(b - a >= 0.249)
        }
        #expect(separated.first! >= 0)
        #expect(separated.last! <= 1)
    }

    @Test
    func crowdedLabelsAlternateTiers() {
        let centers = [
            CGPoint(x: 30, y: 0), CGPoint(x: 150, y: 0), CGPoint(x: 200, y: 0),
            CGPoint(x: 240, y: 0), CGPoint(x: 268, y: 0),
        ]
        let tiers = DayStripFace.labelTiers(centers: centers, labelWidth: 56)
        #expect(tiers[0] == 0)
        #expect(tiers[1] == 0)
        // 150→200 is under a label width: the second drops.
        #expect(tiers[2] == 1)
        // 200→240 under width but the left neighbour already dropped.
        #expect(tiers[3] == 0)
        #expect(tiers[4] == 1)
    }
}
