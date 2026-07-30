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

    private func resolve(_ window: PrayerScheduleWindow, at date: Date) -> PrayerResolution {
        PrayerStateResolver.resolve(prayerTimes: window.resolverSchedule, now: date)
    }

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
            let resolution = resolve(w, at: tick)
            if let current = resolution.currentPrayer {
                #expect(
                    resolution.windowEnd(for: current) == resolution.currentWindowEnd,
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
        let atDhuhr = resolve(w, at: w.day.dhuhr.scheduledTime)
        #expect(atDhuhr.windowEnd(for: w.day.dhuhr) == w.day.asr.scheduledTime)
        let justBeforeAsr = w.day.asr.scheduledTime.addingTimeInterval(-1)
        let resolution = resolve(w, at: justBeforeAsr)
        #expect(resolution.currentPrayer?.prayer == .dhuhr)
        #expect(resolution.currentWindowEnd == w.day.asr.scheduledTime)
        #expect(resolution.nextPrayer.prayer == .asr)
    }

    /// The dawn property, pinned after the device review caught the
    /// card advanced to Dhuhr at 5:27 AM with sunrise at 5:47: for
    /// EVERY t in [fajr, sunrise), the current prayer is Fajr and its
    /// window end is sunrise — the focused card cannot advance while
    /// Fajr is open. At sunrise the window closes atomically and
    /// Dhuhr becomes next/upcoming per the temporal rules.
    @Test
    func fajrIsCurrentFromAdhanUntilSunrise() throws {
        let w = try window(at: noon)
        var tick = w.day.fajr.scheduledTime
        var samples = 0
        while tick < w.day.sunrise {
            let resolution = resolve(w, at: tick)
            #expect(resolution.currentPrayer?.prayer == .fajr, "Fajr not current at \(tick)")
            #expect(resolution.currentWindowEnd == w.day.sunrise)
            #expect(resolution.nextPrayer.prayer == .dhuhr)
            tick = tick.addingTimeInterval(30)
            samples += 1
        }
        #expect(samples > 50)

        // The boundary instant itself belongs to the closed state.
        let atSunrise = resolve(w, at: w.day.sunrise)
        #expect(atSunrise.currentPrayer == nil)
        #expect(atSunrise.nextPrayer.prayer == .dhuhr)
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
        let resolution = resolve(w, at: midGap)
        #expect(resolution.currentPrayer == nil)
        #expect(resolution.currentWindowEnd == nil)
        #expect(resolution.nextPrayer.prayer == .dhuhr)
    }

    // MARK: - Pre-window gating

    /// Commit controls exist only where a commitment is meaningful:
    /// never before the window opens.
    @Test
    func upcomingPhaseAdmitsNoCommitControls() {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let opens = now.addingTimeInterval(3600)
        let phase = FocusedCardModel.resolve(
            windowState: .upcoming(opensAt: opens),
            isLogged: false
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
