import IhsanCore
import IhsanDesignSystem
import SwiftUI
import WidgetKit

/// Large (4×4). The plate, miniature — the hero of the family. The
/// real sky, the day's arc with the sun or moon standing over it, and
/// the focused next-prayer block beneath the horizon filament.
struct PrayerOverviewLargeWidgetView: View {
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
                PlateFace(
                    model: day.faceModel(at: entry.date),
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .widgetURL(WidgetDeeplink.today)
    }
}

struct PrayerOverviewLargeWidget: Widget {
    static let kind: String = "PrayerOverviewLargeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: PrayerTimelineProvider()) { entry in
            PrayerOverviewLargeWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetGround(entry: entry)
                }
        }
        .configurationDisplayName("The Plate")
        .description("The day's sky and arc, and the next prayer beneath the horizon.")
        .supportedFamilies([.systemLarge])
    }
}
