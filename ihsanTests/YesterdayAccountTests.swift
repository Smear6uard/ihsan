import Foundation
import IhsanCore
import Testing
@testable import ihsan

/// The rules that keep an offer from becoming a demand.
///
/// Every case here is one where the app must say nothing. The one
/// where it speaks is easy; the discipline is in the silences.
@Suite("Yesterday's account")
struct YesterdayAccountTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        return calendar
    }

    /// 2026-07-30, 21:40 local — the same moment every other gallery
    /// and fixture in this repo uses.
    private var now: Date {
        calendar.date(from: DateComponents(
            year: 2026, month: 7, day: 30, hour: 21, minute: 40
        ))!
    }

    private var yesterday: Date {
        calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))!
    }

    private func log(
        _ prayer: Prayer,
        on day: Date,
        status: PrayerStatus = .onTime
    ) -> PrayerLog {
        PrayerLog(
            prayer: prayer,
            prayerDate: calendar.startOfDay(for: day),
            loggedTimeZoneIdentifier: calendar.timeZone.identifier,
            scheduledTime: day,
            status: status
        )
    }

    /// Named to avoid shadowing `YesterdayAccount.Offer` at the call
    /// sites, where `#require(resolvedOffer())` would otherwise read as a call
    /// on the type.
    private func resolvedOffer(
        logs: [PrayerLog] = [],
        pauses: [PauseInterval] = [],
        dismissed: String = ""
    ) -> YesterdayAccount.Offer? {
        YesterdayAccount.offer(
            cycleDate: calendar.startOfDay(for: now),
            logs: logs,
            pauses: pauses,
            dismissedDayKey: dismissed,
            calendar: calendar
        )
    }

    // MARK: - When it speaks

    @Test("A wholly unlogged yesterday offers all five")
    func fullyUnloggedDayOffersFive() throws {
        let offer = try #require(resolvedOffer())
        #expect(offer.unloggedCount == 5)
        #expect(offer.inscription == "YESTERDAY · 5 UNLOGGED")
        #expect(calendar.isDate(offer.day, inSameDayAs: yesterday))
    }

    @Test("A partly logged yesterday counts only what is missing")
    func partiallyLoggedDayCountsTheRest() throws {
        let logs = [log(.fajr, on: yesterday), log(.dhuhr, on: yesterday)]
        let offer = try #require(resolvedOffer(logs: logs))
        #expect(offer.unloggedCount == 3)
        #expect(offer.inscription == "YESTERDAY · 3 UNLOGGED")
    }

    @Test("One remaining reads as one, not as a figure")
    func singularReadsNaturally() throws {
        let logs = Prayer.allCases.dropLast().map { log($0, on: yesterday) }
        let offer = try #require(resolvedOffer(logs: Array(logs)))
        #expect(offer.inscription == "YESTERDAY · 1 UNLOGGED")
        #expect(offer.spokenLabel == "Yesterday, one prayer not logged")
    }

    /// A prayer marked missed is still an answer about that prayer.
    /// The offer is about the absence of an answer, not about the
    /// content of one.
    @Test("A prayer logged as missed counts as handled")
    func aMissedLogIsStillAnAnswer() throws {
        let logs = [log(.fajr, on: yesterday, status: .missed)]
        let offer = try #require(resolvedOffer(logs: logs))
        #expect(offer.unloggedCount == 4)
    }

    // MARK: - When it says nothing

    @Test("A fully accounted yesterday offers nothing, ever again")
    func fullyLoggedDayIsSilent() {
        let logs = Prayer.allCases.map { log($0, on: yesterday) }
        #expect(resolvedOffer(logs: logs) == nil)
    }

    @Test("Dismissing silences it for the rest of today")
    func dismissalHoldsForTheDay() {
        let todayKey = YesterdayAccount.civilDayKey(now, calendar: calendar)
        #expect(resolvedOffer(dismissed: todayKey) == nil)

        // And a dismissal from an earlier day does not carry over —
        // tomorrow the offer is about a different yesterday.
        #expect(resolvedOffer(dismissed: "2026-07-29") != nil)
    }

    @Test("An excused pause over yesterday silences it entirely")
    func anExcusedPauseSilencesTheOffer() {
        let pause = PauseInterval(
            startDate: calendar.date(byAdding: .day, value: -3, to: now)!,
            endDate: calendar.date(byAdding: .hour, value: -2, to: now)!,
            loggedTimeZoneIdentifier: calendar.timeZone.identifier
        )
        #expect(resolvedOffer(pauses: [pause]) == nil)
    }

    @Test("A pause that is still open silences it too")
    func anOpenPauseSilencesTheOffer() {
        let pause = PauseInterval(
            startDate: calendar.date(byAdding: .day, value: -2, to: now)!,
            loggedTimeZoneIdentifier: calendar.timeZone.identifier
        )
        #expect(resolvedOffer(pauses: [pause]) == nil)
    }

    @Test("A pause covering only part of yesterday still silences it")
    func aPartialPauseSilencesTheOffer() {
        // Ended at 6am yesterday: the morning was excused, and the app
        // is not going to litigate which prayers fell inside it.
        let pause = PauseInterval(
            startDate: calendar.date(byAdding: .day, value: -4, to: now)!,
            endDate: calendar.date(byAdding: .hour, value: 6, to: yesterday)!,
            loggedTimeZoneIdentifier: calendar.timeZone.identifier
        )
        #expect(resolvedOffer(pauses: [pause]) == nil)
    }

    @Test("A pause that ended before yesterday does not silence it")
    func anOlderPauseDoesNotSilenceTheOffer() {
        let pause = PauseInterval(
            startDate: calendar.date(byAdding: .day, value: -9, to: now)!,
            endDate: calendar.date(byAdding: .day, value: -3, to: now)!,
            loggedTimeZoneIdentifier: calendar.timeZone.identifier
        )
        #expect(resolvedOffer(pauses: [pause]) != nil)
    }

    @Test("It never mentions any day but yesterday")
    func olderDaysAreNeverOffered() {
        // Three days entirely unlogged, and yesterday complete: silent.
        let logs = Prayer.allCases.map { log($0, on: yesterday) }
        #expect(resolvedOffer(logs: logs) == nil)

        // Logs from the day before yesterday change nothing either way.
        let dayBefore = calendar.date(byAdding: .day, value: -2, to: now)!
        let mixed = logs + [log(.fajr, on: dayBefore)]
        #expect(resolvedOffer(logs: mixed) == nil)
    }

    @Test("Today's own logs are not yesterday's business")
    func todaysLogsDoNotCount() throws {
        let logs = Prayer.allCases.map { log($0, on: now) }
        let offer = try #require(resolvedOffer(logs: logs))
        #expect(offer.unloggedCount == 5, "Logging all of today says nothing about yesterday.")
    }

    // MARK: - The sheet's rows

    @Test("Rows come back in prayer order, carrying what is already logged")
    func rowsCarryExistingLogs() {
        let logs = [
            log(.dhuhr, on: yesterday, status: .late),
            log(.fajr, on: yesterday)
        ]
        let rows = YesterdayAccount.rows(for: yesterday, logs: logs, calendar: calendar)

        #expect(rows.map(\.prayer) == Prayer.allCases)
        #expect(rows[0].log?.status == .onTime)
        #expect(rows[1].log?.status == .late)
        #expect(rows[2].log == nil)
        #expect(rows[3].log == nil)
        #expect(rows[4].log == nil)
    }

    @Test("Rows ignore other days entirely")
    func rowsIgnoreOtherDays() {
        let rows = YesterdayAccount.rows(
            for: yesterday,
            logs: [log(.fajr, on: now)],
            calendar: calendar
        )
        #expect(rows.allSatisfy { $0.log == nil })
    }

    // MARK: - Day keys

    @Test("The dismissal key is a plain civil day, stable across a run")
    func civilDayKeyIsStable() {
        #expect(YesterdayAccount.civilDayKey(now, calendar: calendar) == "2026-07-30")
        #expect(YesterdayAccount.civilDayKey(yesterday, calendar: calendar) == "2026-07-29")
        // Late at night and early the same morning are the same key.
        let earlyMorning = calendar.date(from: DateComponents(
            year: 2026, month: 7, day: 30, hour: 0, minute: 5
        ))!
        #expect(YesterdayAccount.civilDayKey(earlyMorning, calendar: calendar) == "2026-07-30")
    }
}
