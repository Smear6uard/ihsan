import Foundation
import Testing
@testable import IhsanPrayerTimes

/// The windows are the feature's shape, so their edges are pinned.
@Suite("Adhkar windows")
struct AdhkarWindowTests {

    private func time(_ hour: Double) -> Date {
        Date(timeIntervalSinceReferenceDate: 700_000_000 + hour * 3600)
    }

    // A plain mid-latitude day.
    private let fajr = 5.0, sunrise = 6.5, dhuhr = 12.5, asr = 16.0, maghrib = 19.5, isha = 21.0

    // MARK: - Morning

    @Test("The morning runs from Fajr to the offset past sunrise")
    func morningSpansFajrToMidMorning() throws {
        let window = try #require(AdhkarWindowResolver.morning(
            fajr: time(fajr), sunrise: time(sunrise), dhuhr: time(dhuhr),
            endsAfterSunrise: 90 * 60
        ))
        #expect(window.start == time(fajr))
        #expect(window.end == time(sunrise + 1.5))
        #expect(window.contains(time(6.0)))
        #expect(window.contains(time(7.9)))
        #expect(!window.contains(time(8.1)))
        #expect(!window.contains(time(4.9)))
    }

    /// The window is half-open: the instant it ends, it is over. A card
    /// that lingers one tick past its window is a card that lies.
    @Test("A window does not contain its own end")
    func windowIsHalfOpen() throws {
        let window = try #require(AdhkarWindowResolver.morning(
            fajr: time(fajr), sunrise: time(sunrise), dhuhr: time(dhuhr),
            endsAfterSunrise: 90 * 60
        ))
        #expect(window.contains(window.start))
        #expect(!window.contains(window.end))
    }

    @Test("The morning never runs past Dhuhr, however generous the offset")
    func morningIsClampedAtDhuhr() throws {
        let window = try #require(AdhkarWindowResolver.morning(
            fajr: time(fajr), sunrise: time(sunrise), dhuhr: time(dhuhr),
            endsAfterSunrise: 12 * 3600
        ))
        #expect(window.end == time(dhuhr))
    }

    /// A high-latitude summer day where Fajr and sunrise nearly touch
    /// and Dhuhr arrives before the offset would: no window rather than
    /// an inverted one.
    @Test("A collapsed day yields no morning window")
    func collapsedDayHasNoMorningWindow() {
        #expect(AdhkarWindowResolver.morning(
            fajr: time(12.6), sunrise: time(12.7), dhuhr: time(12.5),
            endsAfterSunrise: 90 * 60
        ) == nil)
    }

    // MARK: - Evening

    @Test("The evening runs from Asr into the early night by default")
    func eveningSpansAsrPastMaghrib() throws {
        let window = try #require(AdhkarWindowResolver.evening(
            asr: time(asr), maghrib: time(maghrib), isha: time(isha),
            extendsAfterMaghrib: 60 * 60
        ))
        #expect(window.start == time(asr))
        #expect(window.end == time(maghrib + 1))
        #expect(window.contains(time(19.9)))
    }

    /// Someone who holds the evening closes at Maghrib sets the offset
    /// to zero and gets exactly that.
    @Test("A zero extension closes the evening at Maghrib")
    func zeroExtensionClosesAtMaghrib() throws {
        let window = try #require(AdhkarWindowResolver.evening(
            asr: time(asr), maghrib: time(maghrib), isha: time(isha),
            extendsAfterMaghrib: 0
        ))
        #expect(window.end == time(maghrib))
        #expect(!window.contains(time(maghrib)))
    }

    /// The evening card and the sleep card must never be open at once.
    @Test("The evening never runs past Isha")
    func eveningIsClampedAtIsha() throws {
        let window = try #require(AdhkarWindowResolver.evening(
            asr: time(asr), maghrib: time(maghrib), isha: time(isha),
            extendsAfterMaghrib: 5 * 3600
        ))
        #expect(window.end == time(isha))

        let sleep = try #require(AdhkarWindowResolver.sleep(
            isha: time(isha), nextFajr: time(fajr + 24)
        ))
        #expect(window.end <= sleep.start)
        for hour in stride(from: 16.0, to: 28.0, by: 0.25) {
            let both = window.contains(time(hour)) && sleep.contains(time(hour))
            #expect(!both, "evening and sleep both open at \(hour)")
        }
    }

    /// A short summer night where Maghrib and ʿIshāʾ nearly touch: the
    /// clamp must not invert the window into nothing when the person
    /// still has an evening to keep.
    @Test("A short night keeps the evening at least up to Maghrib")
    func shortNightKeepsTheEvening() throws {
        let window = try #require(AdhkarWindowResolver.evening(
            asr: time(asr), maghrib: time(maghrib), isha: time(maghrib - 0.5),
            extendsAfterMaghrib: 60 * 60
        ))
        #expect(window.start == time(asr))
        #expect(window.end == time(maghrib))
    }

    // MARK: - Sleep

    @Test("Sleep runs from Isha to the coming Fajr")
    func sleepSpansIshaToNextFajr() throws {
        let window = try #require(AdhkarWindowResolver.sleep(
            isha: time(isha), nextFajr: time(fajr + 24)
        ))
        #expect(window.contains(time(23.0)))
        #expect(window.contains(time(26.0)))
        #expect(!window.contains(time(29.5)))
    }

    @Test("A day with no night yields no sleep window")
    func noNightYieldsNoSleepWindow() {
        #expect(AdhkarWindowResolver.sleep(isha: time(21), nextFajr: time(21)) == nil)
    }
}
