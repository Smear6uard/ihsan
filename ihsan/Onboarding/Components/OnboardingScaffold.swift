import SwiftUI
import IhsanDesignSystem

/// Common chrome for every onboarding step: dark ground, a top-anchored
/// hero slot, vertically-centred content, primary/secondary action
/// slots, and the progress dots pinned at the bottom.
///
/// Steps fill in their own hero, content, and actions. Keeping the
/// shell here means each step is purely about its copy and choice
/// affordance — the rhythm of the flow is set in one place.
struct OnboardingScaffold<Hero: View, Content: View, Actions: View>: View {
    let stepIndex: Int
    let hero: Hero
    let content: Content
    let actions: Actions

    init(
        stepIndex: Int,
        @ViewBuilder hero: () -> Hero,
        @ViewBuilder content: () -> Content,
        @ViewBuilder actions: () -> Actions
    ) {
        self.stepIndex = stepIndex
        self.hero = hero()
        self.content = content()
        self.actions = actions()
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                // Hero slot — pinned high in the screen, never centred
                // vertically. Onboarding heroes carry symbolic weight;
                // the centred copy block beneath is what carries
                // explanation.
                hero
                    .frame(maxWidth: .infinity)
                    .padding(.top, max(proxy.safeAreaInsets.top, IhsanSpacing.lg) + IhsanSpacing.xl)
                    .padding(.bottom, IhsanSpacing.lg)

                // Content slot — centred between hero and actions.
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, IhsanSpacing.lg)

                VStack(spacing: IhsanSpacing.md) {
                    actions
                }
                .padding(.horizontal, IhsanSpacing.lg)
                .padding(.bottom, IhsanSpacing.lg)

                OnboardingProgressDots(
                    total: OnboardingStep.totalSteps,
                    currentIndex: stepIndex
                )
                .padding(.bottom, max(proxy.safeAreaInsets.bottom, IhsanSpacing.md))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ihsanBackground()
    }
}
