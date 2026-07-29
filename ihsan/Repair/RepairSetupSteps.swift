import IhsanCore
import IhsanDesignSystem
import SwiftData
import SwiftUI

// The nine screens of the setup conversation. Copy register for this
// feature: returning and repair, at the user's pace — counts are always
// "remaining" and "made up".

struct RepairChoiceStep: View {
    @Bindable var viewModel: RepairSetupViewModel
    let tokens: SkyPaletteTokens
    let onDismiss: () -> Void

    var body: some View {
        RepairSetupScaffold(
            tokens: tokens,
            inscription: "RETURNING",
            title: "Prayers to return to.",
            subtitle: "If you carry prayers from another season of life, Ihsan can hold the count and walk it down with you, at your pace. It stays private, like everything here."
        ) {
            EmptyView()
        } actions: {
            RepairPrimaryButton(title: "I know my count", tokens: tokens) {
                viewModel.beginManualPath()
            }
            RepairPrimaryButton(title: "Help me estimate", tokens: tokens) {
                viewModel.beginEstimatePath()
            }
            RepairGhostButton(title: "Not now", tokens: tokens) {
                onDismiss()
            }
        }
    }
}

struct RepairManualCountsStep: View {
    @Bindable var viewModel: RepairSetupViewModel
    let tokens: SkyPaletteTokens

    var body: some View {
        RepairSetupScaffold(
            tokens: tokens,
            inscription: "RETURNING",
            title: "Your count, as you know it.",
            subtitle: "Enter what remains for each prayer. Every number stays adjustable later."
        ) {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(QadaCategory.fardCategories, id: \.rawValue) { category in
                        RepairCategoryCountRow(
                            category: category,
                            count: binding(for: category),
                            tokens: tokens
                        )
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
        } actions: {
            RepairPrimaryButton(title: "Continue", tokens: tokens) {
                viewModel.goNext(from: .manualCounts)
            }
        }
    }

    private func binding(for category: QadaCategory) -> Binding<Int> {
        Binding(
            get: { viewModel.draft.manualCounts[category] ?? 0 },
            set: { viewModel.draft.manualCounts[category] = max(0, $0) }
        )
    }
}

struct RepairBirthDateStep: View {
    @Bindable var viewModel: RepairSetupViewModel
    let tokens: SkyPaletteTokens

    var body: some View {
        RepairSetupScaffold(
            tokens: tokens,
            inscription: "AN ESTIMATE · TOGETHER",
            title: "When were you born?",
            subtitle: "The estimate starts from your years, nothing more."
        ) {
            DatePicker(
                "Birth date",
                selection: $viewModel.draft.birthDate,
                in: ...Date.now,
                displayedComponents: .date
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
        } actions: {
            RepairPrimaryButton(title: "Continue", tokens: tokens) {
                viewModel.goNext(from: .birthDate)
            }
        }
    }
}

struct RepairAccountabilityStep: View {
    @Bindable var viewModel: RepairSetupViewModel
    let tokens: SkyPaletteTokens

    var body: some View {
        RepairSetupScaffold(
            tokens: tokens,
            inscription: "AN ESTIMATE · TOGETHER",
            title: "When did prayer become yours to keep?",
            subtitle: "Traditions place the age of accountability differently. Choose what fits your understanding — a scholar can weigh it precisely."
        ) {
            VStack(spacing: IhsanSpacing.lg) {
                RepairStepperField(
                    value: $viewModel.draft.accountabilityAgeYears,
                    range: 7...21,
                    unitLabel: "years old",
                    tokens: tokens
                )
                RepairArithmeticCard(
                    estimate: viewModel.estimate,
                    averageExcusedDaysPerMonth: viewModel.draft.averageExcusedDaysPerMonth,
                    stage: .began,
                    tokens: tokens
                )
            }
        } actions: {
            RepairPrimaryButton(title: "Continue", tokens: tokens) {
                viewModel.goNext(from: .accountabilityAge)
            }
        }
    }
}

struct RepairPrayerBeganStep: View {
    @Bindable var viewModel: RepairSetupViewModel
    let tokens: SkyPaletteTokens

