import IhsanCore
import IhsanDesignSystem
import SwiftUI
import WidgetKit

/// Lock screen rectangular — the night. Between Maghrib and Fajr it
/// carries nisf al-layl and the last third's start; through the day
/// it quietly holds tonight's instants. The tahajjud widget.
struct NightRectangularWidgetView: View {
    let entry: PrayerTimelineEntry

    var body: some View {
        switch entry.content {
        case .live(let day):
            if let night = day.faceModel(at: entry.date).night {
                AccessoryNightFace(
                    night: night,
                    date: entry.date,
                    timeZoneIdentifier: day.timeZoneIdentifier
                )
            } else {
                // The snapshot's nights are exhausted — only possible
                // at the very edge of coverage.
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

struct NightRectangularWidget: Widget {
    static let kind: String = "NightRectangularWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: PrayerTimelineProvider()) { entry in
            NightRectangularWidgetView(entry: entry)
                .widgetURL(WidgetDeeplink.night)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName("The Night")
        .description("Nisf al-layl and the last third, for the one who rises.")
        .supportedFamilies([.accessoryRectangular])
    }
}
