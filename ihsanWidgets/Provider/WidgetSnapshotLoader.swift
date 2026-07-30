import Foundation
import IhsanCore
import IhsanPrayerTimes
import SwiftData

/// Turns the exact resolver table published by the host app into
/// widget timeline entries. Widgets never run a second Adhan
/// calculation path and never substitute the device timezone for the
/// prayer location's timezone.
@MainActor
struct WidgetSnapshotLoader {
    func entries(starting referenceDate: Date) -> [PrayerTimelineEntry] {
        guard
            let cache = PrayerTimesCacheStore.read(),
            let schedule = cache.resolverSchedule,
            isValid(cache: cache, schedule: schedule, at: referenceDate)
        else {
            return [missingLocationEntry(at: referenceDate)]
        }

        let logs = openSharedContext().map {
            readTodaysLogs(
                at: referenceDate,
                timeZoneIdentifier: cache.timeZoneIdentifier,
                from: $0
            )
        } ?? [:]

        // Entries land on every resolver boundary, including sunrise
        // (Fajr's exit). Tomorrow Fajr is the cache expiration/reload
        // instant and is intentionally not rendered from this table.
        let boundaryDates = [
            schedule.fajr.scheduledTime,
            schedule.sunrise,
            schedule.dhuhr.scheduledTime,
            schedule.asr.scheduledTime,
            schedule.maghrib.scheduledTime,
            schedule.isha.scheduledTime
        ]
        let timelineDates = [referenceDate]
            + boundaryDates.filter { $0 > referenceDate }

        return timelineDates.map { date in
            let resolution = PrayerStateResolver.resolve(
                prayerTimes: schedule,
                now: date
            )
            PrayerResolverDiagnostics.emit(
                prayerTimes: schedule,
                now: date,
                resolution: resolution,
                surface: "ios.widget"
            )
            return PrayerTimelineEntry(
                date: date,
                nextPrayer: resolution.nextPrayer.prayer,
                nextPrayerScheduledTime: resolution.countdownTarget,
                currentPrayer: currentPrayerForDisplayedDay(
                    resolution.currentPrayer,
                    schedule: schedule
                ),
                todayPrayerTimes: schedule.dayPrayerTimes.map {
                    PrayerTimelineEntry.PrayerSlot(
                        prayer: $0.prayer,
                        scheduledTime: $0.scheduledTime
                    )
                },
                loggedStatusByPrayerRaw: logs,
                cityName: cache.cityName ?? "Current Location",
                timeZoneIdentifier: cache.timeZoneIdentifier,
                qiblaBearingDegrees: cache.qiblaBearingDegrees,
                isLocationMissing: false
            )
        }
    }

    private func isValid(
        cache: PrayerTimesCache,
        schedule: PrayerStateSchedule,
        at date: Date
    ) -> Bool {
        let resolution = PrayerStateResolver.resolve(prayerTimes: schedule, now: date)
        guard !resolution.isScheduleExhausted else { return false }
        guard let timeZone = TimeZone(identifier: cache.timeZoneIdentifier) else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.isDate(cache.date, inSameDayAs: schedule.fajr.scheduledTime)
            && calendar.isDate(date, inSameDayAs: cache.date)
    }

    private func currentPrayerForDisplayedDay(
        _ current: PrayerTime?,
        schedule: PrayerStateSchedule
    ) -> Prayer? {
        guard let current else { return nil }
        return schedule.dayPrayerTimes.contains(current) ? current.prayer : nil
    }

    private func openSharedContext() -> ModelContext? {
        guard let container = try? IhsanModelContainerFactory.makeContainer() else {
            return nil
        }
        return ModelContext(container)
    }

    private func readTodaysLogs(
        at referenceDate: Date,
        timeZoneIdentifier: String,
        from context: ModelContext
    ) -> [String: String] {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else { return [:] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let dayStart = calendar.startOfDay(for: referenceDate)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let descriptor = FetchDescriptor<PrayerLog>(
            predicate: #Predicate<PrayerLog> {
                $0.prayerDate >= dayStart && $0.prayerDate < dayEnd
            }
        )
        guard let logs = try? context.fetch(descriptor) else { return [:] }
        return logs.reduce(into: [:]) { result, log in
            result[log.prayerRaw] = log.statusRaw
        }
    }

    private func missingLocationEntry(at date: Date) -> PrayerTimelineEntry {
        let placeholder = PrayerTimelineEntry.placeholder(at: date)
        return PrayerTimelineEntry(
            date: date,
            nextPrayer: placeholder.nextPrayer,
            nextPrayerScheduledTime: placeholder.nextPrayerScheduledTime,
            currentPrayer: nil,
            todayPrayerTimes: placeholder.todayPrayerTimes,
            loggedStatusByPrayerRaw: [:],
            cityName: "Open Ihsan",
            timeZoneIdentifier: TimeZone.current.identifier,
            qiblaBearingDegrees: nil,
            isLocationMissing: true
        )
    }
}
