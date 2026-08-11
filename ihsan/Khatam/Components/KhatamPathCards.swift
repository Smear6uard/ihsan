import IhsanCore
import IhsanDesignSystem
import SwiftData
import SwiftUI

struct KhatamRamadanOfferCard: View {
    let onBegin: () -> Void
    let onDismiss: () -> Void

    private var tokens: SkyPaletteTokens { PaletteState.sunset.tokens }

    var body: some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
            Text("RAMADAN")
                .font(IhsanFont.inscription)
                .tracking(1.6)
                .foregroundStyle(tokens.inkSecondary)

            Text("Ramadan is here — pace a reading of the Qur’an.")
                .font(IhsanFont.bodyEnglish)
                .foregroundStyle(tokens.ink)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: IhsanSpacing.md) {
                Button("Begin") {
                    Haptics.impact(.light)
                    onBegin()
                }
                .font(IhsanFont.bodyEnglishBold)
                .foregroundStyle(tokens.keyline)
                .padding(.horizontal, IhsanSpacing.md)
                .frame(minHeight: 44)
                .background(tokens.leafGold, in: Capsule())
                .buttonStyle(.plain)
                .accessibilityIdentifier("khatam-ramadan-begin")

                Button("Not now") {
                    Haptics.impact(.light)
                    onDismiss()
                }
                .font(IhsanFont.bodyEnglish)
                .foregroundStyle(tokens.inkSecondary)
                .frame(minHeight: 44)
                .buttonStyle(.plain)
            }
        }
        .padding(IhsanSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(SRGBValue.mix(
                    tokens.panelFillValue,
                    tokens.groundPlaneValue,
                    amount: 0.30
                ).color)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tokens.panelStroke, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }
}

struct KhatamSection: View {
    let onOpen: () -> Void

    @Query(sort: \KhatamPlan.createdAt, order: .reverse) private var plans: [KhatamPlan]
    @Query(sort: \KhatamEntry.entryDate) private var entries: [KhatamEntry]
    @Query(sort: \PauseInterval.startDate, order: .reverse) private var pauses: [PauseInterval]
    @Query private var settingsRows: [UserSettings]
    @Environment(\.nowProvider) private var nowProvider

    private var tokens: SkyPaletteTokens {
        IhsanPageChrome.tokens(at: nowProvider.now())
    }

    var body: some View {
        if let plan = KhatamSurfaceModel.activePlan(in: plans) {
            let today = nowProvider.now()
            let planEntries = KhatamSurfaceModel.entries(for: plan, from: entries)
            let read = KhatamSurfaceModel.totalRead(for: plan, entries: planEntries)
            let pace = KhatamSurfaceModel.pace(
                for: plan, entries: planEntries, pauses: pauses, today: today
            )
            let paused = KhatamSurfaceModel.isPaused(on: today, pauses: pauses)

            Button {
                Haptics.impact(.light)
                onOpen()
            } label: {
                VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
                    Text("KHATAM")
                        .font(IhsanFont.inscription)
                        .tracking(1.6)
                        .foregroundStyle(tokens.inkSecondary)

                    KhatamThreadView(
                        read: read,
                        target: plan.targetUnits,
                        unit: plan.unit,
                        tokens: tokens,
                        terminalSize: 18
                    )
                    .frame(height: 32)

                    if paused {
                        Text("PLAN RESTING")
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
                            Text("A DAILY INTENTION, WHEN YOU’RE READY")
                                .font(IhsanFont.inscription)
                                .tracking(1.2)
                                .foregroundStyle(tokens.inkSecondary)
                        }
                    }
                }
                .padding(IhsanSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .celestialPanel(tokens: tokens, cornerRadius: 14)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel(plan: plan, pace: pace, read: read, paused: paused))
            .accessibilityHint("Opens the Khatam plan and recitation log")
        }
    }

    private func accessibilityLabel(
        plan: KhatamPlan,
        pace: KhatamPace,
        read: Int,
        paused: Bool
    ) -> String {
        var parts = ["Khatam", "\(read) of \(plan.targetUnits) \(plan.unit.pluralLabel) read"]
        if paused {
            parts.append("plan resting")
        } else {
            parts.append("today, \(KhatamSurfaceModel.unitLine(pace.suggestedToday, unit: plan.unit))")
        }
        return parts.joined(separator: ", ")
    }
}
