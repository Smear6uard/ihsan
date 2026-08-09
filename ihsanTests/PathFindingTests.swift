import Foundation
import IhsanCore
import IhsanFiqhConfig
import Testing
@testable import ihsan

/// The Path card's finding engine.
///
/// The card is blunt on purpose, which raises the cost of being wrong:
/// a confident sentence naming the wrong prayer is worse than the
/// vague one it replaced. These pin the arithmetic behind every
/// sentence it can say.
@Suite("Path finding")
struct PathFindingTests {

    // MARK: - Fixtures

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    /// Noon on a fixed day, so "today" never drifts with the wall clock.
    private static let now = Date(timeIntervalSince1970: 1_754_654_400)

    private static var today: Date { calendar.startOfDay(for: now) }

    private static func day(
        _ daysAgo: Int,
        statuses: [Prayer: PrayerStatus],
        jamaah: Set<Prayer> = [],
        isPaused: Bool = false
    ) -> DayCompletion {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
        return DayCompletion(
            id: date,
            date: date,
            prayerCompletions: Prayer.allCases.map {
                PrayerCompletion(
                    prayer: $0,
                    status: statuses[$0],
                    withJamaah: jamaah.contains($0)
                )
            },
            isPaused: isPaused,
            isTraveling: false
        )
    }

    /// A full week of on-time days, which every reading below perturbs.
    ///
    /// Built oldest-first, because that is the order `TrajectoryAggregator`
    /// produces and a fixture in the opposite order would exercise a
    /// window the app never passes.
    private static func steadyWeek(
        onTime: Set<Prayer> = Set(Prayer.allCases),
        jamaah: Set<Prayer> = [],
        overrides: [Int: [Prayer: PrayerStatus]] = [:],
        paused: Set<Int> = []
    ) -> [DayCompletion] {
        (1...7).reversed().map { offset in
            day(
                offset,
                statuses: overrides[offset]
                    ?? Dictionary(uniqueKeysWithValues: onTime.map { ($0, PrayerStatus.onTime) }),
                jamaah: jamaah,
                isPaused: paused.contains(offset)
            )
        }
    }

    private static func aggregate(
        from days: [DayCompletion],
        qadaCount: Int = 0
    ) -> TrajectoryAggregate {
        let active = days.filter { !$0.isPaused }
        var onTime = 0, late = 0, missed = 0, jamaah = 0
        for day in active {
            for completion in day.prayerCompletions {
                switch completion.status {
                case .onTime: onTime += 1
                case .late: late += 1
                case .missed: missed += 1
                case .qada, .none: break
                }
                if completion.withJamaah, completion.status != nil { jamaah += 1 }
            }
        }
        let perPrayer = Prayer.allCases.map { prayer in
            let stats = active.compactMap { day in
                day.prayerCompletions.first { $0.prayer == prayer }?.status
            }
            return TrajectoryAggregate.PrayerAggregate(
                prayer: prayer,
                onTimeCount: stats.filter { $0 == .onTime }.count,
                lateCount: stats.filter { $0 == .late }.count,
                missedCount: stats.filter { $0 == .missed }.count,
                qadaCount: 0,
                totalActiveDays: active.count
            )
        }
        return TrajectoryAggregate(
            totalActiveDays: active.count,
            pausedDays: days.count - active.count,
            travelingDays: 0,
            totalLogged: onTime + late + missed,
            totalPossible: active.count * 5,
            onTimeCount: onTime,
            lateCount: late,
            missedCount: missed,
            qadaCount: qadaCount,
            jamaahCount: jamaah,
            perPrayer: perPrayer
        )
    }

    private static func log(
        _ prayer: Prayer,
        daysAgo: Int,
        status: PrayerStatus,
        id: UUID = UUID(),
        qadaFor: UUID? = nil
    ) -> PrayerLog {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
        return PrayerLog(
            id: id,
            prayer: prayer,
            prayerDate: date,
            loggedTimeZoneIdentifier: "UTC",
            scheduledTime: date,
            status: status,
            qadaForPrayerLogID: qadaFor
        )
    }

    private static let allRemindersOn = Prayer.allCases.map {
        PathReminderSetting(prayer: $0, isEnabled: true)
    }
    private static let allRemindersOff = Prayer.allCases.map {
        PathReminderSetting(prayer: $0, isEnabled: false)
    }

