import Foundation
import IhsanCore
import Testing
@testable import IhsanPrayerTimes

/// Correctness contract for `PrayerStateResolver.resolve(...)`:
///
/// - `next` is always the strictly-future nearest fardh, rolling into
///   tomorrow's Fajr after Isha.
/// - `current` is the prayer whose fiqh window contains the instant:
///   Fajr [fajr, sunrise), Dhuhr [dhuhr, asr), Asr [asr, maghrib),
///   Maghrib [maghrib, isha), Isha [isha, next Fajr) — which before
///   dawn is *yesterday's* Isha. The only current-less span is the
///   forenoon gap [sunrise, dhuhr).
/// - `countdownTarget` is always the strictly-future next prayer start;
///   current-window end is exposed separately for the active card.
@Suite("PrayerScheduleWindow")
struct PrayerScheduleWindowTests {

    private let provider = AdhanPrayerTimesProvider()

    private func resolve(_ window: PrayerScheduleWindow, at date: Date) -> PrayerResolution {
        PrayerStateResolver.resolve(prayerTimes: window.resolverSchedule, now: date)
    }

    private func window(
        at date: Date,
        latitude: Double = 41.8781,
        longitude: Double = -87.6298,
        timeZone: TimeZone = TimeZone(identifier: "America/Chicago")!
    ) throws -> PrayerScheduleWindow {
        try provider.scheduleWindow(
            for: date,
            coordinates: Coordinates(latitude: latitude, longitude: longitude),
            timeZone: timeZone,
            calculationMethod: .isna,
            madhab: .standard,
            highLatitudeRule: .middleOfNight
        )
    }

