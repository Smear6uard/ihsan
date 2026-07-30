import Foundation
import IhsanCore
import Testing
@testable import IhsanPrayerTimes

@Suite("Prayer resolver cache bridge")
struct PrayerTimesCacheResolverTests {
    @Test
    func cachedTableRebuildsTheIdenticalResolverInput() throws {
        let provider = AdhanPrayerTimesProvider()
        let timeZone = try #require(TimeZone(identifier: "Asia/Karachi"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let now = try #require(calendar.date(from: DateComponents(
            year: 2026, month: 7, day: 30, hour: 12, minute: 36
        )))
        let window = try provider.scheduleWindow(
            for: now,
            coordinates: Coordinates(latitude: 24.8607, longitude: 67.0011),
            timeZone: timeZone,
            calculationMethod: .isna,
            madhab: .standard,
            highLatitudeRule: .middleOfNight
        )
        let source = window.resolverSchedule
        let cache = PrayerTimesCache(
            date: window.day.date,
            timeZoneIdentifier: timeZone.identifier,
            cityName: "Karachi",
            entries: window.day.allFardh.map {
                PrayerTimesCache.Entry(
                    prayerRaw: $0.prayer.rawValue,
                    scheduledTime: $0.scheduledTime
                )
            },
            previousDayIsha: window.yesterdayIsha.scheduledTime,
            sunrise: window.day.sunrise,
            nextDayFajr: window.tomorrowFajr.scheduledTime,
            writtenAt: now
        )

        let rebuilt = try #require(cache.resolverSchedule)
        #expect(rebuilt == source)
        #expect(rebuilt.tableHash == source.tableHash)
        #expect(
            PrayerStateResolver.resolve(prayerTimes: rebuilt, now: now)
                == PrayerStateResolver.resolve(prayerTimes: source, now: now)
        )
    }

    @Test
    func legacyCacheWithoutEveryBoundaryIsRejectedInsteadOfShownStale() {
        let date = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let cache = PrayerTimesCache(
            date: date,
            timeZoneIdentifier: "America/Chicago",
            cityName: "Chicago",
            entries: Prayer.allCases.map {
                PrayerTimesCache.Entry(prayerRaw: $0.rawValue, scheduledTime: date)
            },
            nextDayFajr: nil,
            writtenAt: date
        )
        #expect(cache.resolverSchedule == nil)
    }
}
