import AppIntents
import IhsanCore
import IhsanDesignSystem
import IhsanIntents
import SwiftUI
import WidgetKit

/// Medium (4×2). The day's arc.
///
/// The five ornaments set along a shallow arc at their true proportion
/// of the day, gilded behind you and outlined ahead. One prayer is
/// interactive: the current one, logged On Time through the same
/// intent every other surface uses. A prayer whose moment has passed
/// deserves the app's own sheet — its status is a question, and a
/// widget button that answered it silently would answer it wrong.
/// During an excused pause the arc shows times and nothing is a
/// button at all.
struct PrayerStatusMediumWidgetView: View {
    let entry: PrayerTimelineEntry

    @Environment(\.showsWidgetContainerBackground) private var showsContainer

    var body: some View {
        let tokens = WidgetPalette.tokens(for: entry)
        let isStandBy = !showsContainer
        let ink = isStandBy ? tokens.standByInk : tokens.ink
        let inkSecondary = isStandBy ? tokens.standByInkSecondary : tokens.inkSecondary

        Group {
            switch entry.content {
            case .live(let day):
                liveBody(day, tokens: tokens, ink: ink, inkSecondary: inkSecondary)
            case .invitation(let invitation):
                WidgetInvitationFace(
                    invitation: invitation, ink: ink, inkSecondary: inkSecondary
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(WidgetDeeplink.today)
    }

    @ViewBuilder
    private func liveBody(
        _ day: PrayerTimelineEntry.LiveDay,
        tokens: SkyPaletteTokens,
        ink: Color,
        inkSecondary: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.xs) {
            header(day, ink: ink, inkSecondary: inkSecondary)

            ZStack {
                WidgetPlate(day: day, date: entry.date, tokens: tokens, ornamentSize: 22)
                if !day.isPaused {
                    currentPrayerTapTarget(day)
                }
            }
            .frame(maxHeight: .infinity)
        }
    }

    private func header(
        _ day: PrayerTimelineEntry.LiveDay, ink: Color, inkSecondary: Color
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: IhsanSpacing.sm) {
            if let city = day.cityName {
                Text(city.uppercased())
                    .font(IhsanFont.inscription)
                    .tracking(1.0)
                    .foregroundStyle(inkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: IhsanSpacing.xs)

            Text(day.nextPrayer.displayNameEnglish)
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundStyle(ink)
            Text("in")
                .font(IhsanFont.inscription)
                .tracking(0.8)
                .foregroundStyle(inkSecondary)
            if let countdown = entry.nextPrayerCountdown {
                CountdownLabel.Compact(interval: countdown)
                    .foregroundStyle(ink)
            }
        }
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }

    /// One invisible button, over the current prayer's ornament,
    /// positioned by the same `ArcGeometry` that draws it — the two
    /// can no longer drift apart.
    @ViewBuilder
    private func currentPrayerTapTarget(_ day: PrayerTimelineEntry.LiveDay) -> some View {
        if let current = day.currentPrayer,
           let slot = day.slot(for: current),
           slot.status == nil {
            GeometryReader { proxy in
                let arc = ArcGeometry(size: proxy.size, ornamentSize: 22)
                if let span = arcSpan(day), span.end > span.start {
                    let t = CGFloat(
                        slot.scheduledTime.timeIntervalSince(span.start)
                            / span.end.timeIntervalSince(span.start)
                    )
                    let point = arc.point(at: min(max(t, 0), 1))
                    Button(intent: LogPrayerIntent(prayer: current)) {
                        Color.clear
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .position(point)
                    .accessibilityLabel("Log \(current.displayNameEnglish) on time")
                }
            }
        }
    }

    private func arcSpan(
        _ day: PrayerTimelineEntry.LiveDay
    ) -> (start: Date, end: Date)? {
        guard
            let first = day.slots.first?.scheduledTime,
            let last = day.slots.last?.scheduledTime,
            last > first
        else { return nil }
        return (first, last)
    }
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
        .description("The day's arc, with the current prayer one tap from logged.")
        .supportedFamilies([.systemMedium])
    }
}
