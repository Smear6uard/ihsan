import SwiftUI
import IhsanDesignSystem

/// Sheet chrome: centered title, dismiss affordance on the right, and a
/// hairline below to separate the header from the dial.
struct QiblaSheetHeader: View {
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("Qibla")
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
        QiblaSheetHeader(onClose: {})
        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .ihsanBackground()
}
