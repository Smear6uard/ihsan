import SwiftUI
import IhsanCore
import IhsanDesignSystem
import IhsanLocation

/// Step 3 of 5 — calculation method.
///
/// Prefilled with the auto-detected method (set by the location step,
/// falling back to a locale-derived guess when location was skipped).
/// Tapping the card or the "Change method" link opens
/// `CalculationMethodPicker`.
struct OnboardingMethodStep: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        OnboardingScaffold(
            stepIndex: OnboardingStep.calculationMethod.progressIndex
        ) {
            heroSymbol
        } content: {
            VStack(spacing: IhsanSpacing.lg) {
                VStack(spacing: IhsanSpacing.sm) {
                    Text("How prayer times are calculated")
                        .font(IhsanFont.title)
                        .foregroundStyle(IhsanColor.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Different scholarly bodies use slightly different angles for Fajr and Isha. We've selected one that fits your region — change it any time.")
                        .font(IhsanFont.bodyEnglish)
                        .foregroundStyle(IhsanColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                OnboardingMethodCard(
                    method: viewModel.draftMethod,
                    detectedFromCountry: viewModel.locationAuthorization.isAuthorized
                ) {
                    viewModel.showMethodPicker = true
                }
            }
        } actions: {
            OnboardingPrimaryButton("Continue") {
                viewModel.goNext(from: .calculationMethod)
            }
        }
        .sheet(isPresented: $viewModel.showMethodPicker) {
            CalculationMethodPicker(selection: $viewModel.draftMethod)
        }
    }

    private var heroSymbol: some View {
        Image(systemName: "globe")
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
        OnboardingMethodStep(viewModel: vm)
    }
}