    /// A fixed summer day, noon Chicago time.
    private var referenceNoon: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        return calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 20, hour: 12)
        )!
    }

    // MARK: - Boundary exactness

    @Test
    func atFajrExactlyFajrIsCurrent() throws {
        let w = try window(at: referenceNoon)
        let m = resolve(w, at: w.day.fajr.scheduledTime)
        #expect(m.currentPrayer?.prayer == .fajr)
        #expect(m.currentWindowEnd == w.day.sunrise)
        #expect(m.nextPrayer.prayer == .dhuhr)
    }

    @Test
    func atSunriseExactlyTheWindowHasAlreadyClosed() throws {
        let w = try window(at: referenceNoon)
        let m = resolve(w, at: w.day.sunrise)
        #expect(m.currentPrayer == nil)
        #expect(m.currentWindowEnd == nil)
        #expect(m.nextPrayer.prayer == .dhuhr)
    }

    @Test
    func oneSecondBeforeSunriseFajrIsStillCurrent() throws {
        let w = try window(at: referenceNoon)
        let m = resolve(w, at: w.day.sunrise.addingTimeInterval(-1))
        #expect(m.currentPrayer?.prayer == .fajr)
    }

    @Test
    func atIshaExactlyIshaIsCurrentAndNextRollsToTomorrowFajr() throws {
        let w = try window(at: referenceNoon)
        let m = resolve(w, at: w.day.isha.scheduledTime)
        #expect(m.currentPrayer?.prayer == .isha)
        #expect(m.currentWindowEnd == w.tomorrowFajr.scheduledTime)
        #expect(m.nextPrayer.prayer == .fajr)
        #expect(m.nextPrayer.scheduledTime > w.day.isha.scheduledTime)
    }

    @Test
    func preDawnCurrentIsYesterdaysIsha() throws {
        let w = try window(at: referenceNoon)
        let preDawn = w.day.fajr.scheduledTime.addingTimeInterval(-3600)
        let m = resolve(w, at: preDawn)
        #expect(m.currentPrayer?.prayer == .isha)
        #expect(m.currentPrayer?.scheduledTime == w.yesterdayIsha.scheduledTime)
        #expect(m.currentWindowEnd == w.day.fajr.scheduledTime)
        #expect(m.nextPrayer.prayer == .fajr)
    }

    @Test
    func midAfternoonAsrWindowRunsToMaghrib() throws {
        let w = try window(at: referenceNoon)
        let midAsr = w.day.asr.scheduledTime.addingTimeInterval(
            w.day.maghrib.scheduledTime.timeIntervalSince(w.day.asr.scheduledTime) / 2
        )
        let m = resolve(w, at: midAsr)
        #expect(m.currentPrayer?.prayer == .asr)
        #expect(m.currentWindowEnd == w.day.maghrib.scheduledTime)
        #expect(m.nextPrayer.prayer == .maghrib)
    }

    /// Item 3's core guarantee: at every instant — including exact
    /// window boundaries — the countdown target is strictly in the
    /// future. A rendered countdown therefore never rests at 0:00:00.
    @Test
    func countdownTargetIsStrictlyFutureAcrossAllBoundaries() throws {
        let w = try window(at: referenceNoon)
        // Probes stay inside the window's valid span, which ends the
        // instant before tomorrow's Fajr — at tomorrow's Fajr the UI
        // must have rolled to a fresh window.
        var probes: [Date] = []
        for time in w.day.allFardh.map(\.scheduledTime)
            + [w.day.sunrise, w.tomorrowFajr.scheduledTime - 2] {
            probes.append(time.addingTimeInterval(-1))
            probes.append(time)
            probes.append(time.addingTimeInterval(1))
        }
        for t in probes {
            let m = resolve(w, at: t)
            let target = m.currentWindowEnd ?? m.nextPrayer.scheduledTime
            #expect(target > t, "countdown target must be strictly future at \(t)")
        }
    }

    // MARK: - Property test: 50 random times and locations

    @Test
    func resolutionInvariantsHoldAcrossRandomTimesAndLocations() throws {
        var rng = SplitMix64(state: 0x1FA9_2026)
        let timeZonePool = [
            "UTC", "America/New_York", "America/Los_Angeles", "Europe/London",
            "Asia/Karachi", "Asia/Tokyo", "Australia/Sydney", "Pacific/Auckland",
            "Asia/Riyadh", "Africa/Cairo"
        ]

        for iteration in 0..<50 {
            let latitude = rng.unit() * 110.0 - 55.0
            let longitude = rng.unit() * 360.0 - 180.0
            let timeZone = TimeZone(
                identifier: timeZonePool[Int(rng.next() % UInt64(timeZonePool.count))]
            )!
            // Any instant across 2026.
            let t = Date(timeIntervalSince1970: 1_767_225_600 + rng.unit() * 365 * 86_400)

            let w = try window(
                at: t, latitude: latitude, longitude: longitude, timeZone: timeZone
            )
            let m = resolve(w, at: t)
            let context = "iteration \(iteration): lat \(latitude), lon \(longitude), \(timeZone.identifier), t \(t)"

            // next is strictly future and minimal among candidates.
            #expect(m.nextPrayer.scheduledTime > t, Comment(rawValue: context))
            let candidates = w.day.allFardh + [w.tomorrowFajr]
            let strictlyFuture = candidates
                .filter { $0.scheduledTime > t }
                .map(\.scheduledTime)
            if let earliest = strictlyFuture.min() {
                #expect(m.nextPrayer.scheduledTime == earliest, Comment(rawValue: context))
            }

            // current's window contains t; the gap is exactly [sunrise, dhuhr).
            if let current = m.currentPrayer {
                let end = try #require(m.currentWindowEnd, Comment(rawValue: context))
                #expect(current.scheduledTime <= t, Comment(rawValue: context))
                #expect(t < end, Comment(rawValue: context))
            } else {
                let inForenoonGap = t >= w.day.sunrise && t < w.day.dhuhr.scheduledTime
                let beforeYesterdayIsha = t < w.yesterdayIsha.scheduledTime
                #expect(
                    inForenoonGap || beforeYesterdayIsha,
                    Comment(rawValue: context)
                )
            }
        }
    }

    /// The provider's `currentPrayer` now shares the window-aware
    /// resolution — pre-dawn it reports yesterday's Isha, and the
    /// forenoon gap reports nothing.
    @Test
    func providerCurrentPrayerIsWindowAware() throws {
        let w = try window(at: referenceNoon)
        let preDawn = w.day.fajr.scheduledTime.addingTimeInterval(-1800)
        let forenoon = w.day.sunrise.addingTimeInterval(600)

        let coordinates = Coordinates(latitude: 41.8781, longitude: -87.6298)
        let timeZone = TimeZone(identifier: "America/Chicago")!

        let preDawnCurrent = try provider.currentPrayer(
            at: preDawn, coordinates: coordinates, timeZone: timeZone,
            calculationMethod: .isna, madhab: .standard, highLatitudeRule: .middleOfNight
        )
        #expect(preDawnCurrent?.prayer == .isha)

        let forenoonCurrent = try provider.currentPrayer(
            at: forenoon, coordinates: coordinates, timeZone: timeZone,
            calculationMethod: .isna, madhab: .standard, highLatitudeRule: .middleOfNight
        )
        #expect(forenoonCurrent == nil)
    }
}

/// Deterministic RNG so the 50 samples are the same 50 samples on
/// every run.
private struct SplitMix64 {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func unit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }
}
