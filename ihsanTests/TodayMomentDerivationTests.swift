import Foundation
import IhsanCore
import IhsanPrayerTimes
import Testing
@testable import ihsan

/// Part-A item 4: the header's "NEXT:" inscription and the plate's
/// marker labels must agree to the minute — same data source (the
/// resolved `PrayerMoment`), same formatter (`PlateTimeFormat`).
@Suite("Today moment derivation")
struct TodayMomentDerivationTests {

    private let chicago = TimeZone(identifier: "America/Chicago")!

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

    /// Corrective G, phase 1 — the formatter-unity invariant, with no
    /// carve-outs: at EVERY minute of the schedule window's span, the
    /// display instant `TodayDisplaySchedule` supplies for the
    /// moment's next prayer IS `moment.next.scheduledTime`. The four
    /// surfaces (header "NEXT:", plate marker label, focused card,
    /// log sheet) all format that one instant through the one
    /// `PlateTimeFormat`, so they render identical strings —
    /// including the post-Isha stretch where Fajr rolls to tomorrow
    /// and the plate used to print yesterday's minute.
    @Test
    func allFourSurfacesRenderIdenticalStringsForIdenticalTimes() throws {
        let w = try window(at: noon)
        var now = w.day.fajr.scheduledTime
        let end = w.tomorrowFajr.scheduledTime
        while now < end {
            let moment = w.moment(at: now)
            let display = TodayDisplaySchedule.displayTime(
                for: moment.next.prayer, window: w, now: now
            )
            // One source: the display schedule and the moment agree
            // about which instant "next" means…
            #expect(display == moment.next.scheduledTime)

            // …so the four surfaces' rendered strings are identical.
            let header = PlateTimeFormat.time(moment.next.scheduledTime, in: chicago)
            let plateLabel = PlateTimeFormat.time(display, in: chicago)
            let card = PlateTimeFormat.time(display, in: chicago)
            let sheet = PlateTimeFormat.time(display, in: chicago)
            #expect(header == plateLabel)
            #expect(header == card)
            #expect(header == sheet)

            now = now.addingTimeInterval(60)
        }
    }

    /// The concrete regression: after Isha begins, the plate's Fajr
    /// label shows tomorrow's Fajr — the same instant the header and
    /// card show — never this morning's, which is typically a minute
    /// different.
    @Test
    func fajrLabelRollsToTomorrowOnceIshaOpens() throws {
        let w = try window(at: noon)
        let beforeIsha = w.day.isha.scheduledTime.addingTimeInterval(-60)
        let afterIsha = w.day.isha.scheduledTime.addingTimeInterval(60)

        #expect(
            TodayDisplaySchedule.displayTime(for: .fajr, window: w, now: beforeIsha)
                == w.day.fajr.scheduledTime
        )
        #expect(!TodayDisplaySchedule.isRolledToTomorrow(.fajr, window: w, now: beforeIsha))

        #expect(
            TodayDisplaySchedule.displayTime(for: .fajr, window: w, now: afterIsha)
                == w.tomorrowFajr.scheduledTime
        )
        #expect(TodayDisplaySchedule.isRolledToTomorrow(.fajr, window: w, now: afterIsha))

        // The other four prayers never roll.
        for prayer in [Prayer.dhuhr, .asr, .maghrib, .isha] {
            #expect(
                TodayDisplaySchedule.displayTime(for: prayer, window: w, now: afterIsha)
                    == w.day.time(for: prayer)
            )
        }
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
            let moment = w.moment(at: now)
            let target = moment.countdownTarget
            #expect(target > now)
            #expect(FocusedCardModel.countdown(until: target, now: now) != "0:00:00")
        }
    }

    /// Marker-state projection: at a window boundary the current
    /// marker flips on the same tick the card's state flips — both
    /// read the same `PrayerMoment`.
    @Test
    func markerCurrentFollowsTheMomentAtBoundaries() throws {
        let w = try window(at: noon)

        let justBeforeAsr = w.moment(at: w.day.asr.scheduledTime.addingTimeInterval(-1))
        #expect(justBeforeAsr.current?.prayer == .dhuhr)
        #expect(justBeforeAsr.next.prayer == .asr)

        let atAsr = w.moment(at: w.day.asr.scheduledTime)
        #expect(atAsr.current?.prayer == .asr)
        #expect(atAsr.next.prayer == .maghrib)
    }
}