    private static func make(
        days: [DayCompletion],
        logs: [PrayerLog] = [],
        qadaCount: Int = 0,
        reminders: [PathReminderSetting] = allRemindersOn
    ) -> PathFinding {
        PathFinding.make(
            days: days,
            aggregate: aggregate(from: days, qadaCount: qadaCount),
            logs: logs,
            reminders: reminders,
            now: now,
            calendar: calendar
        )
    }

    // MARK: - Coverage outranks everything

    @Test("A mostly empty ledger reports its gaps, not a diagnosis")
    func gapsOutrankEveryOtherReading() {
        // Only Fajr recorded: 7 of 35 slots, so 28 are empty.
        let days = Self.steadyWeek(onTime: [.fajr])
        let finding = Self.make(days: days)

        #expect(finding.kind == .unrecordedSlots)
        #expect(finding.headline.contains("28 of the last 35 slots"))
        #expect(finding.headline.contains("7 that do"))
    }

    @Test("The offered slot is the most recent gap, at its first prayer")
    func gapActionTargetsTheMostRecentSlot() {
        let days = Self.steadyWeek(onTime: [.fajr])
        let finding = Self.make(days: days)

        // Yesterday is the most recent elapsed day; Fajr is recorded
        // there, so Dhuhr is the day's first gap.
        let yesterday = Self.calendar.date(byAdding: .day, value: -1, to: Self.today)!
        #expect(finding.action == .logSlot(day: yesterday, prayer: .dhuhr))
        #expect(finding.actionTitle?.contains("Dhuhr") == true)
    }

    @Test("Exactly half the slots empty is not yet a gap finding")
    func coverageFloorIsStrict() {
        // Four days, twenty slots, ten recorded — the boundary itself,
        // which the reading requires to be strictly crossed.
        let days = [
            Self.day(4, statuses: [.fajr: .onTime, .dhuhr: .onTime, .asr: .onTime]),
            Self.day(3, statuses: [.fajr: .onTime, .dhuhr: .onTime, .asr: .onTime]),
            Self.day(2, statuses: [.fajr: .onTime, .dhuhr: .onTime]),
            Self.day(1, statuses: [.fajr: .onTime, .dhuhr: .onTime]),
        ]

        #expect(Self.make(days: days).kind != .unrecordedSlots)
    }

    /// The proof is the denominator. Three elapsed days hold seven of
    /// fifteen slots empty, which is under the floor; folding today's
    /// five untouched slots in would take it to twelve of twenty and
    /// trip the reading every morning before Fajr.
    @Test("Today's not-yet-due prayers are never counted as gaps")
    func todayIsExcludedFromCoverage() {
        let days = [
            Self.day(3, statuses: [.fajr: .onTime, .dhuhr: .onTime, .asr: .onTime]),
            Self.day(2, statuses: [.fajr: .onTime, .dhuhr: .onTime, .asr: .onTime]),
            Self.day(1, statuses: [.fajr: .onTime, .dhuhr: .onTime]),
            Self.day(0, statuses: [:]),
        ]

        let finding = Self.make(days: days)
        #expect(finding.kind != .unrecordedSlots)
        #expect(finding.headline.contains("of 3 days"), "today leaked into the denominator")
    }

    @Test("Paused days contribute neither slots nor gaps")
    func pausedDaysAreInvisible() {
        let days = Self.steadyWeek(overrides: [1: [:]], paused: [1])

        let finding = Self.make(days: days)
        #expect(finding.kind != .unrecordedSlots)
        #expect(!finding.headline.localizedCaseInsensitiveContains("pause"))
    }

    // MARK: - Outstanding make-ups

    @Test("A missed prayer with no linked make-up is still owed")
    func outstandingMakeupIsReported() {
        let days = Self.steadyWeek(overrides: [2: [
            .fajr: .missed, .dhuhr: .onTime, .asr: .onTime, .maghrib: .onTime, .isha: .onTime
        ]])
        let missed = Self.log(.fajr, daysAgo: 2, status: .missed)

        let finding = Self.make(days: days, logs: [missed])
        #expect(finding.kind == .outstandingMakeups)
        #expect(finding.headline.contains("1 prayer is recorded missed"))
        #expect(finding.headline.contains("logged against it yet"))
        #expect(finding.action == .openMakeupLedger)
    }