    var body: some View {
        RepairSetupScaffold(
            tokens: tokens,
            inscription: "AN ESTIMATE · TOGETHER",
            title: "When did you begin praying consistently?",
            subtitle: "Roughly is fine. The estimate is yours to adjust."
        ) {
            VStack(spacing: IhsanSpacing.lg) {
                DatePicker(
                    "Consistent prayer began",
                    selection: $viewModel.draft.consistentPrayerBegan,
                    in: ...Date.now,
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)

                RepairArithmeticCard(
                    estimate: viewModel.estimate,
                    averageExcusedDaysPerMonth: viewModel.draft.averageExcusedDaysPerMonth,
                    stage: .span,
                    tokens: tokens
                )
            }
        } actions: {
            RepairPrimaryButton(title: "Continue", tokens: tokens) {
                viewModel.goNext(from: .prayerBegan)
            }
        }
    }
}

struct RepairExcusedDaysStep: View {
    @Bindable var viewModel: RepairSetupViewModel
    let tokens: SkyPaletteTokens

    var body: some View {
        RepairSetupScaffold(
            tokens: tokens,
            inscription: "AN ESTIMATE · TOGETHER",
            title: "Were some days excused each month?",
            subtitle: "Excused days were never yours to make up. They are simply set aside. Leave this at zero if it doesn't apply."
        ) {
            VStack(spacing: IhsanSpacing.lg) {
                RepairStepperField(
                    value: $viewModel.draft.averageExcusedDaysPerMonth,
                    range: 0...15,
                    unitLabel: "days each month",
                    tokens: tokens
                )
                RepairArithmeticCard(
                    estimate: viewModel.estimate,
                    averageExcusedDaysPerMonth: viewModel.draft.averageExcusedDaysPerMonth,
                    stage: .obligated,
                    tokens: tokens
                )
            }
        } actions: {
            RepairPrimaryButton(title: "Continue", tokens: tokens) {
                viewModel.goNext(from: .excusedDays)
            }
        }
    }
}

struct RepairReviewStep: View {
    @Bindable var viewModel: RepairSetupViewModel
    let tokens: SkyPaletteTokens

