import SwiftUI
import IhsanCore
import IhsanDesignSystem

/// Step 4 of 5 — madhab choice for the Asr calculation.
///
/// Two side-by-side cards on regular size classes; the cards stack
/// vertically on narrow widths (small phones at large Dynamic Type
/// sizes) so neither card ever clips its scholarly footnote.
struct OnboardingMadhabStep: View {
    @Bindable var viewModel: OnboardingViewModel

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var stacksVertically: Bool {
        dynamicTypeSize >= .accessibility1
    }

    var body: some View {
        OnboardingScaffold(
            stepIndex: OnboardingStep.madhab.progressIndex
        ) {
            heroSymbol
        } content: {
            VStack(spacing: IhsanSpacing.lg) {
                VStack(spacing: IhsanSpacing.sm) {
                    Text("When does Asr begin?")
                        .font(IhsanFont.title)
                        .foregroundStyle(IhsanColor.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("The two valid opinions on Asr's onset.")
                        .font(IhsanFont.bodyEnglish)
                        .foregroundStyle(IhsanColor.textSecondary)
                        .multilineTextAlignment(.center)
                }

                cards
            }
        } actions: {
            OnboardingPrimaryButton("Continue") {
                viewModel.goNext(from: .madhab)
            }
        }
    }

    @ViewBuilder
    private var cards: some View {
        if stacksVertically {
            VStack(spacing: IhsanSpacing.md) {
                standardCard
                hanafiCard
            }
        } else {
            HStack(alignment: .top, spacing: IhsanSpacing.md) {
                standardCard
                hanafiCard
            }
        }
    }

    private var standardCard: some View {
        OnboardingMadhabCard(
            title: "Standard",
            arabicLabel: "الجمهور",
            explanation: "Asr begins when an object's shadow equals its length.",
            scholars: "Shafi'i · Maliki · Hanbali",
            isSelected: viewModel.draftMadhab == .standard
        ) {
            viewModel.draftMadhab = .standard
        }
    }

    private var hanafiCard: some View {
        OnboardingMadhabCard(
            title: "Hanafi",
            arabicLabel: "الحنفي",
            explanation: "Asr begins when an object's shadow equals twice its length.",
            scholars: "Hanafi",
            isSelected: viewModel.draftMadhab == .hanafi
        ) {
            viewModel.draftMadhab = .hanafi
        }
    }

    private var heroSymbol: some View {
        Image(systemName: "building.columns")
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
        OnboardingMadhabStep(viewModel: vm)
    }
}
