import IhsanCore
import SwiftUI
import WidgetKit

/// Lock screen rectangular widget — "Asr in 1h 23m" with the
/// scheduled clock time below in tabular figures.
///
/// Lock screen widgets render with system-provided materials so the
/// content stays legible on both light and dark wallpapers. We use
/// outline SF Symbols and `.foregroundStyle(.primary/.secondary)`
/// rather than the bone-white opacity tiers used on home widgets.
struct NextPrayerRectangularWidgetView: View {
    let entry: PrayerTimelineEntry

    var body: some View {
        if entry.isLocationMissing {
            VStack(alignment: .leading, spacing: 2) {
                Label("Open Ihsan", systemImage: "moon.stars")
                    .font(.system(size: 15, weight: .semibold, design: .default))
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
                    Image(systemName: lockSymbol(for: entry.nextPrayer))
                        .font(.system(size: 13, weight: .regular))
                    Text(entry.nextPrayer.displayNameEnglish)
                        .font(.system(size: 14, weight: .semibold, design: .default))
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

    /// Outline SF Symbols variants — Apple's lock screen guidance prefers
    /// these over the filled glyphs used on the home widgets.
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
