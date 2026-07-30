import IhsanCore
import IhsanDesignSystem
import SwiftData
import SwiftUI

/// The full Repair surface: the thread as headline, remaining counts
/// typographically quiet beneath it, a calm "+1 made up" per category, a
/// compact multi-add for sets, and the pace line — a forecast when there is
/// one, a gentle invitation when there is not.
struct RepairDetailScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \QadaLedger.categoryRaw) private var ledgers: [QadaLedger]
    @Query(sort: \QadaEntry.createdAt) private var entries: [QadaEntry]
    @Query private var settingsRows: [UserSettings]

    @State private var viewModel: RepairViewModel?
    @State private var showingMultiAdd = false
    @State private var showingAdjust = false
    @State private var showingFastingEstimator = false

    private var tokens: SkyPaletteTokens {
        RepairPalette.tokens()
    }

    private var settings: UserSettings? {
        settingsRows.first
    }

    private var trackedLedgers: [QadaLedger] {
        orderedLedgers.filter { $0.remainingCount > 0 || $0.madeUpCount > 0 }
    }

    private var openLedgers: [QadaLedger] {
        orderedLedgers.filter { $0.remainingCount > 0 }
    }

    /// Ledger rows in day order (fajr → isha, witr, then the fasting
    /// thread last).
    private var orderedLedgers: [QadaLedger] {
        let order = QadaCategory.fardCategories + [.witr, .fasting]
        return order.compactMap { category in
            ledgers.first { $0.categoryRaw == category.rawValue }
        }
    }

    /// Whether the fasting thread has been opened at all — its
    /// estimator entry is offered only until it exists.
    private var hasFastingLedger: Bool {
        ledgers.contains { $0.categoryRaw == QadaCategory.fasting.rawValue }
    }

    private var totalRemaining: Int {
        ledgers.reduce(0) { $0 + $1.remainingCount }
    }

    private var totalMadeUp: Int {
        ledgers.reduce(0) { $0 + $1.madeUpCount }
    }

    private var overallProgress: Double {
        let whole = totalRemaining + totalMadeUp
        guard whole > 0 else {
            return 0
        }
        return Double(totalMadeUp) / Double(whole)
    }

    private var forecastDate: Date? {
        QadaPace.forecast(entries: entries, remaining: totalRemaining, asOf: .now)
    }

    var body: some View {
        ZStack {
            tokens.groundGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: IhsanSpacing.lg) {
                    header

                    RepairThreadView(progress: overallProgress, tokens: tokens, terminalSize: 22)
                        .frame(height: 44)

                    remainingStrip

                    paceLine

                    if let viewModel, viewModel.recentEntry != nil {
                        undoStrip(viewModel: viewModel)
                    }

                    if totalRemaining == 0 {
                        Text("Nothing remaining.")
                            .font(IhsanFont.bodyEnglish)
                            .foregroundStyle(tokens.inkSecondary)
                            .shadow(color: tokens.inkHalo, radius: 2)
                    } else {
                        categoryRows
                    }

                    footerActions
                }
                .padding(IhsanSpacing.lg)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .task {
            if viewModel == nil {
                viewModel = RepairViewModel(modelContext: modelContext)
            }
        }
        .sheet(isPresented: $showingMultiAdd) {
            if let viewModel {
                RepairMultiAddSheet(
                    viewModel: viewModel,
                    categories: openLedgers.compactMap(\.category),
                    tokens: tokens
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showingAdjust) {
            if let viewModel {
                RepairAdjustSheet(
                    viewModel: viewModel,
                    ledgers: orderedLedgers,
                    tokens: tokens
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showingFastingEstimator) {
            if let viewModel {
                RepairFastingEstimatorSheet(viewModel: viewModel, tokens: tokens)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
        .fullScreenCover(item: Binding(
            get: { viewModel?.zeroEvent },
            set: { viewModel?.zeroEvent = $0 }
        )) { event in
            RepairZeroMoment(event: event, tokens: tokens)
        }
        .environment(\.colorScheme, tokens.prefersDarkChrome ? .dark : .light)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: IhsanSpacing.xs) {
                Text("REPAIR")
                    .font(IhsanFont.inscription)
                    .tracking(1.6)
                    .foregroundStyle(tokens.metal)
                    .shadow(color: tokens.inkHalo, radius: 2)
                Text("The thread grows.")
                    .font(IhsanFont.heroPrayerName)
                    .foregroundStyle(tokens.ink)
                    .shadow(color: tokens.inkHalo, radius: 2)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer()
            Button {
                Haptics.impact(.light)
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(tokens.inkSecondary)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
    }

    /// Remaining counts, present but quiet — small caps, secondary ink,
    /// never the headline. Cleared categories fall away.
    private var remainingStrip: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 104), alignment: .leading)],
            alignment: .leading,
            spacing: IhsanSpacing.xs
        ) {
            ForEach(openLedgers, id: \.categoryRaw) { ledger in
                Text("\(ledger.category?.displayNameEnglish.uppercased() ?? ledger.categoryRaw.uppercased()) · \(ledger.remainingCount.formatted(.number.grouping(.automatic)))")
                    .font(IhsanFont.inscription)
                    .tracking(1.2)
                    .foregroundStyle(tokens.inkSecondary)
                    .shadow(color: tokens.inkHalo, radius: 2)
                    .accessibilityLabel("\(ledger.category?.displayNameEnglish ?? ""), \(ledger.remainingCount) remaining")
            }
        }
    }

    @ViewBuilder
    private var paceLine: some View {
        if let forecastDate {
            Text("At your pace, around \(forecastDate.formatted(.dateTime.month(.wide).year())).")
                .font(IhsanFont.bodyEnglish)
                .foregroundStyle(tokens.inkSecondary)
                .shadow(color: tokens.inkHalo, radius: 2)
        } else if totalRemaining > 0 {
            VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
                Text(settings?.qadaDailyIntentionEnabled == true
                     ? "One with each day, when you're ready."
                     : "When you're ready, one makeup can sit beside one daily prayer.")
                    .font(IhsanFont.bodyEnglish)
                    .foregroundStyle(tokens.inkSecondary)
                    .shadow(color: tokens.inkHalo, radius: 2)
                    .fixedSize(horizontal: false, vertical: true)

                if let settings, !settings.qadaDailyIntentionEnabled {
                    Button {
                        Haptics.impact(.light)
                        viewModel?.setDailyIntention(true, settings: settings)
                    } label: {
                        Text("Keep that intention with me")
                            .font(IhsanFont.bodyEnglish)
                            .foregroundStyle(tokens.ink)
                            .padding(.horizontal, IhsanSpacing.md)
                            .frame(minHeight: 40)
                            .overlay {
                                Capsule().stroke(tokens.metal.opacity(0.6), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func undoStrip(viewModel: RepairViewModel) -> some View {
        HStack(spacing: IhsanSpacing.sm) {
            Text("made up")
                .font(IhsanFont.bodyEnglish)
                .foregroundStyle(tokens.inkSecondary)
                .shadow(color: tokens.inkHalo, radius: 2)
            Text("·")
                .foregroundStyle(tokens.inkSecondary)
            Button {
                viewModel.undoRecent()
            } label: {
                Text("undo")
                    .font(IhsanFont.bodyEnglishBold)
                    .foregroundStyle(tokens.ink)
                    .shadow(color: tokens.inkHalo, radius: 2)
            }
            .buttonStyle(.plain)
        }
        .transition(.opacity)
        .accessibilityElement(children: .combine)
    }

    private var categoryRows: some View {
        VStack(spacing: 0) {
            ForEach(openLedgers, id: \.categoryRaw) { ledger in
                if let category = ledger.category {
                    HStack(spacing: IhsanSpacing.md) {
                        Text(category.displayNameEnglish)
                            .font(IhsanFont.rowPrayerName)
                            .foregroundStyle(tokens.ink)

                        Spacer(minLength: IhsanSpacing.sm)

                        Button {
                            withAnimation(.snappy(duration: 0.25)) {
                                viewModel?.logMadeUp(category: category)
                            }
                        } label: {
                            Text("+1 made up")
                                .font(IhsanFont.bodyEnglishBold)
                                .foregroundStyle(tokens.ink)
                                .padding(.horizontal, IhsanSpacing.md)
                                .frame(minHeight: 44)
                                .background {
                                    Capsule().fill(tokens.panelFill.opacity(0.7))
                                }
                                .overlay {
                                    Capsule().stroke(tokens.metal, lineWidth: 1.1)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            category == .fasting
                                ? "Log one makeup fast"
                                : "Log one \(category.displayNameEnglish) made up"
                        )
                    }
                    .padding(.horizontal, IhsanSpacing.md)
                    .padding(.vertical, IhsanSpacing.sm)
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

    private var footerActions: some View {
        HStack(spacing: IhsanSpacing.md) {
            if openLedgers.count > 0 {
                Button {
                    Haptics.impact(.light)
                    showingMultiAdd = true
                } label: {
                    Text("Add a set")
                        .font(IhsanFont.bodyEnglish)
                        .foregroundStyle(tokens.inkSecondary)
                        .shadow(color: tokens.inkHalo, radius: 2)
                        .frame(minHeight: 40)
                }
                .buttonStyle(.plain)
            }

            if !hasFastingLedger {
                Button {
                    Haptics.impact(.light)
                    showingFastingEstimator = true
                } label: {
                    Text("Add fasts")
                        .font(IhsanFont.bodyEnglish)
                        .foregroundStyle(tokens.inkSecondary)
                        .shadow(color: tokens.inkHalo, radius: 2)
                        .frame(minHeight: 40)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the fasting thread with a count you enter.")
            }

            Spacer()

            Button {
                Haptics.impact(.light)
                showingAdjust = true
            } label: {
                Text("Adjust counts")
                    .font(IhsanFont.bodyEnglish)
                    .foregroundStyle(tokens.inkSecondary)
                    .shadow(color: tokens.inkHalo, radius: 2)
                    .frame(minHeight: 40)
            }
            .buttonStyle(.plain)
        }
    }
}
