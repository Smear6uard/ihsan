import SwiftUI

/// Independent boolean toggle for whether a prayer was performed in
/// jama'ah (congregation). Visually orthogonal to the status pill — a
/// prayer can be both `late` and `jamaah`, or `onTime` and individual.
///
/// Filled person.3 = jama'ah; outlined person = individual. NEVER green;
/// the toggle stays within the white/ivory palette to avoid framing
/// jama'ah as a gamified achievement.
public struct JamaahToggle: View {
    @Binding public var isJamaah: Bool
    public var onToggle: (() -> Void)?

    public init(isJamaah: Binding<Bool>, onToggle: (() -> Void)? = nil) {
        self._isJamaah = isJamaah
        self.onToggle = onToggle
    }

    public var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isJamaah.toggle()
            }
            onToggle?()
        } label: {
            Image(systemName: isJamaah ? "person.3.fill" : "person.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(
                    isJamaah ? IhsanColor.textPrimary : IhsanColor.textMuted
                )
                .frame(width: 32, height: 32)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(isJamaah ? 1.0 : 0.4)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isJamaah ? "Jama'ah" : "Individual")
        .accessibilityValue(isJamaah ? "On" : "Off")
        .accessibilityAddTraits(.isButton)
    }
}

private struct JamaahTogglePreviewWrapper: View {
    @State private var isJamaah = false

    var body: some View {
        VStack(spacing: IhsanSpacing.lg) {
            JamaahToggle(isJamaah: $isJamaah)
            Text(isJamaah ? "Jama'ah" : "Individual")
                .font(IhsanFont.smallCaps)
                .foregroundStyle(IhsanColor.textMuted)
        }
    }
}

#Preview("Jama'ah toggle") {
    JamaahTogglePreviewWrapper()
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ihsanBackground()
}
