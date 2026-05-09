import SwiftUI
import IhsanDesignSystem

struct SunriseBoundaryRow: View {
    let sunriseTime: Date

    var body: some View {
        HStack(spacing: IhsanSpacing.md) {
            Image(systemName: "sunrise")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(IhsanColor.textMuted)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: IhsanSpacing.xxs) {
                HStack(spacing: IhsanSpacing.sm) {
                    Text("Sunrise")
                        .font(IhsanFont.bodyEnglish)
                        .foregroundStyle(IhsanColor.textSecondary)
                    Text("شُروق")
                        .font(IhsanFont.bodyArabic)
                        .foregroundStyle(IhsanColor.textMuted)
                }
                Text("Fajr ends")
                    .font(IhsanFont.smallCaps)
                    .foregroundStyle(IhsanColor.textMuted.opacity(0.7))
            }

            Spacer(minLength: IhsanSpacing.sm)

            Text(sunriseTime, format: .dateTime.hour().minute())
                .font(IhsanFont.tabular)
                .foregroundStyle(IhsanColor.textMuted)
        }
        .padding(.horizontal, IhsanSpacing.md)
        .frame(height: 48)
        .ihsanGlass(intensity: .subtle)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Sunrise at \(sunriseTime.formatted(date: .omitted, time: .shortened)), Fajr's window ends"
        )
    }
}
