import SwiftUI
import IhsanDesignSystem

/// Three rows of paired data inside a single subtle glass card. Labels in
/// small caps with letter spacing read as quiet etched markings; values
/// in tabular figures so the digits stay aligned across rows.
struct QiblaInfoPanel: View {
    let bearing: Double
    let distanceKm: Double
    let cityName: String?

    var body: some View {
        VStack(spacing: 0) {
            row(label: "Qibla bearing", value: CompassDirection.format(bearing))
            HairlineDivider()
            row(label: "Distance to Makkah", value: DistanceFormatter.kilometers(distanceKm))
            HairlineDivider()
            row(label: "From", value: cityName ?? "Unknown")
        }
        .padding(.vertical, IhsanSpacing.xs)
        .padding(.horizontal, IhsanSpacing.md)
        .ihsanGlass(intensity: .subtle)
    }

    private func row(label: String, value: String) -> some View {
        HStack {
            Text(label.uppercased())
                .font(IhsanFont.smallCaps)
                .tracking(1.0)
                .foregroundStyle(IhsanColor.textMuted)
            Spacer()
            Text(value)
                .font(IhsanFont.tabular)
                .foregroundStyle(IhsanColor.textPrimary)
        }
        .padding(.vertical, IhsanSpacing.md)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    QiblaInfoPanel(bearing: 47, distanceKm: 11247, cityName: "Chicago, IL")
        .padding(IhsanSpacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ihsanBackground()
}
