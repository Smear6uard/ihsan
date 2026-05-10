import SwiftUI
import IhsanDesignSystem

/// The quieter sibling of `OnboardingPrimaryButton`. Used for
/// non-blocking opt-outs ("Skip for now", "Not now") so the primary
/// path remains visually obvious without making the secondary path
/// feel punitive.
struct OnboardingGhostButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(IhsanFont.bodyEnglish)
                .foregroundStyle(IhsanColor.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}
