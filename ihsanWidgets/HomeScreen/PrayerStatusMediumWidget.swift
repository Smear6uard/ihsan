import AppIntents
import IhsanCore
import IhsanDesignSystem
import IhsanIntents
import SwiftUI
import WidgetKit

/// Medium (4×2) home widget. Two columns:
/// - left: prayer symbol + countdown + prayer name + scheduled clock time
/// - right: today's five-prayer status row, each dot is a tappable
///   `Button(intent: LogPrayerIntent(prayer:))` that logs that prayer
///   as on-time when pressed
struct PrayerStatusMediumWidgetView: View {
    let entry: PrayerTimelineEntry

    var body: some View {
        HStack(alignment: .center, spacing: IhsanSpacing.lg) {
            countdownColumn

            divider

            statusColumn
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(WidgetDeeplink.today)
    }

    @ViewBuilder
    private var countdownColumn: some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.xs) {
            HStack(spacing: IhsanSpacing.sm) {
                PrayerSymbol(entry.nextPrayer, size: 18)
                Text(entry.cityName.uppercased())
                    .font(IhsanFont.smallCaps)
                    .tracking(0.8)
                    .foregroundStyle(IhsanColor.textMuted)
                    .lineLimit(1)
            }

            if entry.isLocationMissing {
                Text("Open Ihsan")
                    .font(IhsanFont.bodyEnglishBold)
                    .foregroundStyle(IhsanColor.textPrimary)
                Text("to set your location")
                    .font(IhsanFont.smallCaps)
                    .tracking(0.6)
                    .foregroundStyle(IhsanColor.textMuted)
            } else {
                CountdownLabel.Tabular(until: entry.nextPrayerScheduledTime, scale: 1.0)
                Text(entry.nextPrayer.displayNameEnglish)
                    .font(IhsanFont.bodyEnglishBold)
                    .foregroundStyle(IhsanColor.textSecondary)
                Text(entry.clockTime(entry.nextPrayerScheduledTime))
                    .font(IhsanFont.tabular)
                    .foregroundStyle(IhsanColor.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var divider: some View {
        Rectangle()
            .fill(IhsanColor.atmospheric)
            .frame(width: IhsanSpacing.hairline)
    }

    @ViewBuilder
    private var statusColumn: some View {
        VStack(alignment: .center, spacing: IhsanSpacing.sm) {
            Text("TODAY")
                .font(IhsanFont.smallCaps)
                .tracking(1.2)
                .foregroundStyle(IhsanColor.textMuted)

            HStack(spacing: IhsanSpacing.sm) {
                ForEach(entry.todayPrayerTimes) { slot in
                    statusDotButton(for: slot)
                }
            }

            HStack(spacing: IhsanSpacing.sm) {
                ForEach(entry.todayPrayerTimes) { slot in
                    Text(initial(for: slot.prayer))
                        .font(IhsanFont.smallCaps)
                        .tracking(0.6)
                        .foregroundStyle(
                            slot.prayer == entry.activePrayer
                                ? IhsanColor.textSecondary
                                : IhsanColor.textMuted
                        )
                        .frame(width: 22, alignment: .center)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func statusDotButton(for slot: PrayerTimelineEntry.PrayerSlot) -> some View {
        Button(intent: LogPrayerIntent(prayer: slot.prayer)) {
            PrayerStatusDot(
                prayer: slot.prayer,
                status: entry.loggedStatus(for: slot.prayer),
                isActive: slot.prayer == entry.activePrayer,
                size: 14
            )
            .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log \(slot.prayer.displayNameEnglish) on time")
    }

    private func initial(for prayer: Prayer) -> String {
        switch prayer {
        case .fajr: return "F"
        case .dhuhr: return "D"
        case .asr: return "A"
        case .maghrib: return "M"
        case .isha: return "I"
        }
    }
}

struct PrayerStatusMediumWidget: Widget {
    static let kind: String = "PrayerStatusMediumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: PrayerTimelineProvider()) { entry in
            PrayerStatusMediumWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    ZStack {
                        IhsanColor.ground
                        Color.clear.ihsanGlass(intensity: .regular)
                    }
                }
        }
        .configurationDisplayName("Today's Prayers")
        .description("Next prayer countdown and today's five-prayer status.")
        .supportedFamilies([.systemMedium])
    }
}
