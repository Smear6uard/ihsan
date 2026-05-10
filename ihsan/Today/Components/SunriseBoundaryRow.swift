import SwiftUI
import IhsanDesignSystem

struct SunriseBoundaryRow: View {
    let sunriseTime: Date

    var body: some View {
        let now = Date.now
        let foreground = IhsanColor.cardForegroundPrimary(at: now)
        let foregroundSecondary = IhsanColor.cardForegroundSecondary(at: now)
        let foregroundMuted = IhsanColor.cardForegroundMuted(at: now)
        let accent = IhsanColor.accentWarm(at: now)

        HStack(spacing: IhsanSpacing.md) {
            Image(systemName: "sunrise")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(accent.opacity(0.85))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: IhsanSpacing.xxs) {
                HStack(spacing: IhsanSpacing.sm) {
                    Text("Sunrise")
                        .font(IhsanFont.bodyEnglish)
                        .foregroundStyle(foreground.opacity(0.85))
                    Text("شُروق")
                        .font(IhsanFont.bodyArabic)
                        .foregroundStyle(foregroundSecondary)
                }
                Text("Fajr ends")
                    .font(IhsanFont.smallCaps)
                    .foregroundStyle(foregroundMuted)
            }

            Spacer(minLength: IhsanSpacing.sm)

            Text(sunriseTime, format: .dateTime.hour().minute())
                .font(IhsanFont.tabular)
                .foregroundStyle(foregroundSecondary)
        }
        .padding(.horizontal, IhsanSpacing.md)
        .padding(.vertical, IhsanSpacing.sm)
        .frame(minHeight: 48)
        .ihsanWarmCard(intensity: .subtle)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Sunrise at \(sunriseTime.formatted(date: .omitted, time: .shortened)), Fajr's window ends"
        )
    }
}
