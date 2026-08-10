import Foundation
import SwiftUI
import IhsanDesignSystem

/// One transient Apple Maps result. The whole illuminated row opens
/// directions; no business metadata beyond name, street, and distance
/// enters this surface.
struct MasjidResultRow: View {
    let result: MasjidResult
    let tokens: SkyPaletteTokens
    /// True when this row is already the user's masjid. The line beneath
    /// then states the fact instead of offering the act.
    var isMyMasjid: Bool = false
    let onTap: () -> Void
    /// `nil` hides the line entirely — the row is exactly what it was
    /// before My Masjid existed.
    var onSetAsMine: (() -> Void)?

    @ScaledMetric(relativeTo: .body) private var glyphSide: CGFloat = 22

    var body: some View {
        VStack(spacing: 0) {
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
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityDescription)
            .accessibilityAddTraits(.isButton)

            if onSetAsMine != nil || isMyMasjid {
                mineLine
            }
        }
        .padding(IhsanSpacing.md)
        .celestialPanel(
            tokens: tokens,
            cornerRadius: IhsanSpacing.smallCardRadius
        )
    }

    /// The row's third line.
    ///
    /// A full-width target rather than a second glyph beside the
    /// directions arrow: two tap targets sharing one row collapse at
    /// `.accessibility5`, and they hand VoiceOver two rectangles
    /// contending for the same space.
    ///
    /// This is the only gilding in the whole My Masjid feature, and it
    /// earns it — gold means committed everywhere else in the app, and
    /// choosing your masjid is a commitment. Once chosen, the line drops
    /// to metal and stops being a button: it has nothing left to offer.
    @ViewBuilder
    private var mineLine: some View {
        if isMyMasjid {
            Text("MY MASJID")
                .font(IhsanFont.inscription)
                .tracking(1.6)
                .foregroundStyle(tokens.metal)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, IhsanSpacing.sm)
                .accessibilityLabel("This is your masjid")
        } else if let onSetAsMine {
            Button {
                Haptics.impact(.light)
                onSetAsMine()
            } label: {
                Text("SET AS MY MASJID")
                    .font(IhsanFont.inscription)
                    .tracking(1.6)
                    .foregroundStyle(tokens.leafGold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, IhsanSpacing.sm)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Set \(result.name) as my masjid")
            .accessibilityHint("Opens the times editor so you can enter its iqamah.")
        }
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