    var body: some View {
        RepairSetupScaffold(
            tokens: tokens,
            inscription: "AN ESTIMATE · TOGETHER",
            title: "Your starting point.",
            subtitle: nil
        ) {
            ScrollView {
                VStack(spacing: IhsanSpacing.md) {
                    VStack(spacing: 0) {
                        ForEach(QadaCategory.fardCategories, id: \.rawValue) { category in
                            countRow(
                                name: category.displayNameEnglish,
                                count: viewModel.estimate.perCategory[category] ?? 0
                            )
                        }
                    }
                    .padding(.vertical, IhsanSpacing.xs)
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(tokens.panelFill)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(tokens.panelStroke, lineWidth: 1)
                    }

                    RepairArithmeticCard(
                        estimate: viewModel.estimate,
                        averageExcusedDaysPerMonth: viewModel.draft.averageExcusedDaysPerMonth,
                        stage: .obligated,
                        tokens: tokens
                    )

                    Text("Schools count missed prayers differently, and your own obligation is best weighed with a qualified scholar. These numbers are a starting point, and they stay yours to adjust.")
                        .font(IhsanFont.citation)
                        .foregroundStyle(tokens.inkSecondary)
                        .shadow(color: tokens.inkHalo, radius: 2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        } actions: {
            RepairPrimaryButton(title: "This looks right", tokens: tokens) {
                viewModel.goNext(from: .review)
            }
        }
    }

    private func countRow(name: String, count: Int) -> some View {
        HStack {
            Text(name)
                .font(IhsanFont.rowPrayerName)
                .foregroundStyle(tokens.ink)
            Spacer()
            Text(count.formatted(.number.grouping(.automatic)))
                .font(IhsanFont.tabular)
                .foregroundStyle(tokens.ink)
        }
        .padding(.horizontal, IhsanSpacing.md)
        .padding(.vertical, IhsanSpacing.sm)
        .accessibilityElement(children: .combine)
    }
}

struct RepairWitrStep: View {
    @Bindable var viewModel: RepairSetupViewModel
    let tokens: SkyPaletteTokens

    @State private var showsManualWitrCount = false

    var body: some View {
        RepairSetupScaffold(
            tokens: tokens,
            inscription: "ONE MORE CHOICE",
            title: "Track witr as well?",
            subtitle: "Schools differ on witr's standing. Tracking it here is your choice, not a ruling."
        ) {
            if showsManualWitrCount {
                VStack(spacing: 0) {
                    RepairCategoryCountRow(
                        category: .witr,
                        count: Binding(
                            get: { viewModel.draft.witrManualCount },
                            set: { viewModel.draft.witrManualCount = max(0, $0) }
                        ),
                        tokens: tokens
                    )
                }
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(tokens.panelFill)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(tokens.panelStroke, lineWidth: 1)
                }
            } else {
                EmptyView()
            }
        } actions: {
            if showsManualWitrCount {
                RepairPrimaryButton(title: "Continue", tokens: tokens) {
                    viewModel.goNext(from: .witr)
                }
            } else {
                RepairPrimaryButton(title: "Track witr", tokens: tokens) {
                    viewModel.draft.tracksWitr = true
                    if viewModel.chosePathManually {
                        withAnimation(.snappy(duration: 0.2)) {
                            showsManualWitrCount = true
                        }
                    } else {
                        viewModel.goNext(from: .witr)
                    }
                }
                RepairGhostButton(title: "Skip witr", tokens: tokens) {
                    viewModel.draft.tracksWitr = false
                    viewModel.goNext(from: .witr)
                }
            }
        }
    }
}

struct RepairMissedFlowStep: View {
    @Bindable var viewModel: RepairSetupViewModel
    let tokens: SkyPaletteTokens

    var body: some View {
        RepairSetupScaffold(
            tokens: tokens,
            inscription: "ONE MORE CHOICE",
            title: "If a prayer goes unlogged",
            subtitle: "When a day ends and a prayer has no record, Ihsan can add it to your makeup count. Nothing is added on paused days. You can change this anytime in Set."
        ) {
            EmptyView()
        } actions: {
            RepairPrimaryButton(title: "Add it here", tokens: tokens) {
                viewModel.draft.missedFlowEnabled = true
                viewModel.goNext(from: .missedFlow)
            }
            RepairGhostButton(title: "Leave it be", tokens: tokens) {
                viewModel.draft.missedFlowEnabled = false
                viewModel.goNext(from: .missedFlow)
            }
        }
    }
}

struct RepairClosingStep: View {
    @Bindable var viewModel: RepairSetupViewModel
    let tokens: SkyPaletteTokens
    let onFinished: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var saveHiccup = false

    var body: some View {
        RepairSetupScaffold(
            tokens: tokens,
            inscription: "RETURNING",
            title: "The return is itself beloved.",
            subtitle: "One prayer at a time, at your pace. The thread grows on your Path."
        ) {
            if saveHiccup {
                Text("Couldn't save just now. Try again.")
                    .font(IhsanFont.bodyEnglish)
                    .foregroundStyle(tokens.inkSecondary)
                    .shadow(color: tokens.inkHalo, radius: 2)
            } else {
                EmptyView()
            }
        } actions: {
            RepairPrimaryButton(title: "Begin", tokens: tokens) {
                do {
                    try viewModel.finish(in: modelContext)
                    Haptics.success()
                    onFinished()
                } catch {
                    saveHiccup = true
                    Haptics.notification(.warning)
                }
            }
        }
    }
}
