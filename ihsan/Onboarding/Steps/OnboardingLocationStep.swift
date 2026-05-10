import SwiftUI
import IhsanDesignSystem

/// Step 2 of 5 — the location-permission rationale.
///
/// The system prompt fires from "Continue" so that the user has read
/// the privacy framing first. "Skip for now" is non-blocking; the
/// Today screen will surface a `needsLocationPermission` state until
/// the user grants permission later.
struct OnboardingLocationStep: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        OnboardingScaffold(
            stepIndex: OnboardingStep.location.progressIndex
        ) {
            heroSymbol
        } content: {
            VStack(spacing: IhsanSpacing.md) {
                Text("Your location, kept on this device")
                    .font(IhsanFont.title)
                    .foregroundStyle(IhsanColor.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Ihsan calculates prayer times from your current location. Your coordinates are never stored or shared — only your city name is saved for display.")
                    .font(IhsanFont.bodyEnglish)
                    .foregroundStyle(IhsanColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } actions: {
            OnboardingPrimaryButton(
                "Continue",
                isLoading: viewModel.isRequestingLocation
            ) {
                Task { await viewModel.requestLocationAndContinue() }
            }
            .accessibilityHint("Opens the system location permission prompt")

            OnboardingGhostButton("Skip for now") {
                viewModel.skipLocationAndContinue()
            }
            .accessibilityHint("Continues without location. You can grant access later from the Today screen.")
        }
    }

    private var heroSymbol: some View {
        Image(systemName: "location.viewfinder")
            .font(.system(size: 64, weight: .light))
            .foregroundStyle(IhsanColor.textPrimary)
            .symbolRenderingMode(.hierarchical)
            .accessibilityHidden(true)
            .frame(height: 80)
    }
}

#Preview {
    @Previewable @State var vm = OnboardingViewModel()
    NavigationStack {
        OnboardingLocationStep(viewModel: vm)
    }
}
