import IhsanCore
import IhsanDesignSystem
import SwiftUI
import WidgetKit

/// Small (2×2). One ornament and one number.
///
/// At this size the arc would be five ornaments crowded into an inch,
/// so it is cut entirely: what a person wants from a 2×2 is which
/// prayer is next and how long. The ornament carries the identity — a
/// six-petal rosette or a ten-point star is unmistakably this app from
/// across a home screen, in a way a countdown never is.
struct NextPrayerSmallWidgetView: View {
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
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                PrayerMarkerOrnament(
                    prayer: day.nextPrayer,
                    size: 22,
                    state: day.currentPrayer == day.nextPrayer ? .current : .upcoming,
                    tokens: tokens
                )
                Spacer(minLength: IhsanSpacing.xs)
                if let city = day.cityName {
                    Text(city.uppercased())
                        .font(IhsanFont.inscription)
                        .tracking(0.8)
                        .foregroundStyle(inkSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }

            Spacer(minLength: IhsanSpacing.xxs)

            if let countdown = entry.nextPrayerCountdown {
                CountdownLabel.Tabular(interval: countdown, scale: 1.05)
                    .foregroundStyle(ink)
                    .padding(.bottom, IhsanSpacing.xxs)
            }

            Text(day.nextPrayer.displayNameEnglish)
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(day.clockTime(day.nextPrayerTime))
                .font(.system(.footnote, design: .rounded).monospacedDigit())
                .foregroundStyle(inkSecondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(day.nextPrayer.displayNameEnglish) at \(day.clockTime(day.nextPrayerTime))"
        )
    }
}

/// The one invitation face every widget family shares — quiet,
/// grounded on the same sky, and honest about why there are no times.
struct WidgetInvitationFace: View {
    let invitation: PrayerTimelineEntry.Invitation
    let ink: Color
    let inkSecondary: Color

    var body: some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.xs) {
            Text(invitation.title)
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .foregroundStyle(ink)
            Text(invitation.line)
                .font(IhsanFont.inscription)
                .tracking(0.6)
                .foregroundStyle(inkSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(invitation.title) \(invitation.line)")
    }
}

struct NextPrayerSmallWidget: Widget {
    static let kind: String = "NextPrayerSmallWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: PrayerTimelineProvider()) { entry in
            NextPrayerSmallWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetGround(entry: entry)
                }
        }
        .configurationDisplayName("Next Prayer")
        .description("Countdown to your next prayer.")
        .supportedFamilies([.systemSmall])
    }
}

/// The ground under a home widget, and the nightstand ground in
/// StandBy. One place, so every family drifts through the day together.
struct WidgetGround: View {
    let entry: PrayerTimelineEntry

    @Environment(\.showsWidgetContainerBackground) private var showsContainer

    var body: some View {
        if showsContainer {
            WidgetPalette.homeGround(for: entry)
        } else {
            WidgetPalette.standByGround()
        }
    }
}
