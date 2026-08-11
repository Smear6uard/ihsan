import IhsanCore
import IhsanDesignSystem
import SwiftData
import SwiftUI

@MainActor
struct KhatamDetailScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.nowProvider) private var nowProvider
    @Query(sort: \KhatamPlan.createdAt, order: .reverse) private var plans: [KhatamPlan]
    @Query(sort: \KhatamEntry.entryDate, order: .reverse) private var entries: [KhatamEntry]
    @Query(sort: \PauseInterval.startDate, order: .reverse) private var pauses: [PauseInterval]
    @Query private var settingsRows: [UserSettings]

    @State private var logRequest: KhatamLogRequest?
    @State private var recentEntry: KhatamEntry?
    @State private var showingSetup = false
    @State private var showingSettings = false
    @State private var actionError: String?

    private var tokens: SkyPaletteTokens {
        IhsanPageChrome.tokens(at: nowProvider.now())
    }

    private var activePlan: KhatamPlan? {
        KhatamSurfaceModel.activePlan(in: plans)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: IhsanSpacing.lg) {
                    header
                    if let plan = activePlan {
                        activeContent(plan)
                    } else {
                        completedContent
                    }
                    Color.clear.frame(height: IhsanSpacing.xl)
                }
                .padding(IhsanSpacing.md)
            }
            .ihsanManuscriptPage()
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(item: $logRequest) { request in
            KhatamLogSheet(
                plan: request.plan,
                suggested: request.suggested,
                perPrayer: request.perPrayer,
                prefill: request.prefill,
                initialDate: request.initialDate,
                prayer: request.prayer,
                editing: request.entry
            ) { entry in
                recentEntry = entry
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingSettings) {
            if let plan = activePlan {
                KhatamPlanSettingsSheet(plan: plan)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .fullScreenCover(isPresented: $showingSetup) {
            KhatamSetupFlow()
        }
        .overlay {
            if let completed = plans.first(where: {
                $0.completedAt != nil && $0.completionMomentShownAt == nil
            }) {
                KhatamCompletionMoment(
                    plan: completed,
                    tokens: tokens,
                    onUndo: latestEntry(for: completed).map { entry in
                        {
                            do {
                                try KhatamPlanWriter().remove(
                                    entry,
                                    now: nowProvider.now(),
                                    in: modelContext
                                )
                            } catch {
                                actionError = error.localizedDescription
                            }
                        }
                    }
                )
                    .transition(.opacity)
            }
        }
        .alert("The change could not be saved", isPresented: Binding(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(actionError ?? "")
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Khatam")
                    .font(.system(size: 32, weight: .medium, design: .serif))
                    .foregroundStyle(tokens.ink)
                Text("YOUR MUSHAF · YOUR PACE")
                    .font(IhsanFont.inscription)
                    .tracking(1.7)
                    .foregroundStyle(tokens.inkSecondary)
            }
            Spacer()
            Button("Done") { dismiss() }
                .font(IhsanFont.bodyEnglish)
                .foregroundStyle(tokens.ink)
                .frame(minWidth: 44, minHeight: 44)
        }
    }

    @ViewBuilder
    private func activeContent(_ plan: KhatamPlan) -> some View {
        let planEntries = KhatamSurfaceModel.entries(for: plan, from: entries)
        let read = KhatamSurfaceModel.totalRead(for: plan, entries: planEntries)
        let pace = KhatamSurfaceModel.pace(
            for: plan,
            entries: planEntries,
            pauses: pauses,
            today: nowProvider.now()
        )
        let paused = KhatamSurfaceModel.isPaused(on: nowProvider.now(), pauses: pauses)

        VStack(alignment: .leading, spacing: IhsanSpacing.lg) {
            VStack(alignment: .leading, spacing: IhsanSpacing.md) {
                KhatamThreadView(
                    read: read,
                    target: plan.targetUnits,
                    unit: plan.unit,
                    tokens: tokens,
                    terminalSize: 24
                )
                .frame(height: 46)

                HStack(alignment: .firstTextBaseline) {
                    Text("\(read.formatted()) of \(plan.targetUnits.formatted()) \(plan.unit.pluralLabel)")
                        .font(IhsanFont.bodyEnglish)
                        .foregroundStyle(tokens.ink)
                    Spacer()
                    Text(plan.endDate.formatted(date: .abbreviated, time: .omitted).uppercased())
                        .font(IhsanFont.inscription)
                        .foregroundStyle(tokens.inkSecondary)
                }

                if paused {
                    Text("PLAN RESTING · LOGGING REMAINS OPEN")
                        .font(IhsanFont.inscription)
                        .tracking(1.2)
                        .foregroundStyle(tokens.inkSecondary)
                } else {
                    Text("TODAY · \(KhatamSurfaceModel.unitLine(pace.suggestedToday, unit: plan.unit).uppercased())")
                        .font(IhsanFont.inscription)
                        .tracking(1.2)
                        .foregroundStyle(tokens.inkSecondary)
                    if let forecast = pace.forecastCompletionDate {
                        Text(KhatamSurfaceModel.forecastInscription(
                            forecast,
                            offsetDays: settingsRows.first?.hijriCalendarOffsetDays ?? 0
                        ))
                        .font(IhsanFont.inscription)
                        .tracking(1.2)
                        .foregroundStyle(tokens.inkSecondary)
                    } else {
                        Text("Choose a daily intention when you’re ready.")
                            .font(IhsanFont.bodyEnglish)
                            .foregroundStyle(tokens.inkSecondary)
                    }
                }
            }
            .padding(IhsanSpacing.md)
            .celestialPanel(tokens: tokens, cornerRadius: 18)

            Button {
                Haptics.impact(.light)
                logRequest = KhatamLogRequest(
                    plan: plan,
                    suggested: pace.suggestedToday,
                    perPrayer: pace.perPrayerSuggestion,
                    initialDate: nowProvider.now(),
                    prefill: max(1, pace.perPrayerSuggestion)
                )
            } label: {
                Label("Log reading", systemImage: "plus")
                    .font(IhsanFont.bodyEnglishBold)
                    .foregroundStyle(tokens.keyline)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(tokens.leafGold, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityHint(paused ? "Logging stays available while the plan is resting" : "Opens the numeric reading stepper")

            Button {
                Haptics.impact(.light)
                showingSettings = true
            } label: {
                HStack {
                    Text("Plan settings")
                        .font(IhsanFont.bodyEnglish)
                    Spacer()
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(tokens.inkSecondary)
                }
                .foregroundStyle(tokens.ink)
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)

            if let recentEntry, recentEntry.planID == plan.id {
                undoStrip(recentEntry)
            }

            entryLedger(plan: plan, pace: pace, planEntries: planEntries)
        }
    }

    private func entryLedger(
        plan: KhatamPlan,
        pace: KhatamPace,
        planEntries: [KhatamEntry]
    ) -> some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
            Text("READING LOG")
                .font(IhsanFont.inscription)
                .tracking(1.6)
                .foregroundStyle(tokens.inkSecondary)

            if planEntries.isEmpty {
                Text("Your first numeric entry will rest here.")
                    .font(IhsanFont.bodyEnglish)
                    .foregroundStyle(tokens.inkSecondary)
                    .padding(.vertical, IhsanSpacing.md)
            } else {
                ForEach(planEntries.sorted { $0.entryDate > $1.entryDate }) { entry in
                    Button {
                        Haptics.impact(.light)
                        logRequest = KhatamLogRequest(
                            plan: plan,
                            suggested: pace.suggestedToday,
                            perPrayer: pace.perPrayerSuggestion,
                            initialDate: nowProvider.now(),
                            entry: entry
                        )
                    } label: {
                        HStack(spacing: IhsanSpacing.md) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(entry.entryDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(IhsanFont.bodyEnglish)
                                if let prayer = entry.afterPrayer {
                                    Text("AFTER \(prayer.displayNameEnglish.uppercased())")
                                        .font(IhsanFont.inscription)
                                        .foregroundStyle(tokens.inkSecondary)
                                }
                            }
                            Spacer()
                            Text(KhatamSurfaceModel.unitLine(entry.unitsRead, unit: plan.unit))
                                .font(.system(.body, design: .monospaced))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(tokens.inkSecondary)
                        }
                        .foregroundStyle(tokens.ink)
                        .frame(minHeight: 52)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens this entry for editing")
                    Divider().overlay(tokens.panelStroke)
                }
            }
        }
    }

    private func undoStrip(_ entry: KhatamEntry) -> some View {
        HStack {
            Text("Reading recorded")
                .font(IhsanFont.bodyEnglish)
                .foregroundStyle(tokens.inkSecondary)
            Spacer()
            Button("Undo") {
                Haptics.impact(.light)
                do {
                    try KhatamPlanWriter().remove(entry, in: modelContext)
                    recentEntry = nil
                } catch {
                    actionError = error.localizedDescription
                }
            }
            .font(IhsanFont.bodyEnglishBold)
            .foregroundStyle(tokens.inkSecondary)
            .frame(minWidth: 44, minHeight: 44)
        }
        .padding(.horizontal, IhsanSpacing.md)
        .background(tokens.panelFill.opacity(0.72), in: Capsule())
        .accessibilityElement(children: .contain)
    }

    private var completedContent: some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.lg) {
            if let latest = plans.first(where: { $0.completedAt != nil }),
               let completedAt = latest.completedAt {
                VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
                    Text("COMPLETED · \(completedAt.formatted(date: .long, time: .omitted).uppercased())")
                        .font(IhsanFont.inscription)
                        .tracking(1.3)
                        .foregroundStyle(tokens.inkSecondary)
                    Text("A completed reading, held quietly.")
                        .font(IhsanFont.bodyEnglish)
                        .foregroundStyle(tokens.ink)
                }
                .padding(IhsanSpacing.md)
                .celestialPanel(tokens: tokens, cornerRadius: 16)

                let planEntries = KhatamSurfaceModel.entries(for: latest, from: entries)
                let pace = KhatamSurfaceModel.pace(
                    for: latest,
                    entries: planEntries,
                    pauses: pauses,
                    today: nowProvider.now()
                )
                entryLedger(plan: latest, pace: pace, planEntries: planEntries)
            } else {
                Text("Begin when the period feels right.")
                    .font(IhsanFont.bodyEnglish)
                    .foregroundStyle(tokens.inkSecondary)
            }

            Button("Begin another Khatam") {
                Haptics.impact(.light)
                showingSetup = true
            }
            .font(IhsanFont.bodyEnglishBold)
            .foregroundStyle(tokens.keyline)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(tokens.leafGold, in: Capsule())
            .buttonStyle(.plain)
        }
    }

    private func latestEntry(for plan: KhatamPlan) -> KhatamEntry? {
        entries.first { $0.planID == plan.id }
    }
}

