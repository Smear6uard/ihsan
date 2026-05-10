import SwiftUI
import WidgetKit
import IhsanCore
import IhsanDesignSystem

/// Corner complication: prayer name + relative countdown.
///
/// Uses `Text(_:style:.relative)` so the countdown text auto-updates
/// every minute without timeline regeneration. The complication still
/// gets a fresh timeline at each prayer transition so the *target*
/// prayer rolls forward (Fajr → Dhuhr → Asr …).
struct NextPrayerCornerWidget: Widget {
    let kind: String = "ihsan.complications.next-prayer-corner"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ComplicationProvider()) { entry in
            NextPrayerCornerView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Next Prayer")
        .description("Time until the next fardh prayer.")
        .supportedFamilies([.accessoryCorner])
    }
}

struct NextPrayerCornerView: View {
    let entry: ComplicationEntry

    var body: some View {
        if let prayer = entry.nextPrayer, let time = entry.nextPrayerTime {
            content(prayer: prayer, time: time)
        } else {
            Image(systemName: "moon.stars")
                .widgetAccentable()
        }
    }

    private func content(prayer: Prayer, time: Date) -> some View {
        // The corner family curves the *icon/text* slot automatically
        // when paired with `widgetLabel`. The label fills the inner
        // arc; we put the prayer's 3-letter mnemonic on the outside
        // and the relative countdown on the inside.
        let secondsRemaining = max(0, time.timeIntervalSince(entry.date))
        // Cap progress at 90 min so the gauge is meaningful for the
        // typical 15-90 min approach window.
        let progress = min(1.0, secondsRemaining / (90 * 60))

        return ZStack {
            AccessoryWidgetBackground()

            Text(prayer.displayNameEnglish.prefix(3).uppercased())
                .font(.system(size: 11, weight: .semibold))
        }
        .widgetLabel {
            Gauge(value: 1.0 - progress) {
                EmptyView()
            } currentValueLabel: {
                Text(time, style: .relative)
                    .monospacedDigit()
            }
            .gaugeStyle(.accessoryLinear)
        }
    }
}
