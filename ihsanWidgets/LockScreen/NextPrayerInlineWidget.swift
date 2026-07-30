import IhsanCore
import SwiftUI
import WidgetKit

/// Lock screen inline — a single line above the clock.
///
/// The system allows one line of text and an optional leading image,
/// and renders both at text scale in the accented mode. At that size an
/// ornament is indistinguishable from a smudge, so this line is words
/// and figures only: "Asr · 4:32 PM". Nothing is lost — the shapes do
/// their work everywhere there is room for them.
struct NextPrayerInlineWidgetView: View {
    let entry: PrayerTimelineEntry

    var body: some View {
        if entry.isLocationMissing {
            Text("Open Ihsan to set location")
        } else {
            Text("\(entry.nextPrayer.displayNameEnglish) · \(entry.clockTime(entry.nextPrayerScheduledTime))")
                .font(.system(.body, design: .rounded).monospacedDigit())
        }
    }
}

struct NextPrayerInlineWidget: Widget {
    static let kind: String = "NextPrayerInlineWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: PrayerTimelineProvider()) { entry in
            NextPrayerInlineWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName("Next Prayer (Inline)")
        .description("Above the lock screen clock — minimal one-line prayer name and time.")
        .supportedFamilies([.accessoryInline])
    }
}