private struct KhatamLogRequest: Identifiable {
    let id = UUID()
    let plan: KhatamPlan
    let suggested: Int
    let perPrayer: Int
    let initialDate: Date
    var prefill: Int?
    var prayer: Prayer?
    var entry: KhatamEntry?
}

@MainActor
private struct KhatamPlanSettingsSheet: View {
    let plan: KhatamPlan

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.nowProvider) private var nowProvider
    @State private var endDate: Date
    @State private var pageTotal: Int
    @State private var targetCount: Int
    @State private var saveError: String?

    init(plan: KhatamPlan) {
        self.plan = plan
        _endDate = State(initialValue: plan.endDate)
        _pageTotal = State(initialValue: plan.mushafPageTotal)
        _targetCount = State(initialValue: plan.targetCount)
    }

    private var tokens: SkyPaletteTokens {
        IhsanPageChrome.tokens(at: nowProvider.now())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: IhsanSpacing.lg) {
                Text("PLAN SETTINGS")
                    .font(IhsanFont.inscription)
                    .tracking(1.6)
                    .foregroundStyle(tokens.inkSecondary)
                DatePicker("Horizon", selection: $endDate, in: plan.startDate..., displayedComponents: .date)
                if plan.unit == .pages {
                    Stepper("Pages in your mushaf · \(pageTotal)", value: $pageTotal, in: 1...2_000)
                }
                Stepper("Completions · \(targetCount)", value: $targetCount, in: 1...10)
                Button("Keep settings") {
                    Haptics.settle()
                    do {
                        try KhatamPlanWriter().updatePlan(
                            plan,
                            endDate: endDate,
                            mushafPageTotal: pageTotal,
                            targetCount: targetCount,
                            now: nowProvider.now(),
                            in: modelContext
                        )
                        dismiss()
                    } catch {
                        saveError = error.localizedDescription
                    }
                }
                .font(IhsanFont.bodyEnglishBold)
                .foregroundStyle(tokens.keyline)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(tokens.leafGold, in: Capsule())
                .buttonStyle(.plain)
            }
            .padding(IhsanSpacing.lg)
        }
        .font(IhsanFont.bodyEnglish)
        .foregroundStyle(tokens.ink)
        .presentationBackground(.thinMaterial)
        .alert("The plan could not be saved", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }
}

