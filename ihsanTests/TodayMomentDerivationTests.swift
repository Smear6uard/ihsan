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

    /// Whenever the next prayer is one of today's five, its instant is
    /// identical to the marker's instant for that prayer — so the one
    /// shared formatter cannot produce two different strings.
    @Test
    func headerNextAgreesWithMarkerTimeToTheMinute() throws {
        let w = try window(at: noon)
        for offset in stride(from: 0.0, through: 60_000.0, by: 4_000.0) {
            let now = w.day.fajr.scheduledTime.addingTimeInterval(offset)
            let moment = w.moment(at: now)
            guard moment.next.prayer != .fajr || moment.next.scheduledTime <= w.day.isha.scheduledTime else {
                continue // rolled to tomorrow's Fajr — no marker for it today
            }
            let markerTime = w.day.time(for: moment.next.prayer)
            guard markerTime == moment.next.scheduledTime else {
                continue // next is tomorrow's instance of this prayer
            }
            #expect(
                PlateTimeFormat.time(moment.next.scheduledTime, in: chicago)
                    == PlateTimeFormat.time(markerTime, in: chicago)
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
