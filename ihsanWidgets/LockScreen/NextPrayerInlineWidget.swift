import IhsanCore
import SwiftUI
import WidgetKit

/// Lock screen inline widget — single line above the clock.
/// "☼ Asr · 4:32 PM" in the inline accessory family. The system
/// constrains this to a single line of text and an optional leading
/// SF Symbol. Tabular figures keep the digits from jittering.
struct NextPrayerInlineWidgetView: View {
    let entry: PrayerTimelineEntry

    var body: some View {
        if entry.isLocationMissing {
            Label("Open Ihsan to set location", systemImage: "moon.stars")
        } else {
            Label {
                Text("\(entry.nextPrayer.displayNameEnglish) · \(WidgetCountdown.clockTime(entry.nextPrayerScheduledTime))")
                    .font(.system(.body, design: .rounded).monospacedDigit())
            } icon: {
                Image(systemName: lockSymbol(for: entry.nextPrayer))
            }
        }
    }

    private func lockSymbol(for prayer: Prayer) -> String {
        switch prayer {
        case .fajr: return "sunrise"
        case .dhuhr: return "sun.max"
        case .asr: return "sun.haze"
        case .maghrib: return "sunset"
        case .isha: return "moon.stars"
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
