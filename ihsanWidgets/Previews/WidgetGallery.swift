#if DEBUG
import IhsanCore
import SwiftUI
import WidgetKit

// The widget gallery.
//
// Widgets cannot be driven by a UI test — they live on a home screen
// no test harness can arrange — so their acceptance is these previews
// plus the face render tests in IhsanDesignSystemTests. Every frame
// flows through the same composer and the same resolver as live data:
// only the snapshot is canonical.

private func entry(
    hour: Int, minute: Int = 0,
    mutate: ((WidgetSnapshot) -> WidgetSnapshot)? = nil
) -> PrayerTimelineEntry {
    let calendar = Calendar.current
    let dayStart = calendar.startOfDay(for: .now)
    var snapshot = GalleryDay.snapshot(anchoredTo: dayStart)
    if let mutate { snapshot = mutate(snapshot) }
    let instant = calendar.date(
        byAdding: DateComponents(hour: hour, minute: minute), to: dayStart
    ) ?? dayStart
    return WidgetTimelineComposer(snapshot: snapshot).entry(at: instant)
}

private let dawn = entry(hour: 4, minute: 35)
private let afternoon = entry(hour: 15, minute: 10)
private let night = entry(hour: 21, minute: 40)
private let invitation = PrayerTimelineEntry(
    date: .now,
    content: .invitation(.init(reason: .stale))
)
private let paused = entry(hour: 15, minute: 10) { snapshot in
    WidgetSnapshot(
        writtenAt: snapshot.writtenAt,
        timeZoneIdentifier: snapshot.timeZoneIdentifier,
        cityName: snapshot.cityName,
        qiblaBearingDegrees: snapshot.qiblaBearingDegrees,
        yesterdayIsha: snapshot.yesterdayIsha,
        today: snapshot.today,
        tomorrow: snapshot.tomorrow,
        dayAfterTomorrowFajr: snapshot.dayAfterTomorrowFajr,
        tonight: snapshot.tonight,
        tomorrowNight: snapshot.tomorrowNight,
        hijri: snapshot.hijri,
        fasting: snapshot.fasting,
        loggedStatusByPrayerRaw: [:],
        jamaahByPrayerRaw: [:],
        isPaused: true,
        pauseExpectedEnd: nil,
        qadaRemaining: nil
    )
}

#Preview("Small · dawn", as: .systemSmall) {
    NextPrayerSmallWidget()
} timeline: {
    dawn
}

#Preview("Small · night", as: .systemSmall) {
    NextPrayerSmallWidget()
} timeline: {
    night
}

#Preview("Small · invitation", as: .systemSmall) {
    NextPrayerSmallWidget()
} timeline: {
    invitation
}

#Preview("Hijri day", as: .systemSmall) {
    HijriDayWidget()
} timeline: {
    afternoon
}

#Preview("Medium · afternoon", as: .systemMedium) {
    PrayerStatusMediumWidget()
} timeline: {
    afternoon
}

#Preview("Medium · night", as: .systemMedium) {
    PrayerStatusMediumWidget()
} timeline: {
    night
}

#Preview("Medium · paused", as: .systemMedium) {
    PrayerStatusMediumWidget()
} timeline: {
    paused
}

#Preview("Large · afternoon", as: .systemLarge) {
    PrayerOverviewLargeWidget()
} timeline: {
    afternoon
}

#Preview("Large · dawn", as: .systemLarge) {
    PrayerOverviewLargeWidget()
} timeline: {
    dawn
}

#Preview("Lock · circular", as: .accessoryCircular) {
    PrayerProgressCircularWidget()
} timeline: {
    night
}

#Preview("Lock · rectangular", as: .accessoryRectangular) {
    NextPrayerRectangularWidget()
} timeline: {
    night
}

#Preview("Lock · inline", as: .accessoryInline) {
    NextPrayerInlineWidget()
} timeline: {
    night
}

/// The nightstand face. StandBy renders a `.systemSmall` widget
/// without its container background, which is the signal
/// `WidgetGround` uses to swap to the night ground and the capped ink.
#Preview("StandBy", as: .systemSmall) {
    StandByPlateWidget()
} timeline: {
    night
    dawn
}
#endif
