import IhsanCore
import IhsanDesignSystem
import SwiftData
import SwiftUI

/// The opt-in conversation that turns makeup tracking on. Presented as a
/// full-screen cover from Set or from the Path invitation card; invisible
/// everywhere until the user chooses it.
struct RepairSetupFlow: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = RepairSetupViewModel()

    var onFinished: (() -> Void)? = nil

    private var tokens: SkyPaletteTokens {
        RepairPalette.tokens()
    }

    var body: some View {
        NavigationStack(path: $viewModel.path) {
            RepairChoiceStep(viewModel: viewModel, tokens: tokens) {
                dismiss()
            }
            .navigationDestination(for: RepairSetupStep.self) { step in
                stepView(for: step)
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        if step != .closing {
                            ToolbarItem(placement: .topBarLeading) {
                                backButton
                            }
                        }
                    }
                    .toolbarBackground(.hidden, for: .navigationBar)
            }
        }
        .interactiveDismissDisabled(false)
    }

    @ViewBuilder
    private func stepView(for step: RepairSetupStep) -> some View {
        switch step {
        case .manualCounts:
            RepairManualCountsStep(viewModel: viewModel, tokens: tokens)
        case .birthDate:
            RepairBirthDateStep(viewModel: viewModel, tokens: tokens)
        case .accountabilityAge:
            RepairAccountabilityStep(viewModel: viewModel, tokens: tokens)
        case .prayerBegan:
            RepairPrayerBeganStep(viewModel: viewModel, tokens: tokens)
        case .excusedDays:
            RepairExcusedDaysStep(viewModel: viewModel, tokens: tokens)
        case .review:
            RepairReviewStep(viewModel: viewModel, tokens: tokens)
        case .witr:
            RepairWitrStep(viewModel: viewModel, tokens: tokens)
        case .missedFlow:
            RepairMissedFlowStep(viewModel: viewModel, tokens: tokens)
        case .closing:
            RepairClosingStep(viewModel: viewModel, tokens: tokens) {
                onFinished?()
                dismiss()
            }
        }
    }

    private var backButton: some View {
        Button {
            Haptics.impact(.light)
            if !viewModel.path.isEmpty {
                viewModel.path.removeLast()
            }
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(tokens.ink)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }
}
