import IhsanDesignSystem
import SwiftUI

/// A single factual observation generated entirely on device. The card
/// has no score, recommendation, exhortation, or religious text.
struct TrajectoryInsightCard: View {
    let text: String?
    let isLoading: Bool
    let tokens: SkyPaletteTokens

    var body: some View {
        HStack(alignment: .top, spacing: IhsanSpacing.md) {
            FourPointedStar()
                .fill(tokens.metal)
                .frame(width: IhsanSpacing.md, height: IhsanSpacing.md)
                .frame(width: IhsanSpacing.xl, height: IhsanSpacing.xl)

            VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
                Text("ON-DEVICE INSIGHT")
                    .font(IhsanFont.inscription)
                    .tracking(1.8)
                    .foregroundStyle(tokens.inkSecondary)

                if isLoading {
                    HStack(spacing: IhsanSpacing.sm) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(tokens.metal)
                        Text("Reading this period's pattern")
                            .font(IhsanFont.bodyEnglish)
                            .foregroundStyle(tokens.inkSecondary)
                    }
                } else if let text {
                    Text(text)
                        .font(IhsanFont.bodyEnglish)
                        .foregroundStyle(tokens.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(IhsanSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ihsanGlass(
            in: RoundedRectangle(cornerRadius: IhsanSpacing.cardRadius, style: .continuous),
            intensity: .subtle
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            isLoading ? "Generating on-device insight" : "On-device insight, \(text ?? "")"
        )
    }
}
