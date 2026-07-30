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

        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                PrayerMarkerOrnament(
                    prayer: entry.nextPrayer,
                    size: 22,
                    state: entry.currentPrayer == entry.nextPrayer ? .current : .upcoming,
                    tokens: tokens
                )
                Spacer(minLength: IhsanSpacing.xs)
                Text(entry.cityName.uppercased())
                    .font(IhsanFont.inscription)
                    .tracking(0.8)
                    .foregroundStyle(inkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: IhsanSpacing.xxs)

            if entry.isLocationMissing {
                placeholderBody(ink: ink, inkSecondary: inkSecondary)
            } else {
                CountdownLabel.Tabular(until: entry.nextPrayerScheduledTime, scale: 1.05)
                    .foregroundStyle(ink)
                    .padding(.bottom, IhsanSpacing.xxs)

                Text(entry.nextPrayer.displayNameEnglish)
                    .font(.system(size: 17, weight: .semibold, design: .serif))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(entry.clockTime(entry.nextPrayerScheduledTime))
                    .font(.system(.footnote, design: .rounded).monospacedDigit())
                    .foregroundStyle(inkSecondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(WidgetDeeplink.today)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            entry.isLocationMissing
                ? "Open Ihsan to set your location"
                : "\(entry.nextPrayer.displayNameEnglish) at \(entry.clockTime(entry.nextPrayerScheduledTime))"
        )
    }

    @ViewBuilder
    private func placeholderBody(ink: Color, inkSecondary: Color) -> some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.xs) {
            Text("Open Ihsan")
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .foregroundStyle(ink)
            Text("to set your location")
                .font(IhsanFont.inscription)
                .tracking(0.6)
                .foregroundStyle(inkSecondary)
        }
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
            WidgetPalette.standByGround(for: entry)
        }
    }
}
