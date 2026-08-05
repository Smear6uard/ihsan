import IhsanCore
import IhsanDesignSystem
import SwiftUI
import WidgetKit

/// Small (2×2). One illuminated initial: the next prayer's ornament,
/// its time as the primary numeral, the name in both scripts, a quiet
/// ticking line. Configurable to follow the day or to keep one prayer
/// in view.
struct NextPrayerSmallWidgetView: View {
    let entry: PrayerTimelineEntry

    @Environment(\.showsWidgetContainerBackground) private var showsContainer
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        let placement = WidgetPlacement(
            renderingMode: renderingMode, showsContainer: showsContainer
        )
        let tokens = WidgetPalette.tokens(for: entry)

        Group {
            switch entry.content {
            case .live(let day):
                NextPrayerFace(
                    model: day.faceModel(at: entry.date, fixedPrayer: entry.fixedPrayer),
                    tokens: tokens,
                    mode: placement.faceMode,
                    usesStandByInk: placement.isStandBy
                )
            case .invitation(let invitation):
                WidgetInvitationFace(
                    invitation: invitation,
                    ink: placement.isStandBy ? tokens.standByInk : tokens.ink,
                    inkSecondary: placement.isStandBy
                        ? tokens.standByInkSecondary : tokens.inkSecondary
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(WidgetDeeplink.today)
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
                .widgetAccentable()
            Text(invitation.line)
                .font(IhsanFont.inscription)
                .tracking(0.6)
                .foregroundStyle(inkSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(invitation.title) \(invitation.line)")
    }
}

struct NextPrayerSmallWidget: Widget {
    static let kind: String = "NextPrayerSmallWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind,
            intent: NextPrayerConfigurationIntent.self,
            provider: ConfigurablePrayerTimelineProvider()
        ) { entry in
            NextPrayerSmallWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetGround(entry: entry)
                }
        }
        .configurationDisplayName("Next Prayer")
        .description("The next prayer and its hour, on the day's sky.")
        .supportedFamilies([.systemSmall])
    }
}

/// The ground under a home widget: the plate's own sky ramp in full
/// colour, nothing in accented modes (the system owns those), and the
/// pinned night ramp on a nightstand.
struct WidgetGround: View {
    let entry: PrayerTimelineEntry

    @Environment(\.showsWidgetContainerBackground) private var showsContainer
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        let placement = WidgetPlacement(
            renderingMode: renderingMode, showsContainer: showsContainer
        )
        if placement.isStandBy {
            WidgetSkyGround(tokens: PaletteState.night.tokens, deepen: 0.5)
        } else {
            WidgetSkyGround(
                tokens: WidgetPalette.tokens(for: entry),
                mode: placement.faceMode
            )
        }
    }
}
