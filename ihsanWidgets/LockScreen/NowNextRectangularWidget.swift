import IhsanCore
import IhsanDesignSystem
import SwiftUI
import WidgetKit

/// Lock screen rectangular — now and next, two lines in the
/// inscription register.
struct NowNextRectangularWidgetView: View {
    let entry: PrayerTimelineEntry

    var body: some View {
        switch entry.content {
        case .live(let day):
            AccessoryNowNextFace(
                current: day.currentPrayer,
                next: day.nextPrayer,
                nextTime: day.nextPrayerTime,
                timeZoneIdentifier: day.timeZoneIdentifier
            )
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

struct NowNextRectangularWidget: Widget {
    static let kind: String = "NowNextRectangularWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: PrayerTimelineProvider()) { entry in
            NowNextRectangularWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.clear
                }
        }
        .configurationDisplayName("Now & Next")
        .description("The prayer standing now, and the one being waited for.")
        .supportedFamilies([.accessoryRectangular])
    }
}
