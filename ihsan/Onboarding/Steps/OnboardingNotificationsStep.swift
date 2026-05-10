import SwiftUI
import SwiftData
import IhsanDesignSystem

/// Step 5 of 5 — adhan notifications.
///
/// Either branch finishes onboarding (commits UserSettings and flips
/// `hasCompletedOnboarding`). Skipping is non-blocking; the user can
/// turn notifications on from Settings later.
struct OnboardingNotificationsStep: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        OnboardingScaffold(
            stepIndex: OnboardingStep.notifications.progressIndex
        ) {
            heroSymbol
        } content: {
            VStack(spacing: IhsanSpacing.md) {
                Text("Hear the call.")
                    .font(IhsanFont.title)
                    .foregroundStyle(IhsanColor.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Adhan notifications help you not miss prayer times. You can change this anytime in Settings.")
                    .font(IhsanFont.bodyEnglish)
                    .foregroundStyle(IhsanColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } actions: {
            OnboardingPrimaryButton(
                "Enable notifications",
                isLoading: viewModel.isRequestingNotifications
            ) {
                Task {
                    await viewModel.enableNotificationsAndFinish(
                        in: modelContext
                    )
                }
            }
            .accessibilityHint("Opens the system notifications permission prompt, then completes setup")

            OnboardingGhostButton("Not now") {
                viewModel.skipNotificationsAndFinish(in: modelContext)
            }
            .accessibilityHint("Completes setup without notifications")
        }
    }

    private var heroSymbol: some View {
        Image(systemName: "bell.badge")
            .font(.system(size: 60, weight: .light))
            .foregroundStyle(IhsanColor.textPrimary)
            .symbolRenderingMode(.hierarchical)
            .accessibilityHidden(true)
            .frame(height: 80)
    }
}

#Preview {
    @Previewable @State var vm = OnboardingViewModel()
    NavigationStack {
        OnboardingNotificationsStep(viewModel: vm)
    }
}
