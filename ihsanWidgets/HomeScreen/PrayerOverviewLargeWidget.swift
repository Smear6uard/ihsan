import AppIntents
import IhsanCore
import IhsanDesignSystem
import IhsanIntents
import SwiftUI
import WidgetKit

/// Large (4×4). The arc, then the day written out.
///
/// The arc on top says the shape of the day at a glance; the list under
/// it gives the times a person actually reads. Each row logs its prayer
/// through the same intent every other surface uses, and carries its
/// own ornament — the identity is the same five shapes wherever they
/// appear, never a symbol standing in for one.
struct PrayerOverviewLargeWidgetView: View {
    let entry: PrayerTimelineEntry

    @Environment(\.showsWidgetContainerBackground) private var showsContainer

    var body: some View {
        let tokens = WidgetPalette.tokens(for: entry)
        let isStandBy = !showsContainer
        let ink = isStandBy ? tokens.standByInk : tokens.ink
        let inkSecondary = isStandBy ? tokens.standByInkSecondary : tokens.inkSecondary

        VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
            heroBand(tokens: tokens, ink: ink, inkSecondary: inkSecondary)

            if !entry.isLocationMissing {
                WidgetPlate(entry: entry, tokens: tokens, ornamentSize: 20)
                    .frame(height: 54)
            }

            divider(tokens: tokens)

            prayerList(tokens: tokens, ink: ink, inkSecondary: inkSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .widgetURL(WidgetDeeplink.today)
    }

    @ViewBuilder
    private func heroBand(
        tokens: SkyPaletteTokens, ink: Color, inkSecondary: Color
    ) -> some View {
        HStack(alignment: .top, spacing: IhsanSpacing.md) {
            VStack(alignment: .leading, spacing: IhsanSpacing.xxs) {
                Text(entry.cityName.uppercased())
                    .font(IhsanFont.inscription)
                    .tracking(1.2)
                    .foregroundStyle(inkSecondary)
                    .lineLimit(1)

                if entry.isLocationMissing {
                    Text("Open Ihsan to set your location")
                        .font(.system(size: 17, weight: .regular, design: .serif))
                        .foregroundStyle(ink)
                        .padding(.top, IhsanSpacing.xs)
                } else {
                    CountdownLabel.Hero(until: entry.nextPrayerScheduledTime, scale: 1.0)
                        .foregroundStyle(ink)
                        .padding(.top, IhsanSpacing.xxs)

                    HStack(spacing: IhsanSpacing.xs) {
                        Text("UNTIL")
                            .font(IhsanFont.inscription)
                            .tracking(1.0)
                            .foregroundStyle(inkSecondary)
                        Text(entry.nextPrayer.displayNameEnglish)
                            .font(.system(size: 17, weight: .semibold, design: .serif))
                            .foregroundStyle(ink)
                        Text(entry.nextPrayer.displayNameArabic)
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(inkSecondary)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }
            }

            Spacer(minLength: IhsanSpacing.xs)

            if let bearing = entry.qiblaBearingDegrees, !entry.isLocationMissing {
                Link(destination: WidgetDeeplink.qibla) {
                    QiblaIndicator(bearingDegrees: bearing, size: 38, tokens: tokens)
                }
                .accessibilityLabel("Qibla, \(Int(bearing.rounded())) degrees")
            }
        }
    }

    private func divider(tokens: SkyPaletteTokens) -> some View {
        Rectangle()
            .fill(tokens.panelStroke.opacity(0.6))
            .frame(height: IhsanSpacing.hairline)
    }

    @ViewBuilder
    private func prayerList(
        tokens: SkyPaletteTokens, ink: Color, inkSecondary: Color
    ) -> some View {
        VStack(spacing: IhsanSpacing.xs) {
            ForEach(entry.todayPrayerTimes) { slot in
                prayerRow(slot, tokens: tokens, ink: ink, inkSecondary: inkSecondary)
            }
        }
    }

    private func prayerRow(
        _ slot: PrayerTimelineEntry.PrayerSlot,
        tokens: SkyPaletteTokens,
        ink: Color,
        inkSecondary: Color
    ) -> some View {
        let status = entry.loggedStatus(for: slot.prayer)
        let isActive = slot.prayer == entry.activePrayer
        let isNext = slot.prayer == entry.nextPrayer

        return Button(intent: LogPrayerIntent(prayer: slot.prayer)) {
            HStack(spacing: IhsanSpacing.md) {
                PrayerMarkerOrnament(
                    prayer: slot.prayer,
                    size: 18,
                    state: entry.markerState(for: slot),
                    tokens: tokens
                )
                .frame(width: 22)

                Text(slot.prayer.displayNameEnglish)
                    .font(.system(
                        size: 16,
                        weight: isActive ? .semibold : .regular,
                        design: .serif
                    ))
                    .foregroundStyle(ink)

                Spacer(minLength: IhsanSpacing.xs)

                if let status {
                    statusChip(status, tokens: tokens)
                } else if isNext && !isActive {
                    Text("NEXT")
                        .font(IhsanFont.inscription)
                        .tracking(1.2)
                        .foregroundStyle(tokens.ink)
                }

                Text(entry.clockTime(slot.scheduledTime))
                    .font(.system(.subheadline, design: .rounded).monospacedDigit())
                    .foregroundStyle(isActive ? ink : inkSecondary)
                    .frame(minWidth: 62, alignment: .trailing)
            }
            .padding(.horizontal, IhsanSpacing.xs)
            .padding(.vertical, IhsanSpacing.xxs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(slot.prayer.displayNameEnglish) at \(entry.clockTime(slot.scheduledTime)), "
                + entry.markerState(for: slot).spokenDescription
        )
        .accessibilityHint("Logs on time")
    }

    /// Status reads in the inscription register — a word, not a badge.
    /// Nothing here is celebratory and nothing is punitive.
    private func statusChip(_ status: PrayerStatus, tokens: SkyPaletteTokens) -> some View {
        let label: String = {
            switch status {
            case .onTime: "ON TIME"
            case .late: "LATE"
            case .missed: "NOT LOGGED"
            case .qada: "MADE UP"
            }
        }()
        return Text(label)
            .font(IhsanFont.inscription)
            .tracking(1.0)
            .foregroundStyle(status == .missed ? tokens.inkSecondary : tokens.ink)
            .lineLimit(1)
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
        .configurationDisplayName("Today")
        .description("The day's arc and all five prayers, each one tap from logged.")
        .supportedFamilies([.systemLarge])
    }
}
