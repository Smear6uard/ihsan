import IhsanCore
import IhsanDesignSystem
import SwiftUI
import WidgetKit

/// Lock screen circular — the window gauge. The ring fills as the
/// current prayer's window elapses; the glance answers "how much of
/// the time I was given remains."
struct WindowGaugeCircularWidgetView: View {
    let entry: PrayerTimelineEntry

    var body: some View {
        switch entry.content {
        case .live(let day):
            AccessoryWindowGaugeFace(
                prayer: day.currentPrayer ?? day.nextPrayer,
                window: day.currentPrayer != nil ? day.currentWindow : nil,
                isCurrent: day.currentPrayer != nil
            )
        case .invitation:
            LockOrnament(prayer: .fajr, size: 22, isEmphasised: false)
                .widgetAccentable()
                .accessibilityLabel("Open Ihsan for today's prayer times")
        }
    }
}

struct WindowGaugeCircularWidget: Widget {
    static let kind: String = "WindowGaugeCircularWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: PrayerTimelineProvider()) { entry in
            WindowGaugeCircularWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName("Window Gauge")
        .description("How much of the current prayer's window remains.")
        .supportedFamilies([.accessoryCircular])
    }
}
