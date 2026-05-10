import Foundation
import SwiftData
import WidgetKit
import IhsanCore

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
    let dayPrayerTimes: [Prayer: Date]
    let loggedStatuses: [Prayer: PrayerStatus]
    let cityName: String?
    let isStale: Bool
}

extension ComplicationEntry {
    static let placeholder = ComplicationEntry(
        date: .now,
        nextPrayer: .dhuhr,
        nextPrayerTime: .now.addingTimeInterval(3_600),
        dayPrayerTimes: [
            .fajr: .now.addingTimeInterval(-21_600),
            .dhuhr: .now.addingTimeInterval(3_600),
            .asr: .now.addingTimeInterval(14_400),
            .maghrib: .now.addingTimeInterval(28_800),
            .isha: .now.addingTimeInterval(36_000)
        ],
        loggedStatuses: [.fajr: .onTime],
        cityName: nil,
        isStale: false
    )

    static let stale = ComplicationEntry(
        date: .now,
        nextPrayer: nil,
        nextPrayerTime: nil,
        dayPrayerTimes: [:],
        loggedStatuses: [:],
        cityName: nil,
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
        guard let cache = PrayerTimesCacheStore.read() else {
            // No cache: one placeholder entry, ask system to retry in
            // an hour. The host app will populate the cache when next
            // opened, at which point we'll be reloaded explicitly.
            let entry = ComplicationEntry.stale
            completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(3_600))))
            return
        }

        let logs = (try? readTodaysLogs()) ?? [:]

        var transitions: [Date] = [now]
        for entry in cache.entries where entry.scheduledTime > now {
            transitions.append(entry.scheduledTime)
        }
        if let nextDayFajr = cache.nextDayFajr, nextDayFajr > now {
            transitions.append(nextDayFajr)
        }
        // Dedup + sort defensively.
        let sortedTransitions = Array(Set(transitions)).sorted()

        let entries: [ComplicationEntry] = sortedTransitions.compactMap { transition in
            buildEntry(
                at: transition,
                cache: cache,
                logs: logs
            )
        }

        // Refresh policy: re-ask for a timeline an hour after the
        // last entry. If the user opens the watch app in the meantime,
        // an explicit reload pre-empts this.
        let nextRefresh = sortedTransitions.last?.addingTimeInterval(3_600) ?? now.addingTimeInterval(3_600)
        completion(Timeline(entries: entries, policy: .after(nextRefresh)))
    }

    // MARK: - Entry construction

    private func buildEntry(at date: Date) -> ComplicationEntry? {
        guard let cache = PrayerTimesCacheStore.read() else { return nil }
        let logs = (try? readTodaysLogs()) ?? [:]
        return buildEntry(at: date, cache: cache, logs: logs)
    }

    private func buildEntry(
        at date: Date,
        cache: PrayerTimesCache,
        logs: [Prayer: PrayerStatus]
    ) -> ComplicationEntry {
        var times: [Prayer: Date] = [:]
        for entry in cache.entries {
            if let prayer = Prayer(rawValue: entry.prayerRaw) {
                times[prayer] = entry.scheduledTime
            }
        }

        // Find the next prayer relative to `date`. Prefer today's
        // remaining schedule; if all are past, fall back to tomorrow's
        // Fajr from the cache.
        let upcoming = cache.entries
            .compactMap { entry -> (Prayer, Date)? in
                guard let p = Prayer(rawValue: entry.prayerRaw) else { return nil }
                return (p, entry.scheduledTime)
            }
            .first(where: { $0.1 > date })

        let nextPair: (Prayer, Date)? = upcoming
            ?? cache.nextDayFajr.map { (Prayer.fajr, $0) }

        // Cache validity: if the cache's `date` (start-of-day) is
        // more than one day before today, mark stale so views can
        // hint the user to reopen the app.
        let cacheDay = Calendar.current.startOfDay(for: cache.date)
        let today = Calendar.current.startOfDay(for: date)
        let isStale = cacheDay.distance(to: today) > 86_400

        return ComplicationEntry(
            date: date,
            nextPrayer: nextPair?.0,
            nextPrayerTime: nextPair?.1,
            dayPrayerTimes: times,
            loggedStatuses: logs,
            cityName: cache.cityName,
            isStale: isStale
        )
    }

    // MARK: - SwiftData

    private func readTodaysLogs() throws -> [Prayer: PrayerStatus] {
        // Spin up the same App-Group + CloudKit container the host
        // app uses. Widget extensions can open SwiftData containers;
        // the cost is real but bounded, and prayer log volume is
        // tiny (single-digit rows per day).
        let container = try IhsanModelContainerFactory.makeContainer(inMemory: false)
        let context = ModelContext(container)
        let startOfDay = Calendar.current.startOfDay(for: .now)
        let descriptor = FetchDescriptor<PrayerLog>(
            predicate: #Predicate { $0.prayerDate == startOfDay }
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
