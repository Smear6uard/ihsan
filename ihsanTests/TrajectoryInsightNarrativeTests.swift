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

    /// "132 recorded" one line above "129 of 145" is the failure this
    /// line was rewritten to end. The key states the count; a second
    /// count here, on any basis, would be that failure again.
    @Test("It states no coverage figure")
    func statesNoSecondCount() {
        var days = (1...6).map { offset in
            Self.day(offset, statuses: Dictionary(
                uniqueKeysWithValues: Prayer.allCases.map { ($0, PrayerStatus.onTime) }
            ))
        }
        days.append(Self.day(0, statuses: [:]))

        let text = make(days: days)
        #expect(!text.contains("30"))
        #expect(!text.contains("35"))
        #expect(!text.contains(" of "))
    }

    /// The internal words a reader had no way to know.
    @Test("It speaks plainly")
    func usesNoInternalVocabulary() {
        let days = (1...7).map { offset in
            Self.day(offset, statuses: [
                .fajr: .onTime,
                .asr: offset <= 2 ? .onTime : .late
            ])
        }
        let text = make(days: days, qadaCount: 2, pausedDays: 1)
        for word in ["slot", "carry a record", "hold their time", "holds its", "move around", "elapsed"] {
            #expect(!text.contains(word), "\(word) is back in \(text)")
        }
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
        #expect(text.contains("Fajr, Dhuhr, and Maghrib were usually on time"))
        #expect(text.contains("Asr and Isha varied"))
    }

    @Test("A single prayer is named on its own")
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
        #expect(text.contains("Asr varied"))
    }

    @Test("A single steady prayer takes a singular verb")
    func singleHoldingSubjectAgreesInNumber() {
        let days = (1...7).map { offset in
            Self.day(offset, statuses: [.fajr: .onTime])
        }

        let text = make(days: days)
        #expect(text.contains("Fajr was usually on time"))
        #expect(text.contains("Dhuhr, Asr, Maghrib, and Isha varied"))
    }

    @Test("All five are called all five")
    func allFiveAreNotListedOut() {
        let days = (1...7).map { offset in
            Self.day(offset, statuses: Dictionary(
                uniqueKeysWithValues: Prayer.allCases.map { ($0, PrayerStatus.onTime) }
            ))
        }

        #expect(make(days: days) == "All five prayers were usually on time.")
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

        #expect(make(days: days).isEmpty)
    }

    @Test("Pauses and separate make-ups are said in words")
    func pausesAndMakeupsAreReportedSeparately() {
        var days = (1...6).map { offset in
            Self.day(offset, statuses: Dictionary(
                uniqueKeysWithValues: Prayer.allCases.map { ($0, PrayerStatus.onTime) }
            ))
        }
        days.append(Self.day(7, statuses: [:], isPaused: true))

        let text = make(days: days, qadaCount: 1, pausedDays: 1)
        #expect(text.contains("1 earlier prayer was made up in this period."))
        #expect(text.contains("1 paused day isn’t counted."))
    }

    /// A qadā recorded on its own day has a mark, and the key counts it.
    /// Only the make-ups that left their own day's slate alone need
    /// saying, or the same act gets counted out loud twice.
    @Test("A qadā with a mark of its own is not mentioned again")
    func markedQadaIsNotRepeated() {
        let days = (1...6).map { offset in
            Self.day(offset, statuses: [.fajr: offset == 1 ? .qada : .onTime])
        }

        #expect(!make(days: days, qadaCount: 1).contains("made up"))
        #expect(make(days: days, qadaCount: 3).contains("2 earlier prayers were made up"))
    }

    @Test("The days before the record began don't shape the reading")
    func daysBeforeTheRecordAreLeftOut() {
        let days = (1...7).map { offset in
            Self.day(offset, statuses: offset <= 3 ? [.fajr: .onTime] : [:])
        }
        let began = Self.calendar.date(
            byAdding: .day, value: -3, to: Self.calendar.startOfDay(for: Self.now)
        )

        let text = TrajectoryInsightNarrative.make(
            days: days,
            aggregate: aggregate(),
            now: Self.now,
            recordBegan: began,
            calendar: Self.calendar
        )
        #expect(text.contains("Fajr was usually on time"))
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
