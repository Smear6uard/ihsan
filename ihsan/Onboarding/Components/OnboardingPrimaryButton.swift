import SwiftUI
import IhsanDesignSystem

/// The "Continue" capsule used as the primary affordance on every
/// onboarding step. Glass-capsule styling — the iridescent tint is
/// supplied by the shared `.ihsanGlass(...)` modifier so the button
/// feels of-a-piece with the rest of the app's surfaces.
struct OnboardingPrimaryButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ title: String, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .font(IhsanFont.bodyEnglishBold)
                    .foregroundStyle(IhsanColor.textPrimary)
                    .opacity(isLoading ? 0 : 1)

                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(IhsanColor.textPrimary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 54)
            .ihsanGlass(in: Capsule(style: .continuous), intensity: .hero)
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(IhsanColor.atmospheric, lineWidth: 0.5)
            }
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(PressableScaleStyle(reduceMotion: reduceMotion))
        .disabled(isLoading)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

/// Subtle press feedback. Reduce Motion users get a flat opacity dim
/// instead of a scale change.
private struct PressableScaleStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1.0 : (configuration.isPressed ? 0.98 : 1.0))
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(
                // Press feedback intentionally tighter than the standard
                // 0.35/0.85 UI spring: button-down should feel like
                // immediate physical contact, not a settled UI transition.
                reduceMotion
                    ? .linear(duration: 0.1)
                    : .spring(response: 0.32, dampingFraction: 0.78),
                value: configuration.isPressed
            )
    }
}
