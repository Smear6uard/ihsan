import IhsanCore
import IhsanDesignSystem
import SwiftUI
import WidgetKit

/// Lock screen rectangular widget — "Asr in 1h 23m" with the
/// scheduled clock time below in tabular figures.
///
/// Lock Screen widgets render in an accented mode that keeps shape and
/// throws away colour, so the prayer's own ornament is drawn as
/// linework and `.primary` / `.secondary` carry the emphasis. No SF
/// Symbol stands in for a prayer here any more than it does on the
/// plate.
struct NextPrayerRectangularWidgetView: View {
    let entry: PrayerTimelineEntry

    var body: some View {
        if entry.isLocationMissing {
            VStack(alignment: .leading, spacing: 2) {
                Text("Open Ihsan")
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .lineLimit(1)
                Text("Set your location")
                    .font(.system(size: 11, weight: .regular, design: .default))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .widgetAccentable()
        } else {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    LockOrnament(prayer: entry.nextPrayer, size: 13, isEmphasised: true)
                    Text(entry.nextPrayer.displayNameEnglish)
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                    Text("in")
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .foregroundStyle(.secondary)
                    Text(timerInterval: .now...entry.nextPrayerScheduledTime, countsDown: true)
                        .font(.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit())
                }
                .widgetAccentable()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

                Text(entry.clockTime(entry.nextPrayerScheduledTime))
                    .font(.system(size: 12, weight: .regular, design: .rounded).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

}

struct NextPrayerRectangularWidget: Widget {
    static let kind: String = "NextPrayerRectangularWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: PrayerTimelineProvider()) { entry in
            NextPrayerRectangularWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName("Next Prayer")
        .description("Above the lock screen clock — countdown to your next prayer.")
        .supportedFamilies([.accessoryRectangular])
    }
}
