import SwiftUI
import IhsanDesignSystem

/// Step 1 of 5 — the wordmark, the Arabic of "ihsan", and a single
/// tagline. Nothing else fights for the eye. The Continue button is
/// the only affordance.
struct OnboardingWelcomeStep: View {
    @Bindable var viewModel: OnboardingViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    var body: some View {
        OnboardingScaffold(
            stepIndex: OnboardingStep.welcome.progressIndex
        ) {
            wordmark
        } content: {
            VStack(spacing: IhsanSpacing.md) {
                Text("A private record of prayer.")
                    .font(IhsanFont.bodyEnglish)
                    .foregroundStyle(IhsanColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, IhsanSpacing.md)
                    .opacity(hasAppeared ? 1 : 0)
                    .animation(
                        reduceMotion
                            ? .linear(duration: 0.2)
                            : .easeOut(duration: 0.6).delay(0.25),
                        value: hasAppeared
                    )
            }
        } actions: {
            OnboardingPrimaryButton("Continue") {
                viewModel.goNext(from: .welcome)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            hasAppeared = true
        }
    }

    private var wordmark: some View {
        VStack(spacing: IhsanSpacing.xs) {
            // Latin wordmark — quietly heavyweight, sized as the
            // single largest typographic moment in the app aside from
            // the countdown numerals on Today.
            Text("Ihsan")
                .font(.system(size: 56, weight: .light, design: .serif))
                .foregroundStyle(IhsanColor.textPrimary)
                .kerning(2)
                .opacity(hasAppeared ? 1 : 0)
                .scaleEffect(hasAppeared ? 1.0 : 0.96)
                .animation(
                    // Splash entrance — intentionally a slow, generous
                    // settle (response 0.7) rather than the standard UI
                    // spring. The wordmark is the first impression of
                    // the app; it should feel like it's arriving, not
                    // popping in.
                    reduceMotion
                        ? .linear(duration: 0.2)
                        : .spring(response: 0.7, dampingFraction: 0.85),
                    value: hasAppeared
                )

            // Arabic mark — small, integrated beneath the Latin,
            // explicitly NOT a watermark and not behind anything.
            Text("إِحْسَان")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(IhsanColor.textSecondary)
                .opacity(hasAppeared ? 1 : 0)
                .animation(
                    reduceMotion
                        ? .linear(duration: 0.2)
                        : .easeOut(duration: 0.7).delay(0.18),
                    value: hasAppeared
                )
                .accessibilityLabel("Ihsan, Arabic transliteration")
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    @Previewable @State var vm = OnboardingViewModel()
    NavigationStack {
        OnboardingWelcomeStep(viewModel: vm)
    }
}
