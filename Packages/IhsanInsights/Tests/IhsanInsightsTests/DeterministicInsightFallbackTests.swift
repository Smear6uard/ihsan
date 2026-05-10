import Foundation
import IhsanCore
import Testing
@testable import IhsanInsights

@Test
func deterministicFallbackProducesValidInsightFromNumericPeriodSummary() {
    let summary = makeSummary()

    let insight = DeterministicInsightFallback.monthly(from: summary)

    #expect(insight.summarySentence == "Asr was prayed on time on 22 of 30 days. Fajr was prayed on time on 14 of 30 days. 2 prayers made up as qada. 3 days traveling.")
    #expect(insight.mostConsistentPrayer == "Asr")
    #expect(insight.leastConsistentPrayer == "Fajr")
    #expect(insight.notableObservation == "2 prayers made up as qada.")
    #expect(InsightContentFilter.accepts(insight))
}

@Test
func deterministicFallbackHandlesEmptyStats() {
    let summary = PeriodSummary(
        periodKind: .week,
        periodStart: Date(timeIntervalSince1970: 0),
        periodEnd: Date(timeIntervalSince1970: 604_800),
        loggedTimeZoneIdentifier: "America/Chicago"
    )

    let insight = DeterministicInsightFallback.weekly(from: summary)

    #expect(insight.summarySentence == "No prayer activity was logged for this period.")
    #expect(insight.mostConsistentPrayer == "None")
    #expect(insight.leastConsistentPrayer == "None")
    #expect(InsightContentFilter.accepts(insight))
}

private func makeSummary() -> PeriodSummary {
    PeriodSummary(
        periodKind: .month,
        periodStart: Date(timeIntervalSince1970: 0),
        periodEnd: Date(timeIntervalSince1970: 2_592_000),
        loggedTimeZoneIdentifier: "America/Chicago",
        expectedPrayerCount: 150,
        loggedPrayerCount: 131,
        onTimeCount: 93,
        lateCount: 31,
        missedCount: 26,
        qadaLoggedCount: 2,
        jamaahCount: 12,
        pausedDayCount: 0,
        traveledDayCount: 3,
        byPrayer: [
            ByPrayerStat(prayer: .fajr, expected: 30, logged: 24, onTime: 14, late: 6, missed: 6, jamaah: 0),
            ByPrayerStat(prayer: .dhuhr, expected: 30, logged: 27, onTime: 17, late: 7, missed: 3, jamaah: 3),
            ByPrayerStat(prayer: .asr, expected: 30, logged: 29, onTime: 22, late: 5, missed: 1, jamaah: 2),
            ByPrayerStat(prayer: .maghrib, expected: 30, logged: 26, onTime: 18, late: 6, missed: 4, jamaah: 4),
            ByPrayerStat(prayer: .isha, expected: 30, logged: 25, onTime: 22, late: 7, missed: 5, jamaah: 3)
        ]
    )
}
