import IhsanCore
import IhsanDesignSystem
import SwiftData
import SwiftUI

/// Compact multi-add for people working through sets: one category, one
/// count, one calm confirm.
struct RepairMultiAddSheet: View {
    let viewModel: RepairViewModel
    let categories: [QadaCategory]
    let tokens: SkyPaletteTokens

    @Environment(\.dismiss) private var dismiss
    @State private var selected: QadaCategory?
    @State private var count = 5

    var body: some View {
        ZStack {
            tokens.groundGradient
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: IhsanSpacing.lg) {
                Text("A SET, TOGETHER")
                    .font(IhsanFont.inscription)
                    .tracking(1.6)
                    .foregroundStyle(tokens.metal)
                    .shadow(color: tokens.inkHalo, radius: 2)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 88))],
                    spacing: IhsanSpacing.sm
                ) {
                    ForEach(categories, id: \.rawValue) { category in
                        Button {
                            Haptics.impact(.light)
                            selected = category
                        } label: {
                            Text(category.displayNameEnglish)
                                .font(IhsanFont.bodyEnglish)
                                .foregroundStyle(tokens.ink)
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background {
                                    Capsule().fill(
                                        selected == category
                                            ? tokens.panelFill
                                            : tokens.panelFill.opacity(0.4)
                                    )
                                }
                                .overlay {
                                    Capsule().stroke(
                                        selected == category ? tokens.metalHighlight : tokens.metal.opacity(0.4),
                                        lineWidth: selected == category ? 1.4 : 1
                                    )
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected == category ? .isSelected : [])
                    }
                }

                RepairStepperField(
                    value: $count,
                    range: 1...500,
                    unitLabel: "made up",
                    tokens: tokens
                )

                RepairPrimaryButton(title: "Add these", tokens: tokens) {
                    if let selected {
                        viewModel.logMadeUp(category: selected, count: count)
                        dismiss()
                    }
                }
                .opacity(selected == nil ? 0.45 : 1)
                .disabled(selected == nil)
            }
            .padding(IhsanSpacing.lg)
        }
        .onAppear {
            if selected == nil {
                selected = categories.first
            }
        }
        .environment(\.colorScheme, tokens.prefersDarkChrome ? .dark : .light)
    }
}

/// Rewrites remaining counts through adjustment entries, keeping history
/// append-only. Numbers stay the user's to change, any time.
struct RepairAdjustSheet: View {
    let viewModel: RepairViewModel
    let ledgers: [QadaLedger]
    let tokens: SkyPaletteTokens

    @Environment(\.dismiss) private var dismiss
    @State private var drafts: [QadaCategory: Int] = [:]

    var body: some View {
        ZStack {
            tokens.groundGradient
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: IhsanSpacing.lg) {
                Text("YOURS TO ADJUST")
                    .font(IhsanFont.inscription)
                    .tracking(1.6)
                    .foregroundStyle(tokens.metal)
                    .shadow(color: tokens.inkHalo, radius: 2)

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(ledgers, id: \.categoryRaw) { ledger in
                            if let category = ledger.category {
                                RepairCategoryCountRow(
                                    category: category,
                                    count: binding(for: category, current: ledger.remainingCount),
                                    tokens: tokens
                                )
                            }
                        }
                    }
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(tokens.panelFill)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(tokens.panelStroke, lineWidth: 1)
                    }
                }
                .scrollBounceBehavior(.basedOnSize)

                RepairPrimaryButton(title: "Keep these counts", tokens: tokens) {
                    for (category, newValue) in drafts {
                        viewModel.adjustRemaining(for: category, to: newValue)
                    }
                    Haptics.success()
                    dismiss()
                }
            }
            .padding(IhsanSpacing.lg)
        }
        .environment(\.colorScheme, tokens.prefersDarkChrome ? .dark : .light)
    }

    private func binding(for category: QadaCategory, current: Int) -> Binding<Int> {
        Binding(
            get: { drafts[category] ?? current },
            set: { drafts[category] = max(0, $0) }
        )
    }
}