@MainActor
private struct KhatamCompletionMoment: View {
    let plan: KhatamPlan
    let tokens: SkyPaletteTokens
    let onUndo: (() -> Void)?

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            tokens.groundGradient.ignoresSafeArea()
            VStack(spacing: IhsanSpacing.xl) {
                Spacer()
                KhatamThreadView(
                    read: plan.targetUnits,
                    target: plan.targetUnits,
                    unit: plan.unit,
                    tokens: tokens,
                    terminalSize: 30
                )
                .frame(width: 250, height: 58)
                Text("The reading is complete.")
                    .font(IhsanFont.heroPrayerName)
                    .foregroundStyle(tokens.ink)
                    .multilineTextAlignment(.center)
                Spacer()
                Button("Continue") {
                    Haptics.impact(.soft)
                    try? KhatamPlanWriter().markCompletionMomentShown(
                        for: plan,
                        in: modelContext
                    )
                }
                .font(IhsanFont.bodyEnglish)
                .foregroundStyle(tokens.ink)
                .frame(minWidth: 120, minHeight: 52)
                if let onUndo {
                    Button("Undo last entry") {
                        Haptics.impact(.light)
                        onUndo()
                    }
                    .font(IhsanFont.bodyEnglish)
                    .foregroundStyle(tokens.inkSecondary)
                    .frame(minWidth: 120, minHeight: 44)
                }
                Spacer().frame(height: IhsanSpacing.md)
            }
            .padding(IhsanSpacing.lg)
        }
        .task { Haptics.impact(.soft) }
        .accessibilityElement(children: .contain)
    }
}
