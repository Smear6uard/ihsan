import IhsanCore
import IhsanDesignSystem
import SwiftData
import SwiftUI

@MainActor
struct KhatamLogSheet: View {
    let plan: KhatamPlan
    let suggested: Int
    let perPrayer: Int
    var prayer: Prayer?
    var editing: KhatamEntry?
    let initialDate: Date
    let onSaved: (KhatamEntry) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.nowProvider) private var nowProvider
    @State private var count: Int
    @State private var entryDate: Date
    @State private var saveError: String?

    init(
        plan: KhatamPlan,
        suggested: Int,
        perPrayer: Int,
        prefill: Int? = nil,
        initialDate: Date,
        prayer: Prayer? = nil,
        editing: KhatamEntry? = nil,
        onSaved: @escaping (KhatamEntry) -> Void
    ) {
        self.plan = plan
        self.suggested = suggested
        self.perPrayer = perPrayer
        self.prayer = prayer ?? editing?.afterPrayer
        self.editing = editing
        self.initialDate = initialDate
        self.onSaved = onSaved
        _count = State(initialValue: max(1, editing?.unitsRead ?? prefill ?? perPrayer))
        _entryDate = State(initialValue: editing?.entryDate ?? initialDate)
    }

    private var tokens: SkyPaletteTokens {
        IhsanPageChrome.tokens(at: nowProvider.now())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(editing == nil ? "LOG READING" : "EDIT READING")
                        .font(IhsanFont.inscription)
                        .tracking(1.6)
                        .foregroundStyle(tokens.metal)
                    if let prayer {
                        Text("After \(prayer.displayNameEnglish)")
                            .font(IhsanFont.bodyEnglish)
                            .foregroundStyle(tokens.inkSecondary)
                    }
                }
                Spacer()
                Button("Close") { dismiss() }
                    .font(IhsanFont.bodyEnglish)
                    .foregroundStyle(tokens.inkSecondary)
                    .frame(minWidth: 44, minHeight: 44)
            }

            HStack(spacing: IhsanSpacing.lg) {
                stepButton(systemName: "minus", label: "Subtract one") {
                    count = max(1, count - 1)
                }
                VStack(spacing: 3) {
                    Text(count.formatted())
                        .font(.system(size: 52, weight: .light, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(tokens.ink)
                        .contentTransition(.numericText())
                    Text((count == 1 ? plan.unit.singularLabel : plan.unit.pluralLabel).uppercased())
                        .font(IhsanFont.inscription)
                        .tracking(1.5)
                        .foregroundStyle(tokens.inkSecondary)
                }
                .frame(maxWidth: .infinity)
                stepButton(systemName: "plus", label: "Add one") {
                    count += 1
                }
            }

            HStack(spacing: IhsanSpacing.sm) {
                if perPrayer > 0 {
                    quickValue(perPrayer, label: "PER PRAYER")
                }
                if suggested > 0, suggested != perPrayer {
                    quickValue(suggested, label: "TODAY")
                }
            }

            DatePicker("Date", selection: $entryDate, in: ...nowProvider.now(), displayedComponents: .date)
                .font(IhsanFont.bodyEnglish)
                .foregroundStyle(tokens.ink)

            Button(editing == nil ? "Record" : "Keep changes") {
                save()
            }
            .font(IhsanFont.bodyEnglishBold)
            .foregroundStyle(tokens.keyline)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(tokens.leafGold, in: Capsule())
            .buttonStyle(.plain)
            .accessibilityHint("Records the numeric amount without opening reading content")
        }
        .padding(IhsanSpacing.lg)
        .presentationBackground(.thinMaterial)
        .alert("The entry could not be saved", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }

    private func stepButton(
        systemName: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.impact(.light)
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(tokens.ink)
                .frame(width: 64, height: 64)
                .background(tokens.panelFill, in: Circle())
                .overlay { Circle().stroke(tokens.metal.opacity(0.6), lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func quickValue(_ value: Int, label: String) -> some View {
        Button {
            Haptics.impact(.light)
            count = value
        } label: {
            VStack(spacing: 2) {
                Text(value.formatted()).font(.system(.headline, design: .monospaced))
                Text(label).font(IhsanFont.inscription).tracking(1.2)
            }
            .foregroundStyle(tokens.ink)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(tokens.panelFill, in: Capsule())
            .overlay { Capsule().stroke(tokens.panelStroke, lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(value) \(plan.unit.pluralLabel), \(label.lowercased()) suggestion")
    }

    private func save() {
        // Feedback lands before persistence. SwiftData then settles the
        // optimistic state in the same main-actor turn.
        Haptics.settle()
        do {
            let writer = KhatamPlanWriter()
            let saved: KhatamEntry
            if let editing {
                try writer.update(
                    editing,
                    units: count,
                    date: entryDate,
                    after: prayer,
                    now: nowProvider.now(),
                    in: modelContext
                )
                saved = editing
            } else {
                saved = try writer.log(
                    units: count,
                    on: entryDate,
                    after: prayer,
                    for: plan,
                    now: nowProvider.now(),
                    in: modelContext
                )
            }
            onSaved(saved)
            dismiss()
        } catch {
            Haptics.notification(.warning)
            saveError = error.localizedDescription
        }
    }
}
