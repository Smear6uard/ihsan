import Foundation
import IhsanCore
import Testing
@testable import ihsan

@Suite("Path insight materialization")
struct TrajectoryInsightMaterializerTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(day: Int, hour: Int = 12) -> Date {
        calendar.date(
            from: DateComponents(year: 2026, month: 7, day: day, hour: hour)
        )!
    }

    private func snapshot(period: TrajectoryPeriod = .sevenDays) -> TrajectoryState.Snapshot {
        let days = (1...period.dayCount).map { offset in
            let completions = Prayer.allCases.map { prayer in
                PrayerCompletion(
                    prayer: prayer,
                    status: prayer == .fajr && offset == period.dayCount ? .onTime : nil,
                    withJamaah: prayer == .fajr && offset == period.dayCount
                )
            }
            return DayCompletion(
                id: date(day: offset),
                date: date(day: offset),
                prayerCompletions: completions,
                isPaused: false,
                isTraveling: false
            )
        }
        return .init(
            period: period,
            days: days,
            aggregate: TrajectoryAggregator.aggregate(days: days, qadaLogs: [])
        )
    }

    @Test("Only model-supported Path ranges materialize")
    func supportedRanges() {
        #expect(TrajectoryInsightMaterializer.periodKind(for: .sevenDays) == .week)
        #expect(TrajectoryInsightMaterializer.periodKind(for: .thirtyDays) == .month)
        #expect(TrajectoryInsightMaterializer.periodKind(for: .ninetyDays) == nil)
        #expect(TrajectoryInsightMaterializer.periodKind(for: .year) == nil)
    }

    @Test("The model receives a bounded numeric summary, not raw logs")
    func boundedNumericSummary() throws {
        let inside = DhikrSession(
            sessionDate: date(day: 4), count: 33, phrase: .subhanallah
        )
        let outside = DhikrSession(
            sessionDate: date(day: 20), count: 100, phrase: .alhamdulillah
        )

        let summary = try #require(
            TrajectoryInsightMaterializer.makeSummary(
                snapshot: snapshot(),
                dhikrSessions: [inside, outside],
                calendar: calendar,
                now: date(day: 8)
            )
        )

        #expect(summary.periodKind == .week)
        #expect(summary.expectedPrayerCount == 35)
        #expect(summary.loggedPrayerCount == 1)
        #expect(summary.onTimeCount == 1)
        #expect(summary.jamaahCount == 1)
        #expect(summary.dhikrSessionCount == 1)
        #expect(summary.byPrayer.count == Prayer.allCases.count)
        #expect(summary.byPrayer.first { $0.prayer == .fajr }?.onTime == 1)
    }

    @Test("Cached insight survives presentation-only refreshes and clears on data change")
    func deterministicCacheInvalidation() throws {
        let original = try #require(
            TrajectoryInsightMaterializer.makeSummary(
                snapshot: snapshot(),
                dhikrSessions: [],
                calendar: calendar,
                now: date(day: 8)
            )
        )
        original.aiInsightText = "Fajr was recorded once this week."
        original.aiInsightGeneratedAt = date(day: 8)

        let unchanged = try #require(
            TrajectoryInsightMaterializer.makeSummary(
                snapshot: snapshot(),
                dhikrSessions: [],
                calendar: calendar,
                now: date(day: 9)
            )
        )
        #expect(!TrajectoryInsightMaterializer.refresh(original, from: unchanged))
        #expect(original.aiInsightText != nil)

        let changed = try #require(
            TrajectoryInsightMaterializer.makeSummary(
                snapshot: snapshot(),
                dhikrSessions: [
                    DhikrSession(
                        sessionDate: date(day: 4), count: 33, phrase: .subhanallah
                    )
                ],
                calendar: calendar,
                now: date(day: 9)
            )
        )
        #expect(TrajectoryInsightMaterializer.refresh(original, from: changed))
        #expect(original.aiInsightText == nil)
        #expect(original.aiInsightGeneratedAt == nil)
    }
}
