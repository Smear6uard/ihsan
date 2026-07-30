#if DEBUG
import IhsanCore
import SwiftUI
import WidgetKit

// The widget gallery.
//
// Widgets cannot be driven by a UI test — they live on a home screen no
// test harness can arrange — so their acceptance is these previews,
// each pinned to a real moment of a real day so the ground, the
// ornament states, and the arc spacing are all the ones that actually
// ship.

/// A day in Chicago, mid-July: Fajr 4:10, sunrise 5:42, Dhuhr 12:58,
/// Asr 4:53, Maghrib 8:11, Isha 9:43 — the same day every other gallery
/// frame in this repo uses.
private func chicagoEntry(
    at hour: Int,
    minute: Int = 0,
    logged: [Prayer: PrayerStatus] = [:]
) -> PrayerTimelineEntry {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Chicago")!
    let day = calendar.date(from: DateComponents(year: 2026, month: 7, day: 30))!

    func at(_ h: Int, _ m: Int) -> Date {
        calendar.date(byAdding: DateComponents(hour: h, minute: m), to: day)!
    }

    let slots: [PrayerTimelineEntry.PrayerSlot] = [
        .init(prayer: .fajr, scheduledTime: at(4, 10)),
        .init(prayer: .dhuhr, scheduledTime: at(12, 58)),
        .init(prayer: .asr, scheduledTime: at(16, 53)),
        .init(prayer: .maghrib, scheduledTime: at(20, 11)),
        .init(prayer: .isha, scheduledTime: at(21, 43))
    ]
    let now = at(hour, minute)

    // The prayer whose window contains `now`, resolved the same way
    // every surface resolves it: the last one that has started.
    let current = slots.last { $0.scheduledTime <= now }
    let isForenoonGap = now >= at(5, 42) && now < at(12, 58)
    let next = slots.first { $0.scheduledTime > now }

    return PrayerTimelineEntry(
        date: now,
        nextPrayer: next?.prayer ?? .fajr,
        nextPrayerScheduledTime: next?.scheduledTime ?? at(28, 10),
        currentPrayer: isForenoonGap ? nil : current?.prayer,
        todayPrayerTimes: slots,
        sunrise: at(5, 42),
        loggedStatusByPrayerRaw: logged.reduce(into: [:]) { $0[$1.key.rawValue] = $1.value.rawValue },
        cityName: "Chicago",
        timeZoneIdentifier: "America/Chicago",
        qiblaBearingDegrees: 48.6,
        isLocationMissing: false
    )
}

private let nightEntry = chicagoEntry(
    at: 21, minute: 40,
    logged: [.fajr: .onTime, .dhuhr: .onTime, .asr: .late, .maghrib: .onTime]
)
private let dawnEntry = chicagoEntry(at: 4, minute: 35)
private let afternoonEntry = chicagoEntry(
    at: 15, minute: 10,
    logged: [.fajr: .onTime, .dhuhr: .onTime]
)

#Preview("Small · night", as: .systemSmall) {
    NextPrayerSmallWidget()
} timeline: {
    nightEntry
}

#Preview("Small · dawn", as: .systemSmall) {
    NextPrayerSmallWidget()
} timeline: {
    dawnEntry
}

#Preview("Medium · night", as: .systemMedium) {
    PrayerStatusMediumWidget()
} timeline: {
    nightEntry
}

#Preview("Medium · afternoon", as: .systemMedium) {
    PrayerStatusMediumWidget()
} timeline: {
    afternoonEntry
}

#Preview("Large · night", as: .systemLarge) {
    PrayerOverviewLargeWidget()
} timeline: {
    nightEntry
}

#Preview("Large · dawn", as: .systemLarge) {
    PrayerOverviewLargeWidget()
} timeline: {
    dawnEntry
}

#Preview("Lock · circular", as: .accessoryCircular) {
    PrayerProgressCircularWidget()
} timeline: {
    nightEntry
}

#Preview("Lock · rectangular", as: .accessoryRectangular) {
    NextPrayerRectangularWidget()
} timeline: {
    nightEntry
}

#Preview("Lock · inline", as: .accessoryInline) {
    NextPrayerInlineWidget()
} timeline: {
    nightEntry
}

/// The nightstand face. StandBy renders a `.systemSmall` widget without
/// its container background, which is the signal `WidgetGround` uses to
/// swap to the night ground and the capped ink.
#Preview("StandBy", as: .systemSmall) {
    StandByPlateWidget()
} timeline: {
    nightEntry
    dawnEntry
}
#endif
