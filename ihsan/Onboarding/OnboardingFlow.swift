import SwiftUI
import IhsanDesignSystem

/// First-launch flow root.
///
/// `NavigationStack` drives the forward progression; the back chevron
/// (and the iOS swipe-back gesture) pops a step. The progress dots
/// inside each step's scaffold reflect the depth of the path so a
/// pop-back updates them automatically.
///
/// The flow is presented full-screen by `IhsanApp` and owns its own
/// `OnboardingViewModel`. The view model is created here (not in a
/// parent) so quitting the app mid-flow throws it away — users
/// restart the flow from step one with default draft state, which is
/// the documented behaviour.
struct OnboardingFlow: View {
    @State private var viewModel = OnboardingViewModel()

    var body: some View {
        @Bindable var vm = viewModel
        return NavigationStack(path: $vm.path) {
            OnboardingWelcomeStep(viewModel: viewModel)
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: OnboardingStep.self) { step in
                    destinationView(for: step)
                        .toolbar { backChevron }
                        .toolbarBackground(.hidden, for: .navigationBar)
                        .navigationBarBackButtonHidden(true)
                        .navigationBarTitleDisplayMode(.inline)
                }
        }
        .tint(IhsanColor.textPrimary)
    }

    @ViewBuilder
    private func destinationView(for step: OnboardingStep) -> some View {
        switch step {
        case .welcome:
            // Welcome lives at the root, not on the path. This branch
            // exists only to satisfy exhaustiveness; reaching it would
            // mean the path was constructed incorrectly.
            EmptyView()
        case .location:
            OnboardingLocationStep(viewModel: viewModel)
        case .calculationMethod:
            OnboardingMethodStep(viewModel: viewModel)
        case .madhab:
            OnboardingMadhabStep(viewModel: viewModel)
        case .notifications:
            OnboardingNotificationsStep(viewModel: viewModel)
        }
    }

    @ToolbarContentBuilder
    private var backChevron: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                guard !viewModel.path.isEmpty else { return }
                viewModel.path.removeLast()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(IhsanColor.textSecondary)
                    .frame(width: 44, height: 44, alignment: .leading)
            }
            .accessibilityLabel("Back")
        }
    }
}

#Preview {
    OnboardingFlow()
}
