import IhsanCore
import IhsanDesignSystem
import SwiftUI
import WidgetKit

/// Lock screen fasting faces. On a fast day (any recorded fast, and
/// every Ramadan day) they carry the fast's two clocks; on other days
/// they stand in as the next-prayer face rather than an empty ring —
/// a widget slot should never spend a day saying nothing.

struct FastingCircularWidgetView: View {
    let entry: PrayerTimelineEntry

    var body: some View {
        switch entry.content {
        case .live(let day):
            let model = day.faceModel(at: entry.date)
            if let fasting = model.fasting {
                AccessoryFastingGaugeFace(fasting: fasting, date: entry.date)
            } else {
                AccessoryNextPrayerFace(
                    prayer: day.nextPrayer,
                    time: day.nextPrayerTime,
                    timeZoneIdentifier: day.timeZoneIdentifier,
                    isCurrent: day.currentPrayer == day.nextPrayer
                )
            }
        case .invitation:
            LockOrnament(prayer: .fajr, size: 22, isEmphasised: false)
                .widgetAccentable()
                .accessibilityLabel("Open Ihsan for today's times")
        }
    }
}

struct FastingCircularWidget: Widget {
    static let kind: String = "FastingCircularWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: PrayerTimelineProvider()) { entry in
            FastingCircularWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName("Fast")
        .description("On fasting days, the hours to iftar or suhoor; otherwise the next prayer.")
        .supportedFamilies([.accessoryCircular])
    }
}

struct FastingRectangularWidgetView: View {
    let entry: PrayerTimelineEntry

    var body: some View {
        switch entry.content {
        case .live(let day):
            let model = day.faceModel(at: entry.date)
            if let fasting = model.fasting {
                AccessoryFastingRectFace(
                    fasting: fasting,
                    date: entry.date,
                    timeZoneIdentifier: day.timeZoneIdentifier
                )
            } else {
                AccessoryNowNextFace(
                    current: day.currentPrayer,
                    next: day.nextPrayer,
                    nextTime: day.nextPrayerTime,
                    timeZoneIdentifier: day.timeZoneIdentifier
                )
            }
        case .invitation(let invitation):
            VStack(alignment: .leading, spacing: 2) {
                Text(invitation.title)
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .widgetAccentable()
                Text(invitation.line)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

struct FastingRectangularWidget: Widget {
    static let kind: String = "FastingRectangularWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: PrayerTimelineProvider()) { entry in
            FastingRectangularWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName("Fast")
        .description("On fasting days, iftar and suhoor with the time remaining.")
        .supportedFamilies([.accessoryRectangular])
    }
}
