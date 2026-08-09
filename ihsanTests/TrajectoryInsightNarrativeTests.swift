import IhsanCore
import Foundation
import Testing
@testable import ihsan

/// The line under the finding.
///
/// Its whole job is to say what the counts row above it cannot. These
/// hold it to that: coverage with its denominator, the shape of the
/// week, agreement with the finding about how long the week was, and
/// nothing that merely repeats a number already on screen.
@Suite("Deterministic Path readout")
struct TrajectoryInsightNarrativeTests {

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    private static let now = Date(timeIntervalSince1970: 1_754_654_400)

    private static func day(
        _ daysAgo: Int,
        statuses: [Prayer: PrayerStatus],
        isPaused: Bool = false
    ) -> DayCompletion {
        let date = calendar.date(
            byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now)
        )!
        return DayCompletion(
            id: date,
            date: date,
            prayerCompletions: Prayer.allCases.map {
                PrayerCompletion(prayer: $0, status: statuses[$0], withJamaah: false)
            },
            isPaused: isPaused,
            isTraveling: false
        )
    }

    /// Only the fields this line actually reads.
    private func aggregate(qadaCount: Int = 0, pausedDays: Int = 0) -> TrajectoryAggregate {
        TrajectoryAggregate(
            totalActiveDays: 7,
            pausedDays: pausedDays,
            travelingDays: 0,
            totalLogged: 0,
            totalPossible: 35,
            onTimeCount: 0,
            lateCount: 0,
            missedCount: 0,
            qadaCount: qadaCount,
            jamaahCount: 0,
            perPrayer: []
        )
    }

    private func make(
        days: [DayCompletion],
        qadaCount: Int = 0,
        pausedDays: Int = 0
    ) -> String {
        TrajectoryInsightNarrative.make(
            days: days,
            aggregate: aggregate(qadaCount: qadaCount, pausedDays: pausedDays),
            now: Self.now,
            calendar: Self.calendar
        )
    }

    /// Six elapsed days plus an untouched today. The finding above this
    /// line says "of 6 days"; this one must not say seven, and must not
    /// count today's five not-yet-due slots as unrecorded.
    @Test("Coverage counts elapsed days only, exactly as the finding does")
    func coverageAgreesWithTheFinding() {
        var days = (1...6).map { offset in
            Self.day(offset, statuses: Dictionary(
                uniqueKeysWithValues: Prayer.allCases.map { ($0, PrayerStatus.onTime) }
            ))
        }
        days.append(Self.day(0, statuses: [:]))

        let text = make(days: days)
        #expect(text.contains("30 of 30 slots across 6 elapsed days carry a record."))
        #expect(!text.contains("35"))
        #expect(!text.contains("7 elapsed"))
    }

    @Test("A qadā slot still counts as a slot that carries a record")
    func qadaSlotsCountAsRecorded() {
        let days = (1...4).map { offset in
            Self.day(offset, statuses: [
                .fajr: .qada, .dhuhr: .onTime, .asr: .onTime, .maghrib: .onTime, .isha: .onTime
            ])
        }

        #expect(make(days: days).contains("20 of 20 slots"))
    }

    @Test("The shape names what holds and what moves")
    func namesTheShapeOfTheWeek() {
        let days = (1...7).map { offset in
            Self.day(offset, statuses: [
                .fajr: .onTime,
                .dhuhr: .onTime,
                .maghrib: .onTime,
                .asr: offset <= 2 ? .onTime : .late,
                .isha: offset <= 2 ? .onTime : .missed
            ])
        }

        let text = make(days: days)
        #expect(text.contains("Fajr, Dhuhr, and Maghrib hold their time"))
        #expect(text.contains("Asr and Isha move around"))
    }

    /// The bug that reached a screenshot: "Asr move around."
    @Test("A single prayer takes a singular verb")
    func singleSubjectAgreesInNumber() {
        let days = (1...7).map { offset in
            Self.day(offset, statuses: [
                .fajr: .onTime,
                .dhuhr: .onTime,
                .maghrib: .onTime,
                .isha: .onTime,
                .asr: offset <= 2 ? .onTime : .late
            ])
        }

        let text = make(days: days)
        #expect(text.contains("Asr moves around"))
        #expect(!text.contains("Asr move around"))
    }

    @Test("A single settled prayer keeps its own time")
    func singleHoldingSubjectAgreesInNumber() {
        let days = (1...7).map { offset in
            Self.day(offset, statuses: [.fajr: .onTime])
        }

        let text = make(days: days)
        #expect(text.contains("Fajr holds its time"))
        #expect(text.contains("Dhuhr, Asr, Maghrib, and Isha move around"))
    }

    /// The failure this line was rewritten to avoid: restating totals
    /// the quiet summary row already prints two inches above it.
    @Test("It never re-reads the counts row back to the user")
    func doesNotRestateTheCountsRow() {
        let days = (1...7).map { offset in
            Self.day(offset, statuses: [
                .fajr: .onTime, .dhuhr: .onTime, .maghrib: .onTime,
                .asr: .late, .isha: .missed
            ])
        }

        let text = make(days: days)
        #expect(!text.contains("on time"))
        #expect(!text.contains("delayed within the window"))
        #expect(!text.contains("has the most on-time records"))
        #expect(!text.localizedCaseInsensitiveContains("score"))
    }

    @Test("A uniform period reports no shape rather than inventing one")
    func uniformPeriodHasNoShapeSentence() {
        // Every prayer on time on 3 of 6 days — between the thresholds,
        // so nothing holds and nothing moves.
        let days = (1...6).map { offset in
            Self.day(
                offset,
                statuses: offset <= 3
                    ? Dictionary(uniqueKeysWithValues: Prayer.allCases.map { ($0, PrayerStatus.onTime) })
                    : [:]
            )
        }

        #expect(make(days: days) == "15 of 30 slots across 6 elapsed days carry a record.")
    }

    @Test("Pauses and make-ups are reported without entering the coverage count")
    func pausesAndMakeupsAreReportedSeparately() {
        var days = (1...6).map { offset in
            Self.day(offset, statuses: Dictionary(
                uniqueKeysWithValues: Prayer.allCases.map { ($0, PrayerStatus.onTime) }
            ))
        }
        days.append(Self.day(7, statuses: [:], isPaused: true))

        let text = make(days: days, qadaCount: 1, pausedDays: 1)
        #expect(text.contains("30 of 30 slots across 6 elapsed days"))
        #expect(text.contains("1 later makeup is tracked separately."))
        #expect(text.contains("1 paused day was excluded from these counts."))
    }

    @Test("Model prose that names nothing concrete is refused")
    func generatedObservationsMustNameSomething() {
        #expect(!TrajectoryInsightNarrative.isUsefulGeneratedObservation(
            "The user logged a total of eight prayers in this period."
        ))
        #expect(TrajectoryInsightNarrative.isUsefulGeneratedObservation(
            "Fajr was recorded on time more often than the other prayers."
        ))
    }
}
