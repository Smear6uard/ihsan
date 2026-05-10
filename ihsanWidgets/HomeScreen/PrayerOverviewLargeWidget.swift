import AppIntents
import IhsanCore
import IhsanDesignSystem
import IhsanIntents
import SwiftUI
import WidgetKit

/// Large (4×4) home widget. Hero band on top (countdown + qibla
/// indicator), full prayer list below. Each prayer row is a
/// `Button(intent: LogPrayerIntent(prayer:))` that logs that prayer
/// as on-time when pressed.
///
/// The qibla indicator at top-right is a `Link` into the app with the
/// "open qibla sheet" deeplink stamped to App Group `UserDefaults`.
struct PrayerOverviewLargeWidgetView: View {
    let entry: PrayerTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.md) {
            heroBand
            divider
            prayerList
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .widgetURL(WidgetDeeplink.today)
    }

    @ViewBuilder
    private var heroBand: some View {
        HStack(alignment: .top, spacing: IhsanSpacing.md) {
            VStack(alignment: .leading, spacing: IhsanSpacing.xxs) {
                Text(entry.cityName.uppercased())
                    .font(IhsanFont.smallCaps)
                    .tracking(1.2)
                    .foregroundStyle(IhsanColor.textMuted)
                    .lineLimit(1)
                if entry.isLocationMissing {
                    Text("Open Ihsan to set location")
                        .font(IhsanFont.bodyEnglishBold)
                        .foregroundStyle(IhsanColor.textPrimary)
                        .padding(.top, IhsanSpacing.xs)
                } else {
                    CountdownLabel.Hero(until: entry.nextPrayerScheduledTime, scale: 1.0)
                        .padding(.top, IhsanSpacing.xxs)
                    HStack(spacing: IhsanSpacing.xs) {
                        Text("until")
                            .font(IhsanFont.smallCaps)
                            .tracking(0.8)
                            .foregroundStyle(IhsanColor.textMuted)
                        Text(entry.nextPrayer.displayNameEnglish)
                            .font(IhsanFont.bodyEnglishBold)
                            .foregroundStyle(IhsanColor.textSecondary)
                        Text(entry.nextPrayer.displayNameArabic)
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(IhsanColor.textMuted)
                    }
                }
            }

            Spacer()

            if let bearing = entry.qiblaBearingDegrees {
                Link(destination: WidgetDeeplink.qibla) {
                    QiblaIndicator(bearingDegrees: bearing, size: 38)
                }
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(IhsanColor.atmospheric)
            .frame(height: IhsanSpacing.hairline)
    }

    @ViewBuilder
    private var prayerList: some View {
        VStack(spacing: IhsanSpacing.xs) {
            ForEach(entry.todayPrayerTimes) { slot in
                prayerRow(slot)
            }
        }
    }

    private func prayerRow(_ slot: PrayerTimelineEntry.PrayerSlot) -> some View {
        let status = entry.loggedStatus(for: slot.prayer)
        let isActive = slot.prayer == entry.activePrayer
        let isNext = slot.prayer == entry.nextPrayer

        return Button(intent: LogPrayerIntent(prayer: slot.prayer)) {
            HStack(spacing: IhsanSpacing.md) {
                PrayerSymbol(slot.prayer, size: 18)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 0) {
                    Text(slot.prayer.displayNameEnglish)
                        .font(isActive ? IhsanFont.bodyEnglishBold : IhsanFont.bodyEnglish)
                        .foregroundStyle(IhsanColor.textPrimary)
                }

                Spacer()

                if let status {
                    statusChip(status)
                } else if isNext && !isActive {
                    Text("NEXT")
                        .font(IhsanFont.smallCaps)
                        .tracking(1.2)
                        .foregroundStyle(IhsanColor.textMuted)
                }

                Text(WidgetCountdown.clockTime(slot.scheduledTime))
                    .font(IhsanFont.tabular)
                    .foregroundStyle(isActive ? IhsanColor.textSecondary : IhsanColor.textMuted)
                    .frame(minWidth: 60, alignment: .trailing)
            }
            .padding(.horizontal, IhsanSpacing.xs)
            .padding(.vertical, IhsanSpacing.xxs)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log \(slot.prayer.displayNameEnglish) on time, scheduled \(WidgetCountdown.clockTime(slot.scheduledTime))")
    }

    private func statusChip(_ status: PrayerStatus) -> some View {
        let label: String = {
            switch status {
            case .onTime: return "On Time"
            case .late: return "Late"
            case .missed: return "Missed"
            case .qada: return "Qada"
            }
        }()
        let color: Color = {
            switch status {
            case .onTime: return IhsanColor.statusOnTime
            case .late: return IhsanColor.statusLate
            case .missed: return IhsanColor.statusMissed
            case .qada: return IhsanColor.statusQada
            }
        }()
        return Text(label)
            .font(IhsanFont.smallCaps)
            .tracking(0.6)
            .foregroundStyle(color)
    }
}

struct PrayerOverviewLargeWidget: Widget {
    static let kind: String = "PrayerOverviewLargeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: PrayerTimelineProvider()) { entry in
            PrayerOverviewLargeWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    ZStack {
                        IhsanColor.ground
                        Color.clear.ihsanGlass(intensity: .regular)
                    }
                }
        }
        .configurationDisplayName("Prayer Overview")
        .description("Full day's prayer list with countdown and qibla.")
        .supportedFamilies([.systemLarge])
    }
}
