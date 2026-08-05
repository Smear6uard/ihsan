import IhsanCore
import SwiftUI
import WidgetKit

/// Lock screen inline — a single line above the clock.
///
/// The system allows one line of text and an optional leading image,
/// and renders both at text scale in the accented mode. At that size
/// an ornament is indistinguishable from a smudge, so this line is
/// words and figures only: "Asr · 4:32 PM".
struct NextPrayerInlineWidgetView: View {
    let entry: PrayerTimelineEntry

    var body: some View {
        switch entry.content {
        case .live(let day):
            Text("\(day.nextPrayer.displayNameEnglish) · \(day.clockTime(day.nextPrayerTime))")
                .font(.system(.body, design: .rounded).monospacedDigit())
        case .invitation(let invitation):
            Text("\(invitation.title) \(invitation.line)")
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
        .description("Above the lock screen clock — the next prayer's name and time.")
        .supportedFamilies([.accessoryInline])
    }
}
