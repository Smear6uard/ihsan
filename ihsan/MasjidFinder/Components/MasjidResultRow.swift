import SwiftUI
import IhsanDesignSystem

/// A single masjid row, presented as a `.subtle` glass card.
///
/// Layout follows a deliberate hierarchy:
///   1. Leading building glyph as visual anchor.
///   2. Bold name on the leading edge, tabular distance on the trailing
///      edge — eyes scan to whichever is closer first.
///   3. Address in secondary text underneath.
///   4. Optional phone row in tracked smallCaps with a phone glyph
///      — small, monumental, easy to find without competing.
///   5. A muted chevron marks the row as actionable.
///
/// The whole card is one accessibility element; the combined label
/// reads name → distance → address. The hint tells VoiceOver users
/// what double-tap will do.
struct MasjidResultRow: View {
    let result: MasjidResult
    let onTap: () -> Void
    let onCopyAddress: () -> Void
    let onShare: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            onTap()
        } label: {
            HStack(alignment: .top, spacing: IhsanSpacing.md) {
                Image(systemName: "building.2.fill")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(IhsanColor.textSecondary)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 28, alignment: .top)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: IhsanSpacing.xs) {
                    HStack(alignment: .firstTextBaseline, spacing: IhsanSpacing.sm) {
                        Text(result.name)
                            .font(IhsanFont.bodyEnglishBold)
                            .foregroundStyle(IhsanColor.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(distanceFormatted)
                            .font(IhsanFont.tabular)
                            .foregroundStyle(IhsanColor.textMuted)
                            .layoutPriority(1)
                    }

                    if let address = result.address {
                        Text(address)
                            .font(IhsanFont.bodyEnglish)
                            .foregroundStyle(IhsanColor.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let phone = result.phoneNumber {
                        HStack(spacing: IhsanSpacing.xs) {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 11, weight: .medium))
                            Text(phone)
                                .font(IhsanFont.smallCaps)
                                .tracking(0.6)
                        }
                        .foregroundStyle(IhsanColor.textMuted)
                        .padding(.top, IhsanSpacing.xxs)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(IhsanColor.textMuted)
                    .padding(.top, 4)
            }
            .padding(IhsanSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .ihsanGlass(
                in: RoundedRectangle(
                    cornerRadius: IhsanSpacing.smallCardRadius,
                    style: .continuous
                ),
                intensity: .subtle
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onTap()
            } label: {
                Label("Open in Apple Maps", systemImage: "map")
            }
            Button {
                onCopyAddress()
            } label: {
                Label("Copy Address", systemImage: "doc.on.doc")
            }
            Button {
                onShare()
            } label: {
                Label("Share Location", systemImage: "square.and.arrow.up")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Double tap to open in Apple Maps")
        .accessibilityAddTraits(.isButton)
    }

    private var distanceFormatted: String {
        if result.distanceKm < 1 {
            return "\(Int((result.distanceKm * 1_000).rounded())) m"
        } else {
            return String(format: "%.1f km", result.distanceKm)
        }
    }

    private var accessibilityDescription: String {
        var parts: [String] = [result.name, distanceFormatted]
        if let address = result.address { parts.append(address) }
        if let phone = result.phoneNumber { parts.append("Phone: \(phone)") }
        return parts.joined(separator: ", ")
    }
}
