import Foundation
import IhsanCore
import IhsanPrayerTimes
import Testing
@testable import ihsan

/// Phase 5a: ONE source of truth for prayer-window ends. The device
/// review saw two Asr times at once; the audit traced it to a
/// device-timezone formatter in the log sheet (fixed in the sheet
/// rebuild) — but these tests pin the deeper guarantee: every surface
/// derives window ends from the same rule, and that rule agrees with
/// the schedule window's own resolution at every instant of the day.
@Suite("Prayer window semantics")
struct PrayerWindowSemanticsTests {

    private let newYork = TimeZone(identifier: "America/New_York")!

    private func window(at date: Date) throws -> PrayerScheduleWindow {
        try AdhanPrayerTimesProvider().scheduleWindow(
            for: date,
            coordinates: Coordinates(latitude: 40.7128, longitude: -74.0059),
            timeZone: newYork,
            calculationMethod: .isna,
            madhab: .standard,
            highLatitudeRule: .middleOfNight
        )
    }

    private var noon: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = newYork
        return calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 29, hour: 12)
        )!
    }

    /// Sweep the whole day at 90-second ticks: whenever a window is
    /// open, the per-prayer rule (used by the log sheet and the card)
    /// must name exactly the end the schedule window resolved. One
    /// rule, two readers, zero room to drift.
    @Test
    func windowEndRuleAgreesWithMomentResolutionAllDay() throws {
        let w = try window(at: noon)
        var tick = w.day.fajr.scheduledTime
        let dayEnd = w.tomorrowFajr.scheduledTime
        var openSamples = 0
        while tick < dayEnd {
            let moment = w.moment(at: tick)
            if let current = moment.current {
                #expect(
                    PrayerWindowRule.windowEnd(for: current.prayer, in: w)
                        == moment.currentWindowEnd,
                    "disagreement at \(tick) for \(current.prayer)"
                )
                openSamples += 1
            }
            tick = tick.addingTimeInterval(90)
        }
        #expect(openSamples > 100)
    }

    /// Dhuhr's end IS Asr's start — the single Asr instant, from the
    /// user's one madhab setting. There is no second Asr time anywhere
    /// in the model for a surface to leak.
    @Test
    func dhuhrEndsExactlyAtAsr() throws {
        let w = try window(at: noon)
        #expect(
            PrayerWindowRule.windowEnd(for: .dhuhr, in: w)
                == w.day.asr.scheduledTime
        )
        let justBeforeAsr = w.day.asr.scheduledTime.addingTimeInterval(-1)
        let moment = w.moment(at: justBeforeAsr)
        #expect(moment.current?.prayer == .dhuhr)
        #expect(moment.currentWindowEnd == w.day.asr.scheduledTime)
        #expect(moment.next.prayer == .asr)
    }

    /// The forenoon gap is the only span with no open window: after
    /// sunrise, before Dhuhr. Header shows next, card shows upcoming,
    /// nothing is loggable as "on time".
    @Test
    func forenoonGapHasNoOpenWindow() throws {
        let w = try window(at: noon)
        let midGap = w.day.sunrise.addingTimeInterval(
            w.day.dhuhr.scheduledTime.timeIntervalSince(w.day.sunrise) / 2
        )
        let moment = w.moment(at: midGap)
        #expect(moment.current == nil)
        #expect(moment.currentWindowEnd == nil)
        #expect(moment.next.prayer == .dhuhr)
    }

    // MARK: - Pre-window gating

    /// Commit controls exist only where a commitment is meaningful:
    /// never before the window opens.
    @Test
    func upcomingPhaseAdmitsNoCommitControls() {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let opens = now.addingTimeInterval(3600)
        let phase = FocusedCardModel.resolve(
            scheduledTime: opens,
            windowEndTime: opens.addingTimeInterval(7200),
            isInWindow: false,
            isLogged: false,
            now: now
        )
        #expect(phase == .upcoming(opensAt: opens))
        #expect(FocusedCardModel.allowsLogging(phase) == false)
    }

    @Test
    func openAndPassedWindowsAdmitLogging() {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        #expect(FocusedCardModel.allowsLogging(
            .active(until: now.addingTimeInterval(600))
        ))
        #expect(FocusedCardModel.allowsLogging(.windowClosed(at: now)))
        #expect(FocusedCardModel.allowsLogging(.logged))
    }

    // MARK: - Display frame

    /// The regression the device review caught: a prayer instant must
    /// render in the PLACE's clock frame on every surface. For an
    /// instant whose New York hour differs from UTC's, the formatted
    /// string must carry the New York hour when New York is the frame.
    @Test
    func formattedTimesCarryThePlacesClockHour() throws {
        let w = try window(at: noon)
        let asr = w.day.asr.scheduledTime
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = newYork
        let hour24 = calendar.component(.hour, from: asr)
        let hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12
        #expect(
            PlateTimeFormat.time(asr, in: newYork).contains("\(hour12)"),
            "place-frame hour \(hour12) missing from formatted string"
        )
    }
}
