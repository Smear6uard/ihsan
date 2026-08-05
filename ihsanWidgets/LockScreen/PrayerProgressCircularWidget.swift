import IhsanCore
import IhsanDesignSystem
import SwiftUI
import WidgetKit

/// Lock screen circular — the next prayer's ornament over its hour.
///
/// This kind used to render five fill-as-you-log segments; a count of
/// worship is a score, and this app does not keep score. The kind is
/// kept so placed widgets survive the rebuild; the face is now the
/// app's mark and the one fact a circle can carry.
struct NextPrayerCircularWidgetView: View {
    let entry: PrayerTimelineEntry

    var body: some View {
        switch entry.content {
        case .live(let day):
            AccessoryNextPrayerFace(
                prayer: entry.fixedPrayer ?? day.nextPrayer,
                time: displayTime(day),
                timeZoneIdentifier: day.timeZoneIdentifier,
                isCurrent: day.currentPrayer == (entry.fixedPrayer ?? day.nextPrayer)
            )
        case .invitation:
            LockOrnament(prayer: .fajr, size: 22, isEmphasised: false)
                .widgetAccentable()
                .accessibilityLabel("Open Ihsan for today's prayer times")
        }
    }

    private func displayTime(_ day: PrayerTimelineEntry.LiveDay) -> Date {
        if let fixed = entry.fixedPrayer,
           let occurrence = day.nextOccurrenceByPrayerRaw[fixed.rawValue] {
            return occurrence
        }
        return day.nextPrayerTime
    }
}

struct NextPrayerCircularWidget: Widget {
    static let kind: String = "PrayerProgressCircularWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind,
            intent: NextPrayerConfigurationIntent.self,
            provider: ConfigurablePrayerTimelineProvider()
        ) { entry in
            NextPrayerCircularWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName("Next Prayer")
        .description("The next prayer's mark and hour.")
        .supportedFamilies([.accessoryCircular])
    }
}