    @Test("Several outstanding make-ups take the plural")
    func outstandingMakeupsAgreeInNumber() {
        let days = Self.steadyWeek(overrides: [
            2: [.fajr: .missed, .dhuhr: .onTime, .asr: .onTime, .maghrib: .onTime, .isha: .onTime],
            3: [.fajr: .missed, .dhuhr: .onTime, .asr: .onTime, .maghrib: .onTime, .isha: .onTime],
        ])
        let logs = [
            Self.log(.fajr, daysAgo: 2, status: .missed),
            Self.log(.fajr, daysAgo: 3, status: .missed),
        ]

        let finding = Self.make(days: days, logs: logs)
        #expect(finding.headline.contains("2 prayers are recorded missed"))
        #expect(finding.headline.contains("logged against them yet"))
    }

    /// The one that would have shipped wrong. `markAsQada` writes a
    /// SECOND linked log and leaves the original as missed, so the grid
    /// still shows missed after a repair. Only the link proves it was
    /// made up.
    @Test("A linked make-up clears the debt even though the grid still reads missed")
    func linkedMakeupClearsTheFinding() {
        let days = Self.steadyWeek(overrides: [2: [
            .fajr: .missed, .dhuhr: .onTime, .asr: .onTime, .maghrib: .onTime, .isha: .onTime
        ]])
        let missedID = UUID()
        let missed = Self.log(.fajr, daysAgo: 2, status: .missed, id: missedID)
        let repair = Self.log(.fajr, daysAgo: 1, status: .qada, qadaFor: missedID)

        let finding = Self.make(days: days, logs: [missed, repair])
        #expect(finding.kind != .outstandingMakeups)
    }

    @Test("A missed prayer on a paused day is not counted as owed")
    func pausedDayMissesAreNotOwed() {
        let days = Self.steadyWeek(overrides: [2: [.fajr: .missed]], paused: [2])
        let missed = Self.log(.fajr, daysAgo: 2, status: .missed)

        let finding = Self.make(days: days, logs: [missed])
        #expect(finding.kind != .outstandingMakeups)
    }

    // MARK: - The weak prayer

    @Test("Asr below the rest is named, with the Asr grounding")
    func weakAsrIsNamed() {
        let days = (1...7).map { offset -> DayCompletion in
            var statuses = Dictionary(
                uniqueKeysWithValues: Prayer.allCases.map { ($0, PrayerStatus.onTime) }
            )
            if offset > 2 { statuses[.asr] = .missed }
            return Self.day(offset, statuses: statuses)
        }

        let finding = Self.make(days: days, reminders: Self.allRemindersOn)
        #expect(finding.kind == .weakAsr)
        #expect(finding.headline.contains("Asr is the weak point"))
        #expect(finding.headline.contains("prayed on 2 of 7 days"))
    }

    /// The reading that would have been actively insulting: somebody
    /// who prays ʿAṣr every single day, just late, being told ʿAṣr is
    /// the prayer they are missing — under a hadith about losing your
    /// family and property.
    @Test("A prayer that is always late is late, not weak")
    func chronicDelayIsNotWeakness() {
        let days = (1...7).map { offset -> DayCompletion in
            var statuses = Dictionary(
                uniqueKeysWithValues: Prayer.allCases.map { ($0, PrayerStatus.onTime) }
            )
            statuses[.asr] = .late
            return Self.day(offset, statuses: statuses)
        }

        let finding = Self.make(days: days)
        #expect(finding.kind == .delayedAsr)
        #expect(!finding.headline.contains("weak point"))
    }

    @Test("Fajr and Isha share one reading")
    func weakFajrUsesTheSharedGrounding() {
        let days = (1...7).map { offset -> DayCompletion in
            var statuses = Dictionary(
                uniqueKeysWithValues: Prayer.allCases.map { ($0, PrayerStatus.onTime) }
            )
            if offset > 2 { statuses[.fajr] = .missed }
            return Self.day(offset, statuses: statuses)
        }

        #expect(Self.make(days: days).kind == .weakFajrOrIsha)
    }

