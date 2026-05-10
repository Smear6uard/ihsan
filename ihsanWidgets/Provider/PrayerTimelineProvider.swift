import Foundation
import WidgetKit

/// Drives all six widget families.
///
/// Refresh strategy: emit one entry "now" plus one entry at every
/// upcoming prayer transition for the next 24 hours (5 today's + 1
/// tomorrow's Fajr). The countdown text inside each entry uses
/// `Text(_:style: .timer)` so the visible "1h 23m" updates without
/// rebuilding the timeline. The timeline reloads at the last entry
/// (`.atEnd`) which lands at tomorrow's Fajr — at that moment we
/// recompute the next 24h.
///
/// This minimizes timeline rebuilds (≤ 1/day under steady state) while
/// guaranteeing the "next prayer" label flips at the exact transition
/// boundary, never stale.
struct PrayerTimelineProvider: TimelineProvider {
    typealias Entry = PrayerTimelineEntry

    func placeholder(in context: Context) -> PrayerTimelineEntry {
        PrayerTimelineEntry.placeholder()
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping @Sendable (PrayerTimelineEntry) -> Void
    ) {
        Task { @MainActor in
            // Gallery uses a non-redacted preview entry; live snapshot
            // returns the most recent real entry from the loader.
            if context.isPreview {
                completion(PrayerTimelineEntry.placeholder())
                return
            }
            let loader = WidgetSnapshotLoader()
            let entries = loader.entries(starting: .now)
            completion(entries.first ?? PrayerTimelineEntry.placeholder())
        }
    }

    func getTimeline(
        in context: Context,
        completion: @escaping @Sendable (Timeline<PrayerTimelineEntry>) -> Void
    ) {
        Task { @MainActor in
            let loader = WidgetSnapshotLoader()
            let entries = loader.entries(starting: .now)
            // `.atEnd` reloads when the system surfaces the final entry;
            // that entry's date is tomorrow's Fajr, so the new timeline
            // build picks up tomorrow's prayer times automatically.
            let policy: TimelineReloadPolicy = .atEnd
            completion(Timeline(entries: entries, policy: policy))
        }
    }
}
