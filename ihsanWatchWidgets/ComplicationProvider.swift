import Foundation
import SwiftData
import WidgetKit
import IhsanCore
import IhsanPrayerTimes

/// Single shared timeline provider that all three complications
/// consume. Each entry carries enough context to render any of the
/// three families — corner (next prayer countdown), circular
/// (5-segment ring), rectangular (full prayer list).
///
/// Energy/budget notes:
/// - We do NOT spin up CoreLocation here; we read the day's prayer
///   schedule from `PrayerTimesCacheStore`, populated by the watch
///   app on every snapshot refresh. If the cache is stale or missing
///   the timeline returns a single placeholder entry that the views
///   render as "Open Ihsan".
/// - We DO open the SwiftData ModelContainer to read today's
///   `PrayerLog` rows (so the rectangular and circular variants can
///   reflect logged statuses). The widget extension shares the same
///   App-Group + CloudKit container as the host app.
/// - Timeline entries are bounded to today's prayer transitions
///   plus tomorrow's Fajr, capping refresh budget at ~6 entries/day.
struct ComplicationEntry: TimelineEntry {
    let date: Date
    let nextPrayer: Prayer?
    let nextPrayerTime: Date?
    let currentPrayer: Prayer?
    let dayPrayerTimes: [Prayer: Date]
    let loggedStatuses: [Prayer: PrayerStatus]
    let cityName: String?
    let timeZoneIdentifier: String
    let isStale: Bool
}

extension ComplicationEntry {
    static let placeholder = ComplicationEntry(
        date: .now,
        nextPrayer: .dhuhr,
        nextPrayerTime: .now.addingTimeInterval(3_600),
        currentPrayer: nil,
        dayPrayerTimes: [
            .fajr: .now.addingTimeInterval(-21_600),
            .dhuhr: .now.addingTimeInterval(3_600),
            .asr: .now.addingTimeInterval(14_400),
            .maghrib: .now.addingTimeInterval(28_800),
            .isha: .now.addingTimeInterval(36_000)
        ],
        loggedStatuses: [.fajr: .onTime],
        cityName: nil,
        timeZoneIdentifier: TimeZone.current.identifier,
        isStale: false
    )

    static let stale = ComplicationEntry(
        date: .now,
        nextPrayer: nil,
        nextPrayerTime: nil,
        currentPrayer: nil,
        dayPrayerTimes: [:],
        loggedStatuses: [:],
        cityName: nil,
        timeZoneIdentifier: TimeZone.current.identifier,
        isStale: true
    )
}

struct ComplicationProvider: TimelineProvider {
    typealias Entry = ComplicationEntry

    func placeholder(in context: Context) -> Entry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(buildEntry(at: .now) ?? .stale)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let now = Date.now
        guard
            let cache = PrayerTimesCacheStore.read(),
            let schedule = cache.resolverSchedule
        else {
            // No cache: one placeholder entry, ask system to retry in
            // an hour. The host app will populate the cache when next
            // opened, at which point we'll be reloaded explicitly.
            let entry = ComplicationEntry.stale
            completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(3_600))))
            return
        }

        let logs = (try? readTodaysLogs(at: now, timeZoneIdentifier: cache.timeZoneIdentifier)) ?? [:]

        var transitions: [Date] = [now]
        let boundaries = [
            schedule.fajr.scheduledTime, schedule.sunrise,
            schedule.dhuhr.scheduledTime, schedule.asr.scheduledTime,
            schedule.maghrib.scheduledTime, schedule.isha.scheduledTime
        ]
        transitions.append(contentsOf: boundaries.filter { $0 > now })
        // Dedup + sort defensively.
        let sortedTransitions = Array(Set(transitions)).sorted()

        let entries: [ComplicationEntry] = sortedTransitions.compactMap { transition in
            buildEntry(
                at: transition,
                cache: cache,
                schedule: schedule,
                logs: logs
            )
        }

        // Refresh policy: re-ask for a timeline an hour after the
        // last entry. If the user opens the watch app in the meantime,
        // an explicit reload pre-empts this.
        let nextRefresh = schedule.tomorrowFajr.scheduledTime > now
            ? schedule.tomorrowFajr.scheduledTime
            : now.addingTimeInterval(3_600)
        completion(Timeline(entries: entries, policy: .after(nextRefresh)))
    }

    // MARK: - Entry construction

    private func buildEntry(at date: Date) -> ComplicationEntry? {
        guard let cache = PrayerTimesCacheStore.read() else { return nil }
        guard let schedule = cache.resolverSchedule else { return nil }
        let logs = (try? readTodaysLogs(at: date, timeZoneIdentifier: cache.timeZoneIdentifier)) ?? [:]
        return buildEntry(at: date, cache: cache, schedule: schedule, logs: logs)
    }

    private func buildEntry(
        at date: Date,
        cache: PrayerTimesCache,
        schedule: PrayerStateSchedule,
        logs: [Prayer: PrayerStatus]
    ) -> ComplicationEntry {
        var times: [Prayer: Date] = [:]
        for entry in cache.entries {
            if let prayer = Prayer(rawValue: entry.prayerRaw) {
                times[prayer] = entry.scheduledTime
            }
        }

        let resolution = PrayerStateResolver.resolve(
            prayerTimes: schedule,
            now: date
        )
        PrayerResolverDiagnostics.emit(
            prayerTimes: schedule,
            now: date,
            resolution: resolution,
            surface: "watch.complication"
        )

        // Cache validity: if the cache's `date` (start-of-day) is
        // more than one day before today, mark stale so views can
        // hint the user to reopen the app.
        let isStale = resolution.isScheduleExhausted
        let displayedCurrent = resolution.currentPrayer.flatMap {
            schedule.dayPrayerTimes.contains($0) ? $0.prayer : nil
        }

        return ComplicationEntry(
            date: date,
            nextPrayer: resolution.nextPrayer.prayer,
            nextPrayerTime: resolution.countdownTarget,
            currentPrayer: displayedCurrent,
            dayPrayerTimes: times,
            loggedStatuses: logs,
            cityName: cache.cityName,
            timeZoneIdentifier: cache.timeZoneIdentifier,
            isStale: isStale
        )
    }

    // MARK: - SwiftData

    private func readTodaysLogs(
        at date: Date,
        timeZoneIdentifier: String
    ) throws -> [Prayer: PrayerStatus] {
        // Spin up the same App-Group + CloudKit container the host
        // app uses. Widget extensions can open SwiftData containers;
        // the cost is real but bounded, and prayer log volume is
        // tiny (single-digit rows per day).
        let container = try IhsanModelContainerFactory.makeContainer(inMemory: false)
        let context = ModelContext(container)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        let descriptor = FetchDescriptor<PrayerLog>(
            predicate: #Predicate {
                $0.prayerDate >= startOfDay && $0.prayerDate < endOfDay
            }
        )
        let logs = try context.fetch(descriptor)
        var map: [Prayer: PrayerStatus] = [:]
        for log in logs {
            if let prayer = log.prayer, let status = log.status {
                map[prayer] = status
            }
        }
        return map
    }
}
