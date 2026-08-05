import IhsanCore
import IhsanDesignSystem
import SwiftUI
import WidgetKit

/// The nightstand face.
///
/// StandBy is the app seen from a bed at three in the morning:
/// sideways, across a dark room, through Night Mode's red shift.
/// Nothing is white, nothing is small, nothing moves. What remains is
/// the plate itself — the arc, the five ornaments, the prayer being
/// waited for.
struct StandByPlateView: View {
    let entry: PrayerTimelineEntry

    @Environment(\.showsWidgetContainerBackground) private var showsContainer

    var body: some View {
        // On a home screen this widget still has to look right, so it
        // rides the day's palette there and pins to night in StandBy.
        let onNightstand = !showsContainer
        let tokens = onNightstand ? PaletteState.night.tokens : WidgetPalette.tokens(for: entry)
        let ink = onNightstand ? tokens.standByInk : tokens.ink
        let inkSecondary = onNightstand ? tokens.standByInkSecondary : tokens.inkSecondary

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
            Text(day.nextPrayer.displayNameEnglish)
                .font(.system(size: 24, weight: .regular, design: .serif))
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(day.clockTime(day.nextPrayerTime))
                .font(.system(size: 30, weight: .light, design: .rounded).monospacedDigit())
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(
                day.currentPrayer.map {
                    "NEXT · NOW IN \($0.displayNameEnglish.uppercased())"
                } ?? "NEXT"
            )
            .font(IhsanFont.inscription)
            .tracking(1.4)
            .foregroundStyle(inkSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            Spacer(minLength: IhsanSpacing.xs)

            WidgetPlate(day: day, date: entry.date, tokens: tokens, ornamentSize: 17)
                .frame(height: 34)
        }
        .accessibilityElement(children: .contain)
    }
}

struct StandByPlateWidget: Widget {
    static let kind: String = "StandByPlateWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: PrayerTimelineProvider()) { entry in
            StandByPlateView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetGround(entry: entry)
                }
        }
        .configurationDisplayName("Nightstand")
        .description("The day's arc and the next prayer, made for StandBy.")
        .supportedFamilies([.systemSmall])
    }
}
