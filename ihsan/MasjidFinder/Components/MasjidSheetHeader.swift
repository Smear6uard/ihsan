import SwiftUI
import IhsanDesignSystem

/// Sheet chrome: centered title, dismiss affordance on the right, and a
/// hairline below to separate the header from the result list. Mirrors
/// the structure of `QiblaSheetHeader` so both sheets feel like
/// siblings, not strangers.
struct MasjidSheetHeader: View {
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("Masjids Nearby")
                    .font(IhsanFont.subtitle)
                    .foregroundStyle(IhsanColor.textPrimary)

                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24, weight: .regular))
                            .foregroundStyle(IhsanColor.textMuted)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }
            }
            .padding(.horizontal, IhsanSpacing.md)
            .padding(.vertical, IhsanSpacing.sm)
            .frame(height: 44)

            HairlineDivider()
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        MasjidSheetHeader(onClose: {})
        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .ihsanBackground()
}
