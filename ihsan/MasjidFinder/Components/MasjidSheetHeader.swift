import SwiftUI
import IhsanDesignSystem

/// Sheet chrome in the same title-and-inscription register as the app's
/// secondary pages. The close mark is drawn linework, not a content icon.
struct MasjidSheetHeader: View {
    let locationName: String
    let tokens: SkyPaletteTokens
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: IhsanSpacing.md) {
            VStack(alignment: .leading, spacing: IhsanSpacing.xs) {
                Text("Near \(locationName)")
                    .font(.system(.title2, design: .serif, weight: .medium))
                    .foregroundStyle(tokens.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text("CURRENT LOCATION")
                    .font(IhsanFont.inscription)
                    .tracking(1.8)
                    .foregroundStyle(tokens.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            Spacer(minLength: IhsanSpacing.sm)

            Button {
                Haptics.impact(.light)
                onClose()
            } label: {
                MasjidCloseMark()
                    .stroke(
                        tokens.metal,
                        style: StrokeStyle(lineWidth: 1.2, lineCap: .round)
                    )
                    .frame(width: IhsanSpacing.md, height: IhsanSpacing.md)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close nearby masjids")
        }
        .padding(.horizontal, IhsanSpacing.md)
        .padding(.top, IhsanSpacing.md)
    }
}

private struct MasjidCloseMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return path
    }
}