    @Test("Under four elapsed days no prayer is named weak")
    func shortPeriodsGetNoDiagnosis() {
        let days = (1...3).map { offset -> DayCompletion in
            var statuses = Dictionary(
                uniqueKeysWithValues: Prayer.allCases.map { ($0, PrayerStatus.onTime) }
            )
            statuses[.asr] = .missed
            return Self.day(offset, statuses: statuses)
        }

        let finding = Self.make(days: days)
        #expect(finding.kind != .weakAsr)
        #expect(finding.kind != .weakFajrOrIsha)
        #expect(finding.kind != .weakOtherPrayer)
    }

    // MARK: - Delay

    @Test("A prayer habitually taken at the window's end is named")
    func delayedAsrIsNamed() {
        let days = (1...7).map { offset -> DayCompletion in
            var statuses = Dictionary(
                uniqueKeysWithValues: Prayer.allCases.map { ($0, PrayerStatus.onTime) }
            )
            if offset > 2 { statuses[.asr] = .late }
            return Self.day(offset, statuses: statuses)
        }

        let finding = Self.make(days: days)
        #expect(finding.kind == .delayedAsr)
        #expect(finding.headline.contains("delayed on 5 of 7 days"))
    }

    // MARK: - Congregation

    @Test("A solid record with no congregation says so")
    func congregationIsOffered() {
        let finding = Self.make(days: Self.steadyWeek())
        #expect(finding.kind == .noJamaah)
        #expect(finding.action == .findCongregation)
        #expect(finding.headline.contains("35 prayers recorded"))
    }

    @Test("A record already half in congregation gets no button")
    func steadyRecordWithCongregationOffersNothing() {
        let days = Self.steadyWeek(jamaah: Set(Prayer.allCases))
        let finding = Self.make(days: days)

        #expect(finding.kind == .steady)
        #expect(finding.action == nil)
        #expect(finding.actionTitle == nil)
        #expect(finding.headline.contains("Nothing in this period is slipping"))
    }

    // MARK: - The remedy ladder

    @Test("A prayer with no reminder is offered one")
    func silentPrayerIsOfferedAReminder() {
        let days = (1...7).map { offset -> DayCompletion in
            var statuses = Dictionary(
                uniqueKeysWithValues: Prayer.allCases.map { ($0, PrayerStatus.onTime) }
            )
            if offset > 2 { statuses[.asr] = .missed }
            return Self.day(offset, statuses: statuses)
        }

        let finding = Self.make(days: days, reminders: Self.allRemindersOff)
        #expect(finding.action == .enableReminder(.asr))
        #expect(finding.actionTitle == "Turn on the Asr reminder")
    }

    @Test("A prayer that already announces itself falls through to congregation")
    func announcedPrayerFallsThroughToPeople() {
        let days = (1...7).map { offset -> DayCompletion in
            var statuses = Dictionary(
                uniqueKeysWithValues: Prayer.allCases.map { ($0, PrayerStatus.onTime) }
            )
            if offset > 2 { statuses[.asr] = .missed }
            return Self.day(offset, statuses: statuses)
        }

        let finding = Self.make(days: days, reminders: Self.allRemindersOn)
        #expect(finding.action == .findCongregation)
    }

    // MARK: - Determinism

    @Test("Two equally weak prayers resolve to the earlier one, every time")
    func tiesAreStable() {
        let days = (1...7).map { offset -> DayCompletion in
            var statuses = Dictionary(
                uniqueKeysWithValues: Prayer.allCases.map { ($0, PrayerStatus.onTime) }
            )
            if offset > 2 {
                statuses[.fajr] = .missed
                statuses[.isha] = .missed
            }
            return Self.day(offset, statuses: statuses)
        }

        let first = Self.make(days: days)
        let second = Self.make(days: days)
        #expect(first == second)
        #expect(first.headline.hasPrefix("Fajr is the weak point"))
    }

    @Test("Every reading the engine can return has grounding behind it")
    func everyKindIsGrounded() {
        for kind in PathFindingKind.allCases {
            let framing = TrajectoryFindingFraming.standard(for: kind)
            #expect(framing.kind == kind)
            #expect(!framing.title.isEmpty)
            #expect(!framing.body.isEmpty)
            #expect(!framing.citation.isEmpty)
        }
    }
}
