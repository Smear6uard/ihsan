import IhsanCore
import IhsanDesignSystem
import SwiftUI
import WidgetKit

/// The nightstand face.
///
/// StandBy is the app seen from a bed at three in the morning: sideways,
/// across a dark room, through Night Mode's red shift. Three
/// consequences shape everything here.
///
/// Nothing is white. Night Mode discards the blue and green channels,
/// and a bright white becomes a red glare with no character left in it;
/// warm parchment at 84% survives the tint and stays a colour. Nothing
/// is small — the type is set for a glance from across a room, not for
/// a phone in the hand. And nothing moves: a face that animates on a
/// nightstand is a light in a dark room.
///
/// What remains is the plate itself — the arc, the five ornaments, the
/// prayer being waited for. It is the surface most likely to be
/// photographed, and it should be the app at its most itself.
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

        VStack(alignment: .leading, spacing: 0) {
            if entry.isLocationMissing {
                Text("Open Ihsan")
                    .font(.system(size: 20, weight: .regular, design: .serif))
                    .foregroundStyle(ink)
                Text("to set your location")
                    .font(IhsanFont.inscription)
                    .tracking(1.0)
                    .foregroundStyle(inkSecondary)
            } else {
                Text(entry.nextPrayer.displayNameEnglish)
                    .font(.system(size: 24, weight: .regular, design: .serif))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(entry.clockTime(entry.nextPrayerScheduledTime))
                    .font(.system(size: 30, weight: .light, design: .rounded).monospacedDigit())
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(entry.currentPrayer == nil ? "NEXT" : "NEXT · NOW IN \(entry.currentPrayer!.displayNameEnglish.uppercased())")
                    .font(IhsanFont.inscription)
                    .tracking(1.4)
                    .foregroundStyle(inkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: IhsanSpacing.xs)

                WidgetPlate(entry: entry, tokens: tokens, ornamentSize: 17)
                    .frame(height: 34)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(WidgetDeeplink.today)
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
