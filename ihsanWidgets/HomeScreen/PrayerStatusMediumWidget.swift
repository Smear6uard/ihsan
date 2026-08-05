import AppIntents
import IhsanCore
import IhsanDesignSystem
import IhsanIntents
import SwiftUI
import WidgetKit

/// Medium (4×2). The day strip: five ornaments along the day's arc
/// with their times inscribed beneath, the current prayer one tap
/// from logged On Time. A passed prayer's status is a question — its
/// mark deep-links into the app's sheet instead of answering it
/// silently. During an excused pause nothing is a button.
struct PrayerStatusMediumWidgetView: View {
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
                let model = day.faceModel(at: entry.date)
                ZStack(alignment: .topLeading) {
                    DayStripFace(
                        model: model,
                        tokens: tokens,
                        mode: placement.faceMode,
                        usesStandByInk: placement.isStandBy
                    )
                    if !model.isPaused {
                        stripTapTargets(model)
                    }
                }
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

    /// The strip's touch layer, laid with the exact geometry that
    /// draws the ornaments. The current unlogged prayer carries the
    /// one intent button; a passed unlogged mark links into the app's
    /// sheet, where the status question is asked properly.
    private func stripTapTargets(_ model: WidgetDayModel) -> some View {
        VStack(spacing: IhsanSpacing.xxs) {
            // Mirror the face's header height so the geometry below
            // matches the band the ornaments were drawn in.
            Color.clear.frame(height: 18)
            GeometryReader { proxy in
                let band = CGSize(width: proxy.size.width, height: proxy.size.height - 28)
                let centers = DayStripFace.ornamentCenters(slots: model.slots, in: band)

                ForEach(Array(model.slots.enumerated()), id: \.element.id) { index, slot in
                    if index < centers.count {
                        target(for: slot)
                            .position(centers[index])
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func target(for slot: WidgetDayModel.Slot) -> some View {
        switch slot.state {
        case .current:
            Button(intent: LogPrayerIntent(prayer: slot.prayer)) {
                Color.clear
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Log \(slot.prayer.displayNameEnglish) on time")
        case .passedUnlogged:
            Link(destination: WidgetDeeplink.logSheet(for: slot.prayer)) {
                Color.clear
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Open \(slot.prayer.displayNameEnglish) in Ihsan")
        case .logged, .upcoming:
            Color.clear.frame(width: 1, height: 1)
        }
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
        .configurationDisplayName("The Day Strip")
        .description("All five prayers on the day's arc, the current one a tap from logged.")
        .supportedFamilies([.systemMedium])
    }
}
