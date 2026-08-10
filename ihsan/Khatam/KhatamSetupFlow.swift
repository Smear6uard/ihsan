import IhsanCore
import IhsanDesignSystem
import SwiftData
import SwiftUI

@MainActor
struct KhatamSetupFlow: View {
    var prefersRamadan = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.nowProvider) private var nowProvider
    @Query private var settingsRows: [UserSettings]

    @State private var stage = Stage.period
    @State private var periodIsRamadan = false
    @State private var startDate = Date.now
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 29, to: .now) ?? .now
    @State private var unit = KhatamUnit.pages
    @State private var pageTotal = 604
    @State private var targetCount = 1
    @State private var saveError: String?

    private enum Stage: Int { case period, measure, arithmetic }

    private var tokens: SkyPaletteTokens { PaletteState.sunset.tokens }

    var body: some View {
        ZStack {
            tokens.groundGradient.ignoresSafeArea()

            VStack(alignment: .leading, spacing: IhsanSpacing.md) {
                HStack {
                    Text("KHATAM · \(stage.rawValue + 1) OF 3")
                        .font(IhsanFont.inscription)
                        .tracking(1.6)
                        .foregroundStyle(tokens.metal)
                    Spacer()
                    Button("Close") { dismiss() }
                        .font(IhsanFont.bodyEnglish)
                        .foregroundStyle(tokens.inkSecondary)
                        .frame(minWidth: 44, minHeight: 44)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: IhsanSpacing.lg) {
                        titleBlock
                        stageContent
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, IhsanSpacing.xs)
                }
                actions
            }
            .padding(IhsanSpacing.lg)
        }
        .environment(\.colorScheme, .dark)
        .onAppear(perform: preparePeriod)
        .alert("The plan could not be saved", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }

    @ViewBuilder
    private var titleBlock: some View {
        switch stage {
        case .period:
            setupTitle("Choose a period", subtitle: "A date can hold the intention without becoming a verdict.")
        case .measure:
            setupTitle("Count from your own mushaf", subtitle: "Ihsan records numbers only. Your mushaf stays with you.")
        case .arithmetic:
            setupTitle("A steady measure", subtitle: nil)
        }
    }

    private func setupTitle(_ title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
            Text(title)
                .font(IhsanFont.heroPrayerName)
                .foregroundStyle(tokens.ink)
            if let subtitle {
                Text(subtitle)
                    .font(IhsanFont.bodyEnglish)
                    .foregroundStyle(tokens.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var stageContent: some View {
        switch stage {
        case .period:
            VStack(spacing: IhsanSpacing.md) {
                if currentRamadanContext.isCurrentlyRamadan {
                    KhatamChoiceRow(
                        title: "This Ramadan",
                        subtitle: ramadanRangeLabel,
                        selected: periodIsRamadan,
                        tokens: tokens
                    ) { chooseRamadan() }
                }
                KhatamChoiceRow(
                    title: "Custom dates",
                    subtitle: "Choose a beginning and a gentle horizon",
                    selected: !periodIsRamadan,
                    tokens: tokens
                ) { periodIsRamadan = false }

                if !periodIsRamadan {
                    DatePicker("Begins", selection: $startDate, displayedComponents: .date)
                    DatePicker("Horizon", selection: $endDate, in: startDate..., displayedComponents: .date)
                }
            }
            .font(IhsanFont.bodyEnglish)
            .foregroundStyle(tokens.ink)

        case .measure:
            VStack(alignment: .leading, spacing: IhsanSpacing.md) {
                Picker("Measure", selection: $unit) {
                    Text("Pages").tag(KhatamUnit.pages)
                    Text("Juz’").tag(KhatamUnit.juz)
                }
                .pickerStyle(.segmented)

                if unit == .pages {
                    Stepper(value: $pageTotal, in: 1...2_000) {
                        KhatamNumberRow(label: "Pages in your mushaf", value: pageTotal, tokens: tokens)
                    }
                }
                Stepper(value: $targetCount, in: 1...10) {
                    KhatamNumberRow(label: "Completions", value: targetCount, tokens: tokens)
                }
            }

        case .arithmetic:
            VStack(alignment: .leading, spacing: IhsanSpacing.lg) {
                KhatamThreadView(read: 0, target: targetUnits, tokens: tokens, terminalSize: 24)
                    .frame(height: 46)

                Text(arithmeticLine)
                    .font(IhsanFont.heroPrayerName)
                    .foregroundStyle(tokens.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(periodIsRamadan ? "RAMADAN · AT YOUR PACE" : "AT YOUR PACE · AROUND \(endDate.formatted(.dateTime.month(.wide).day()))")
                    .font(IhsanFont.inscription)
                    .tracking(1.4)
                    .foregroundStyle(tokens.metal)
            }
            .padding(IhsanSpacing.md)
            .celestialPanel(tokens: tokens, cornerRadius: 18)
        }
    }

    @ViewBuilder
    private var actions: some View {
        Button(stage == .arithmetic ? "Begin the plan" : "Continue") {
            Haptics.impact(.light)
            if stage == .arithmetic { save() } else { advance() }
        }
        .font(IhsanFont.bodyEnglishBold)
        .foregroundStyle(tokens.keyline)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(tokens.leafGold, in: Capsule())
        .buttonStyle(.plain)

        if stage != .period {
            Button("Back") {
                Haptics.impact(.light)
                stage = Stage(rawValue: stage.rawValue - 1) ?? .period
            }
            .font(IhsanFont.bodyEnglish)
            .foregroundStyle(tokens.inkSecondary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .buttonStyle(.plain)
        }
    }

    private var currentRamadanContext: RamadanContext {
        RamadanContext(
            at: nowProvider.now(),
            offsetDays: settingsRows.first?.hijriCalendarOffsetDays ?? 0
        )
    }

    private var ramadanRangeLabel: String {
        "\(startDate.formatted(date: .abbreviated, time: .omitted)) – \(endDate.formatted(date: .abbreviated, time: .omitted))"
    }

    private var targetUnits: Int {
        (unit == .pages ? max(1, pageTotal) : 30) * max(1, targetCount)
    }

    private var activeDayCount: Int {
        max(1, (Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0) + 1)
    }

    private var arithmeticLine: String {
        let daily = Double(targetUnits) / Double(activeDayCount)
        let roundedDaily = max(1, Int(daily.rounded()))
        if unit == .pages {
            let perPrayer = max(1, Int((daily / 5).rounded()))
            return "About \(roundedDaily) pages a day — around \(perPrayer) after each prayer."
        }
        return "About \(roundedDaily) \(roundedDaily == 1 ? unit.singularLabel : unit.pluralLabel) a day, held across the day as you choose."
    }

    private func preparePeriod() {
        if (prefersRamadan || currentRamadanContext.isCurrentlyRamadan),
           currentRamadanContext.isCurrentlyRamadan {
            chooseRamadan()
        } else {
            let now = nowProvider.now()
            startDate = Calendar.current.startOfDay(for: now)
            endDate = Calendar.current.date(byAdding: .day, value: 29, to: startDate) ?? startDate
        }
    }

    private func chooseRamadan() {
        let now = Calendar.current.startOfDay(for: nowProvider.now())
        let elapsed = max(0, (currentRamadanContext.daysIntoRamadan ?? 1) - 1)
        let remaining = max(0, currentRamadanContext.daysRemainingInRamadan ?? 0)
        startDate = Calendar.current.date(byAdding: .day, value: -elapsed, to: now) ?? now
        endDate = Calendar.current.date(byAdding: .day, value: remaining, to: now) ?? now
        periodIsRamadan = true
    }

    private func advance() {
        if stage == .period, endDate < startDate { endDate = startDate }
        stage = Stage(rawValue: stage.rawValue + 1) ?? .arithmetic
    }

    private func save() {
        do {
            _ = try KhatamPlanWriter().begin(
                startDate: Calendar.current.startOfDay(for: startDate),
                endDate: Calendar.current.startOfDay(for: max(startDate, endDate)),
                unit: unit,
                mushafPageTotal: pageTotal,
                targetCount: targetCount,
                isRamadan: periodIsRamadan,
                now: nowProvider.now(),
                in: modelContext
            )
            Haptics.settle()
            dismiss()
        } catch {
            Haptics.notification(.warning)
            saveError = error.localizedDescription
        }
    }
}

private struct KhatamChoiceRow: View {
    let title: String
    let subtitle: String
    let selected: Bool
    let tokens: SkyPaletteTokens
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: IhsanSpacing.md) {
                ZStack {
                    Circle().stroke(tokens.metal.opacity(0.7), lineWidth: 1)
                    if selected { Circle().fill(tokens.leafGold).padding(4) }
                }
                .frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(IhsanFont.bodyEnglishBold)
                    Text(subtitle).font(IhsanFont.inscription).foregroundStyle(tokens.inkSecondary)
                }
                Spacer()
            }
            .foregroundStyle(tokens.ink)
            .padding(IhsanSpacing.md)
            .background(tokens.panelFill, in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selected ? tokens.metal : tokens.panelStroke, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct KhatamNumberRow: View {
    let label: String
    let value: Int
    let tokens: SkyPaletteTokens

    var body: some View {
        HStack {
            Text(label).font(IhsanFont.bodyEnglish).foregroundStyle(tokens.ink)
            Spacer()
            Text(value.formatted()).font(.system(.title3, design: .monospaced)).foregroundStyle(tokens.ink)
        }
    }
}
