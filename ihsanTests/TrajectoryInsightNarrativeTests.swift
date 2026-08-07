import IhsanCore
import Foundation
import Testing
@testable import ihsan

@Suite("Deterministic Path readout")
struct TrajectoryInsightNarrativeTests {
    @Test
    func statesCountsAndKeepsMakeupsSeparate() {
        let perPrayer = Prayer.allCases.map { prayer in
            TrajectoryAggregate.PrayerAggregate(
                prayer: prayer,
                onTimeCount: prayer == .fajr ? 5 : 2,
                lateCount: prayer == .asr ? 2 : 0,
                missedCount: 0,
                qadaCount: prayer == .isha ? 1 : 0,
                totalActiveDays: 7
            )
        }
        let aggregate = TrajectoryAggregate(
            totalActiveDays: 7,
            pausedDays: 1,
            travelingDays: 0,
            totalLogged: 15,
            totalPossible: 35,
            onTimeCount: 13,
            lateCount: 2,
            missedCount: 0,
            qadaCount: 1,
            jamaahCount: 3,
            perPrayer: perPrayer
        )

        let text = TrajectoryInsightNarrative.make(from: aggregate)
        #expect(text.contains("15 of 35"))
        #expect(text.contains("2 delayed within the window"))
        #expect(text.contains("Fajr has the most on-time records (5)"))
        #expect(text.contains("1 later makeup is tracked separately"))
        #expect(!text.localizedCaseInsensitiveContains("score"))
        #expect(!TrajectoryInsightNarrative.isUsefulGeneratedObservation(
            "The user logged a total of eight prayers in this period."
        ))
        #expect(TrajectoryInsightNarrative.isUsefulGeneratedObservation(
            "Fajr was recorded on time more often than the other prayers."
        ))
    }
}
