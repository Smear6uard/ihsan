import SwiftUI
import IhsanDesignSystem

/// Five-dot progress indicator anchored at the bottom of every step.
///
/// The active dot is filled at primary opacity and is also visually
/// elongated into a short capsule so the "you are here" position reads
/// at a glance even at small sizes.
struct OnboardingProgressDots: View {
    let total: Int
    let currentIndex: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: IhsanSpacing.sm) {
            ForEach(0..<total, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(fillColor(for: index))
                    .frame(
                        width: index == currentIndex ? 22 : 6,
                        height: 6
                    )
                    .animation(
                        reduceMotion
                            ? .linear(duration: 0.18)
                            : .spring(response: 0.55, dampingFraction: 0.85),
                        value: currentIndex
                    )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(currentIndex + 1) of \(total)")
    }

    private func fillColor(for index: Int) -> Color {
        if index < currentIndex {
            return IhsanColor.textSecondary
        } else if index == currentIndex {
            return IhsanColor.textPrimary
        } else {
            return IhsanColor.atmospheric
        }
    }
}

#Preview {
    VStack(spacing: IhsanSpacing.lg) {
        ForEach(0..<5, id: \.self) { idx in
            OnboardingProgressDots(total: 5, currentIndex: idx)
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .ihsanBackground()
}
