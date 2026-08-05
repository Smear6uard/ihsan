import IhsanCore
import IhsanDesignSystem
import SwiftUI
import WidgetKit

/// Lock screen rectangular — "Asr in 1h 23m" with the scheduled clock
/// time below in tabular figures.
///
/// Lock Screen widgets render in a vibrant material that keeps shape
/// and throws away colour, so the prayer's own ornament is drawn as
/// linework and `.primary` / `.secondary` carry the emphasis. The
/// ornament and the prayer's name are the accent; the ticking timer
/// stays material so the emphasis sits on identity, not arithmetic.
struct NextPrayerRectangularWidgetView: View {
    let entry: PrayerTimelineEntry

    var body: some View {
        switch entry.content {
        case .live(let day):
            liveBody(day)
        case .invitation(let invitation):
            VStack(alignment: .leading, spacing: 2) {
                Text(invitation.title)
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .lineLimit(1)
                    .widgetAccentable()
                Text(invitation.line)
                    .font(.system(size: 11, weight: .regular, design: .default))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func liveBody(_ day: PrayerTimelineEntry.LiveDay) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                HStack(spacing: 5) {
                    LockOrnament(prayer: day.nextPrayer, size: 15, isEmphasised: true)
                    Text(day.nextPrayer.displayNameEnglish)
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                }
                .widgetAccentable()

                Text("in")
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundStyle(.secondary)
                if let countdown = entry.nextPrayerCountdown {
                    Text(timerInterval: countdown, countsDown: true)
                        .font(.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit())
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            Text(day.clockTime(day.nextPrayerTime))
                .font(.system(size: 12, weight: .regular, design: .rounded).monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(day.nextPrayer.displayNameEnglish) at \(day.clockTime(day.nextPrayerTime))"
        )
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
