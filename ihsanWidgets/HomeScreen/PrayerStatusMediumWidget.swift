import AppIntents
import IhsanCore
import IhsanDesignSystem
import IhsanIntents
import SwiftUI
import WidgetKit

/// Medium (4×2). The day's arc.
///
/// This is the app's signature at widget scale: the five ornaments set
/// along a shallow arc at their true proportion of the day, gilded
/// behind you and outlined ahead. The letter row that used to sit under
/// a row of dots — F D A M I — is gone; a shape that means Maghrib
/// needs no letter to say so, and the arc carries the day's shape in a
/// way five evenly spaced dots never could.
///
/// Every ornament is a tap target: pressing one logs that prayer
/// through the same intent every other surface uses.
struct PrayerStatusMediumWidgetView: View {
    let entry: PrayerTimelineEntry

    @Environment(\.showsWidgetContainerBackground) private var showsContainer

    var body: some View {
        let tokens = WidgetPalette.tokens(for: entry)
        let isStandBy = !showsContainer
        let ink = isStandBy ? tokens.standByInk : tokens.ink
        let inkSecondary = isStandBy ? tokens.standByInkSecondary : tokens.inkSecondary

        VStack(alignment: .leading, spacing: IhsanSpacing.xs) {
            header(ink: ink, inkSecondary: inkSecondary)

            if entry.isLocationMissing {
                Spacer(minLength: 0)
                Text("Open Ihsan to set your location")
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .foregroundStyle(inkSecondary)
                Spacer(minLength: 0)
            } else {
                ZStack {
                    WidgetPlate(entry: entry, tokens: tokens, ornamentSize: 22)
                    tapTargets
                }
                .frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(WidgetDeeplink.today)
    }

    private func header(ink: Color, inkSecondary: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: IhsanSpacing.sm) {
            Text(entry.cityName.uppercased())
                .font(IhsanFont.inscription)
                .tracking(1.0)
                .foregroundStyle(inkSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: IhsanSpacing.xs)

            if !entry.isLocationMissing {
                Text(entry.nextPrayer.displayNameEnglish)
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundStyle(ink)
                Text("in")
                    .font(IhsanFont.inscription)
                    .tracking(0.8)
                    .foregroundStyle(inkSecondary)
                CountdownLabel.Compact(until: entry.nextPrayerScheduledTime)
                    .foregroundStyle(ink)
            }
        }
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }

    /// Invisible buttons over each ornament. Drawing and touch are kept
    /// apart on purpose: an ornament that had to also be a button would
    /// have to grow a hit area, and the arc's spacing is information.
    private var tapTargets: some View {
        GeometryReader { proxy in
            let inset: CGFloat = 13
            let width = max(proxy.size.width - inset * 2, 1)
            let span = zip(
                entry.todayPrayerTimes.first?.scheduledTime,
                entry.todayPrayerTimes.last?.scheduledTime
            )

            ForEach(entry.todayPrayerTimes) { slot in
                if let span, span.1 > span.0 {
                    let t = CGFloat(
                        slot.scheduledTime.timeIntervalSince(span.0)
                            / span.1.timeIntervalSince(span.0)
                    )
                    Button(intent: LogPrayerIntent(prayer: slot.prayer)) {
                        Color.clear
                            .frame(width: 40, height: proxy.size.height)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .position(
                        x: inset + width * min(max(t, 0), 1),
                        y: proxy.size.height / 2
                    )
                    .accessibilityLabel("Log \(slot.prayer.displayNameEnglish) on time")
                }
            }
        }
    }
}

private func zip(_ a: Date?, _ b: Date?) -> (Date, Date)? {
    guard let a, let b else { return nil }
    return (a, b)
}

struct PrayerStatusMediumWidget: Widget {
    static let kind: String = "PrayerStatusMediumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: PrayerTimelineProvider()) { entry in
            PrayerStatusMediumWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetGround(entry: entry)
                }
        }
        .configurationDisplayName("Today's Prayers")
        .description("The day's arc, with every prayer one tap from logged.")
        .supportedFamilies([.systemMedium])
    }
}
