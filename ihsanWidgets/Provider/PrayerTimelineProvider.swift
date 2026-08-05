import Foundation
import IhsanCore
import WidgetKit

/// Drives every prayer widget family.
///
/// The provider reads the snapshot the host app published and nothing
/// else — no SwiftData, no CoreLocation, no calculation. The composer
/// places an entry on every boundary a face can change at and closes
/// the timeline with the invitation entry, so the reload policy is a
/// courtesy, not a correctness requirement: the app's own publish
/// path reloads all timelines on every mutation, and a reload that
/// never arrives leaves a dignified face, never a stale time.
struct PrayerTimelineProvider: TimelineProvider {
    typealias Entry = PrayerTimelineEntry

    func placeholder(in context: Context) -> PrayerTimelineEntry {
        galleryEntry()
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping @Sendable (PrayerTimelineEntry) -> Void
    ) {
        if context.isPreview {
            completion(galleryEntry())
            return
        }
        completion(WidgetTimelineComposer().entry(at: .now))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping @Sendable (Timeline<PrayerTimelineEntry>) -> Void
    ) {
        completion(WidgetTimelineComposer().timeline(from: .now))
    }

    /// The gallery frame: the canonical day at mid-afternoon, flowing
    /// through the same composer and resolver as live data.
    private func galleryEntry() -> PrayerTimelineEntry {
        let now = Date.now
        let snapshot = GalleryDay.snapshot(anchoredTo: now)
        // Mid-afternoon of the canonical day: Dhuhr logged behind,
        // Asr ahead — the state every widget face is designed around.
        let calendar = Calendar.current
        let display = calendar.date(
            byAdding: DateComponents(hour: 14, minute: 30),
            to: calendar.startOfDay(for: now)
        ) ?? now
        return WidgetTimelineComposer(snapshot: snapshot).entry(at: display)
    }
}
