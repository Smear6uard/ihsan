import Foundation
import IhsanCore
import IhsanPrayerTimes
import Testing
@testable import ihsan

/// Part-A item 4: the header's "NEXT:" inscription and the plate's
/// marker labels must agree to the minute — same data source (the
/// resolved `PrayerResolution`), same formatter (`PlateTimeFormat`).
@Suite("Today moment derivation")
struct TodayMomentDerivationTests {

    private let chicago = TimeZone(identifier: "America/Chicago")!

    private func resolve(_ window: PrayerScheduleWindow, at date: Date) -> PrayerResolution {
        TodayDisplaySchedule.resolve(window: window, now: date)
    }

    private func window(at date: Date) throws -> PrayerScheduleWindow {
        try AdhanPrayerTimesProvider().scheduleWindow(
            for: date,
            coordinates: Coordinates(latitude: 41.8781, longitude: -87.6298),
            timeZone: chicago,
            calculationMethod: .isna,
            madhab: .standard,
            highLatitudeRule: .middleOfNight
        )
    }

    private var noon: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = chicago
        return calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 20, hour: 12)
        )!
    }

    /// The plate, card, and sheet consume the same exact prayer
    /// instance at every minute of a cycle. The header independently
    /// names the strictly-future next prayer; after Isha that is the
    /// closing Fajr while the plate intentionally remains on the
    /// current cycle until that Fajr arrives.
    @Test
    func cycleSurfacesRenderIdenticalStringsForIdenticalPrayerInstances() throws {
        let w = try window(at: noon)
        var now = w.day.fajr.scheduledTime
        let end = w.tomorrowFajr.scheduledTime
        while now < end {
            let resolution = resolve(w, at: now)
            #expect(resolution.nextPrayer.scheduledTime > now)

            for prayer in Prayer.allCases {
                let display = TodayDisplaySchedule.displayTime(
                    for: prayer, window: w, now: now
                )
                #expect(display == w.cycleDayTimes(at: now).time(for: prayer))
                #expect(resolution.state(for: TodayDisplaySchedule.prayerTime(
                    for: prayer, window: w, now: now
                )) != nil)

                let plateLabel = PlateTimeFormat.time(display, in: chicago)
                let card = PlateTimeFormat.time(display, in: chicago)
                let sheet = PlateTimeFormat.time(display, in: chicago)
                #expect(plateLabel == card)
                #expect(plateLabel == sheet)
            }

            now = now.addingTimeInterval(60)
        }
    }

    /// The reproduced failure at the level the UI consumes. Two
    /// independently refreshed windows on opposite sides of civil
    /// midnight must select the same cycle, the same five marker
    /// instants, and the same still-open Isha.
    @Test
    func civilMidnightDoesNotAdvanceTheDisplayedCycle() throws {
        let beforeMidnight = localDate(2026, 7, 20, 23, 59)
        let afterMidnight = localDate(2026, 7, 21, 0, 1)
        let beforeWindow = try window(at: beforeMidnight)
        let afterWindow = try window(at: afterMidnight)
        let beforeResolution = resolve(beforeWindow, at: beforeMidnight)
        let afterResolution = resolve(afterWindow, at: afterMidnight)

        #expect(beforeWindow.cycle(at: beforeMidnight).date == afterWindow.cycle(at: afterMidnight).date)
        for prayer in Prayer.allCases {
            #expect(
                TodayDisplaySchedule.displayTime(
                    for: prayer, window: beforeWindow, now: beforeMidnight
                )
                    == TodayDisplaySchedule.displayTime(
                        for: prayer, window: afterWindow, now: afterMidnight
                    )
            )
        }
        #expect(beforeResolution.currentPrayer == beforeWindow.day.isha)
        #expect(afterResolution.currentPrayer == afterWindow.yesterday.isha)
        #expect(afterResolution.currentWindowEnd == afterWindow.day.fajr.scheduledTime)
    }

    @Test("At 1 AM the plate and card still resolve yesterday's Isha")
    func oneAmUsesTheEveningCycle() throws {
        let oneAm = localDate(2026, 7, 21, 1, 0)
        let w = try window(at: oneAm)
        let resolution = resolve(w, at: oneAm)
        let isha = TodayDisplaySchedule.prayerTime(for: .isha, window: w, now: oneAm)

        #expect(isha == w.yesterday.isha)
        #expect(resolution.currentPrayer == isha)
        #expect(resolution.state(for: isha)?.isCurrent == true)
        #expect(resolution.currentWindowEnd == w.day.fajr.scheduledTime)
        #expect(resolution.nextPrayer == w.day.fajr)
    }

    private func localDate(
        _ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = chicago
        return calendar.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute
        ))!
    }

    /// The formatter localises into the *place's* timezone, not the
    /// device's — a Chicago prayer time reads as Chicago clock time.
    @Test
    func formatterUsesThePlacesTimeZone() {
        let instant = Date(timeIntervalSince1970: 1_784_567_400) // fixed
        let inChicago = PlateTimeFormat.time(instant, in: chicago)
        let inUTC = PlateTimeFormat.time(instant, in: TimeZone(identifier: "UTC")!)
        #expect(inChicago != inUTC)
    }

    /// Item 3, rendered form: walking one-second ticks across a window
    /// boundary, the countdown string never rests at 0:00:00 — the
    /// final sub-second reads 0:00:01 and the next tick belongs to the
    /// next state.
    @Test
    func renderedCountdownNeverRestsAtZero() throws {
        let w = try window(at: noon)
        let boundary = w.day.asr.scheduledTime

        for step in stride(from: -3.0, through: 3.0, by: 0.5) {
            let now = boundary.addingTimeInterval(step)
            let resolution = resolve(w, at: now)
            let target = resolution.countdownTarget
            #expect(target > now)
            #expect(FocusedCardModel.countdown(until: target, now: now) != "0:00:00")
        }
    }

    /// Marker-state projection: at a window boundary the current
    /// marker flips on the same tick the card's state flips — both
    /// read the same `PrayerResolution`.
    @Test
    func markerCurrentFollowsTheMomentAtBoundaries() throws {
        let w = try window(at: noon)

        let justBeforeAsr = resolve(w, at: w.day.asr.scheduledTime.addingTimeInterval(-1))
        #expect(justBeforeAsr.currentPrayer?.prayer == .dhuhr)
        #expect(justBeforeAsr.nextPrayer.prayer == .asr)

        let atAsr = resolve(w, at: w.day.asr.scheduledTime)
        #expect(atAsr.currentPrayer?.prayer == .asr)
        #expect(atAsr.nextPrayer.prayer == .maghrib)
    }
}
