import SwiftUI
import IhsanDesignSystem

/// Marker row separating Fajr from Dhuhr in the prayer list. Sunrise
/// isn't a prayer to log — it's a window boundary — so the row carries
/// no status pill, no jama'ah toggle, no adhan toggle. Visually it reads
/// as an inscriptional caption rather than a prayer row: smaller, no
/// brass border at full strength, no shadow.
struct SunriseBoundaryRow: View {
    let sunriseTime: Date

    var body: some View {
        let now = Date.now
        let foreground = IhsanColor.cardForegroundPrimary(at: now)
        let foregroundSecondary = IhsanColor.cardForegroundSecondary(at: now)

        HStack(spacing: IhsanSpacing.md) {
            Image(systemName: "sunrise")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(IhsanColor.brass.opacity(0.78))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: IhsanSpacing.sm) {
                    Text("Sunrise")
                        .font(IhsanFont.rowPrayerName)
                        .foregroundStyle(foreground.opacity(0.78))
                    Text("شُروق")
                        .font(IhsanFont.bodyArabic)
                        .foregroundStyle(foregroundSecondary.opacity(0.78))
                }
                Text("Fajr ends".uppercased())
                    .font(IhsanFont.inscription)
                    .tracking(1.4)
                    .foregroundStyle(IhsanColor.brass.opacity(0.70))
            }

            Spacer(minLength: IhsanSpacing.sm)

            Text(sunriseTime, format: .dateTime.hour().minute())
                .font(IhsanFont.tabular)
                .foregroundStyle(foregroundSecondary)
        }
        .padding(.horizontal, IhsanSpacing.lg)
        .padding(.vertical, IhsanSpacing.sm)
        .frame(minHeight: 44)
        // No illuminated panel — the boundary row sits as inscriptional
        // text directly on the page, between two illuminated prayer
        // rows. A faint horizontal brass rule signals the section break
        // without competing with the prayer panels.
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [
                    .clear,
                    IhsanColor.brass.opacity(0.22),
                    .clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: IhsanSpacing.hairline)
            .padding(.horizontal, IhsanSpacing.xl)
        }
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [
                    .clear,
                    IhsanColor.brass.opacity(0.22),
                    .clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: IhsanSpacing.hairline)
            .padding(.horizontal, IhsanSpacing.xl)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Sunrise at \(sunriseTime.formatted(date: .omitted, time: .shortened)), Fajr's window ends"
        )
    }
}
