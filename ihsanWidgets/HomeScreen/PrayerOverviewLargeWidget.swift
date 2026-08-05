import AppIntents
import IhsanCore
import IhsanDesignSystem
import IhsanIntents
import SwiftUI
import WidgetKit

/// Large (4×4). The arc, then the day written out.
///
/// The arc on top says the shape of the day at a glance; the list
/// under it gives the times a person actually reads. Only the current
/// prayer's row is a button (On Time, through the shared intent) —
/// a passed prayer's status is a question the app's own sheet asks
/// properly, and an upcoming prayer is not loggable at all. During an
/// excused pause the list is times only.
struct PrayerOverviewLargeWidgetView: View {
    let entry: PrayerTimelineEntry

    @Environment(\.showsWidgetContainerBackground) private var showsContainer

    var body: some View {
        let tokens = WidgetPalette.tokens(for: entry)
        let isStandBy = !showsContainer
        let ink = isStandBy ? tokens.standByInk : tokens.ink
        let inkSecondary = isStandBy ? tokens.standByInkSecondary : tokens.inkSecondary

        Group {
            switch entry.content {
            case .live(let day):
                liveBody(day, tokens: tokens, ink: ink, inkSecondary: inkSecondary)
            case .invitation(let invitation):
                WidgetInvitationFace(
                    invitation: invitation, ink: ink, inkSecondary: inkSecondary
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .widgetURL(WidgetDeeplink.today)
    }

    @ViewBuilder
    private func liveBody(
        _ day: PrayerTimelineEntry.LiveDay,
        tokens: SkyPaletteTokens,
        ink: Color,
        inkSecondary: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
            heroBand(day, tokens: tokens, ink: ink, inkSecondary: inkSecondary)

            WidgetPlate(day: day, date: entry.date, tokens: tokens, ornamentSize: 20)
                .frame(height: 54)

            divider(tokens: tokens)

            VStack(spacing: IhsanSpacing.xs) {
                ForEach(day.slots) { slot in
                    prayerRow(
                        slot, day: day, tokens: tokens,
                        ink: ink, inkSecondary: inkSecondary
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func heroBand(
        _ day: PrayerTimelineEntry.LiveDay,
        tokens: SkyPaletteTokens,
        ink: Color,
        inkSecondary: Color
    ) -> some View {
        HStack(alignment: .top, spacing: IhsanSpacing.md) {
            VStack(alignment: .leading, spacing: IhsanSpacing.xxs) {
                if let city = day.cityName {
                    Text(city.uppercased())
                        .font(IhsanFont.inscription)
                        .tracking(1.2)
                        .foregroundStyle(inkSecondary)
                        .lineLimit(1)
                }

                if let countdown = entry.nextPrayerCountdown {
                    CountdownLabel.Hero(interval: countdown)
                        .foregroundStyle(ink)
                        .padding(.top, IhsanSpacing.xxs)
                }

                HStack(spacing: IhsanSpacing.xs) {
                    Text("UNTIL")
                        .font(IhsanFont.inscription)
                        .tracking(1.0)
                        .foregroundStyle(inkSecondary)
                    Text(day.nextPrayer.displayNameEnglish)
                        .font(.system(size: 17, weight: .semibold, design: .serif))
                        .foregroundStyle(ink)
                    Text(day.nextPrayer.displayNameArabic)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(inkSecondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }

            Spacer(minLength: IhsanSpacing.xs)

            if let bearing = day.qiblaBearingDegrees {
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
    private func prayerRow(
        _ slot: PrayerTimelineEntry.LiveDay.PrayerSlot,
        day: PrayerTimelineEntry.LiveDay,
        tokens: SkyPaletteTokens,
        ink: Color,
        inkSecondary: Color
    ) -> some View {
        let isCurrent = slot.prayer == day.currentPrayer
        let isLoggable = isCurrent && slot.status == nil && !day.isPaused

        if isLoggable {
            Button(intent: LogPrayerIntent(prayer: slot.prayer)) {
                rowContent(slot, day: day, tokens: tokens, ink: ink, inkSecondary: inkSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(rowAccessibilityLabel(slot, day: day))
            .accessibilityHint("Logs on time")
        } else {
            rowContent(slot, day: day, tokens: tokens, ink: ink, inkSecondary: inkSecondary)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(rowAccessibilityLabel(slot, day: day))
        }
    }

    private func rowContent(
        _ slot: PrayerTimelineEntry.LiveDay.PrayerSlot,
        day: PrayerTimelineEntry.LiveDay,
        tokens: SkyPaletteTokens,
        ink: Color,
        inkSecondary: Color
    ) -> some View {
        let isCurrent = slot.prayer == day.currentPrayer
        let isNext = slot.prayer == day.nextPrayer

        return HStack(spacing: IhsanSpacing.md) {
            PrayerMarkerOrnament(
                prayer: slot.prayer,
                size: 18,
                state: day.markerState(for: slot, at: entry.date),
                tokens: tokens
            )
            .frame(width: 22)

            Text(slot.prayer.displayNameEnglish)
                .font(.system(
                    size: 16,
                    weight: isCurrent ? .semibold : .regular,
                    design: .serif
                ))
                .foregroundStyle(ink)

            Spacer(minLength: IhsanSpacing.xs)

            if let status = slot.status, !day.isPaused {
                statusInscription(status, tokens: tokens)
            } else if isNext && !isCurrent {
                Text("NEXT")
                    .font(IhsanFont.inscription)
                    .tracking(1.2)
                    .foregroundStyle(tokens.ink)
            }

            Text(day.clockTime(slot.scheduledTime))
                .font(.system(.subheadline, design: .rounded).monospacedDigit())
                .foregroundStyle(isCurrent ? ink : inkSecondary)
                .frame(minWidth: 62, alignment: .trailing)
        }
        .padding(.horizontal, IhsanSpacing.xs)
        .padding(.vertical, IhsanSpacing.xxs)
        .contentShape(Rectangle())
    }

    /// Status reads in the inscription register — a word, not a badge.
    /// An unlogged prayer simply shows its time; absence is not a
    /// state this app names at a glance.
    @ViewBuilder
    private func statusInscription(
        _ status: PrayerStatus, tokens: SkyPaletteTokens
    ) -> some View {
        let label: String? = {
            switch status {
            case .onTime: "ON TIME"
            case .late: "LATE"
            case .qada: "MADE UP"
            case .missed: nil
            }
        }()
        if let label {
            Text(label)
                .font(IhsanFont.inscription)
                .tracking(1.0)
                .foregroundStyle(tokens.ink)
                .lineLimit(1)
        }
    }

    private func rowAccessibilityLabel(
        _ slot: PrayerTimelineEntry.LiveDay.PrayerSlot,
        day: PrayerTimelineEntry.LiveDay
    ) -> String {
        "\(slot.prayer.displayNameEnglish) at \(day.clockTime(slot.scheduledTime)), "
            + day.markerState(for: slot, at: entry.date).spokenDescription
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
        .description("The day's arc and all five prayers at a glance.")
        .supportedFamilies([.systemLarge])
    }
}
