import Foundation
import SwiftUI
import IhsanDesignSystem

/// One transient Apple Maps result. The whole illuminated row opens
/// directions; no business metadata beyond name, street, and distance
/// enters this surface.
struct MasjidResultRow: View {
    let result: MasjidResult
    let tokens: SkyPaletteTokens
    let onTap: () -> Void

    @ScaledMetric(relativeTo: .body) private var glyphSide: CGFloat = 22

    var body: some View {
        Button {
            Haptics.tap()
            onTap()
        } label: {
            HStack(alignment: .center, spacing: IhsanSpacing.md) {
                VStack(alignment: .leading, spacing: IhsanSpacing.xs) {
                    Text(result.name)
                        .font(IhsanFont.bodyEnglishBold)
                        .foregroundStyle(tokens.ink)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(detailLine)
                        .font(IhsanFont.inscription)
                        .tracking(1.1)
                        .foregroundStyle(tokens.inkSecondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                SettingsGlyphView(.directions, color: tokens.metal)
                    .frame(width: glyphSide, height: glyphSide)
                    .padding(IhsanSpacing.sm)
            }
            .padding(IhsanSpacing.md)
            .contentShape(Rectangle())
            .celestialPanel(
                tokens: tokens,
                cornerRadius: IhsanSpacing.smallCardRadius
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityAddTraits(.isButton)
    }

    private var detailLine: String {
        [distanceFormatted, result.street]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private var distanceFormatted: String {
        Measurement(value: result.distanceMeters, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road))
    }

    private var spokenDistance: String {
        Measurement(value: result.distanceMeters, unit: UnitLength.meters)
            .formatted(.measurement(width: .wide, usage: .road))
    }

    private var accessibilityDescription: String {
        [result.name, spokenDistance, result.street, "Opens directions in Maps"]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}
