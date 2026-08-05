import IhsanCore
import IhsanDesignSystem
import SwiftUI
import WidgetKit

/// Small (2×2). The Hijri day as an inscription plate, with the
/// significant-day line when the calendar carries one.
struct HijriDayWidgetView: View {
    let entry: PrayerTimelineEntry

    @Environment(\.showsWidgetContainerBackground) private var showsContainer
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        let placement = WidgetPlacement(
            renderingMode: renderingMode, showsContainer: showsContainer
        )
        let tokens = WidgetPalette.tokens(for: entry)

        Group {
            if case .live(let day) = entry.content,
               let hijri = day.faceModel(at: entry.date).hijri {
                HijriDayFace(
                    hijri: hijri,
                    tokens: tokens,
                    mode: placement.faceMode,
                    usesStandByInk: placement.isStandBy
                )
            } else {
                // Missing snapshot or a snapshot without Hijri facts —
                // the invitation, never a guessed date.
                WidgetInvitationFace(
                    invitation: .init(reason: invitationReason),
                    ink: placement.isStandBy ? tokens.standByInk : tokens.ink,
                    inkSecondary: placement.isStandBy
                        ? tokens.standByInkSecondary : tokens.inkSecondary
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(WidgetDeeplink.hijri)
    }

    private var invitationReason: PrayerTimelineEntry.Invitation.Reason {
        if case .invitation(let invitation) = entry.content {
            return invitation.reason
        }
        return .stale
    }
}

struct HijriDayWidget: Widget {
    static let kind: String = "HijriDayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: PrayerTimelineProvider()) { entry in
            HijriDayWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetGround(entry: entry)
                }
        }
        .configurationDisplayName("Hijri Day")
        .description("Today's Hijri date, and the days worth knowing.")
        .supportedFamilies([.systemSmall])
    }
}
