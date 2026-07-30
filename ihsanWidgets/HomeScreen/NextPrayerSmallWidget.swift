import IhsanCore
import IhsanDesignSystem
import SwiftUI
import WidgetKit

/// Small (2×2) home widget. Asymmetric layout:
/// - top-left: prayer symbol
/// - center-left: hero countdown (auto-updating, tabular)
/// - bottom-left: prayer name + scheduled time
/// - top-right: city label, small caps
struct NextPrayerSmallWidgetView: View {
    let entry: PrayerTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                PrayerSymbol(entry.nextPrayer, size: 18)
                Spacer()
                Text(entry.cityName.uppercased())
                    .font(IhsanFont.smallCaps)
                    .tracking(0.8)
                    .foregroundStyle(IhsanColor.textMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: IhsanSpacing.xxs)

            if entry.isLocationMissing {
                placeholderBody
            } else {
                CountdownLabel.Tabular(until: entry.nextPrayerScheduledTime, scale: 1.05)
                    .padding(.bottom, IhsanSpacing.xxs)

                Text(entry.nextPrayer.displayNameEnglish)
                    .font(IhsanFont.bodyEnglishBold)
                    .foregroundStyle(IhsanColor.textPrimary)

                Text("at \(entry.clockTime(entry.nextPrayerScheduledTime))")
                    .font(IhsanFont.smallCaps)
                    .tracking(0.6)
                    .foregroundStyle(IhsanColor.textMuted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(WidgetDeeplink.today)
    }

    @ViewBuilder
    private var placeholderBody: some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.xs) {
            Text("Open Ihsan")
                .font(IhsanFont.bodyEnglishBold)
                .foregroundStyle(IhsanColor.textPrimary)
            Text("to set your location")
                .font(IhsanFont.smallCaps)
                .tracking(0.6)
                .foregroundStyle(IhsanColor.textMuted)
        }
    }
}

struct NextPrayerSmallWidget: Widget {
    static let kind: String = "NextPrayerSmallWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: PrayerTimelineProvider()) { entry in
            NextPrayerSmallWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    ZStack {
                        IhsanColor.ground
                        Color.clear.ihsanGlass(intensity: .hero)
                    }
                }
        }
        .configurationDisplayName("Next Prayer")
        .description("Countdown to your next prayer.")
        .supportedFamilies([.systemSmall])
    }
}
