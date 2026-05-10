import SwiftUI
import IhsanCore
import IhsanDesignSystem

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Conditionally rendered "Reflections this period" card. Hidden entirely on
/// hardware that doesn't support Apple Intelligence — no greyed-out state,
/// no upgrade prompt; the user simply doesn't see it.
///
/// V1 emits a deterministic template summary built from the aggregate. The
/// real on-device generation lands in a separate `IhsanInsights` package.
struct InsightCard: View {
    let aggregate: TrajectoryAggregate

    var body: some View {
        if isAppleIntelligenceAvailable {
            VStack(alignment: .leading, spacing: IhsanSpacing.md) {
                Text("REFLECTIONS THIS PERIOD")
                    .font(IhsanFont.inscription)
                    .tracking(1.8)
                    .foregroundStyle(IhsanColor.brassDark)

                Text(generatedSummary)
                    .font(IhsanFont.bodyEnglish)
                    .foregroundStyle(IhsanColor.inkDeep)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: IhsanSpacing.xs) {
                    Image(systemName: "cpu")
                        .font(.system(size: 10, weight: .semibold))
                    Text("GENERATED ON-DEVICE")
                        .font(IhsanFont.inscription)
                        .tracking(1.4)
                }
                .foregroundStyle(IhsanColor.brassDark.opacity(0.70))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(IhsanSpacing.lg)
            .ihsanIlluminatedPanel(intensity: .regular)
        }
    }

    /// Apple Intelligence availability gate. Returns `false` whenever the
    /// `FoundationModels` framework isn't present (older OS or simulator
    /// without AI) or the on-device model isn't ready, in which case the
    /// card disappears completely.
    private var isAppleIntelligenceAvailable: Bool {
        #if canImport(FoundationModels)
        switch SystemLanguageModel.default.availability {
        case .available: return true
        default: return false
        }
        #else
        return false
        #endif
    }

    /// V1: deterministic, factual observations only. The IhsanInsights
    /// package will later replace this with a `@Generable` model call.
    /// TODO: Replace with `InsightGenerator` from IhsanInsights.
    private var generatedSummary: String {
        let perPrayer = aggregate.perPrayer
        guard let most = perPrayer.max(by: { $0.onTimeCount < $1.onTimeCount }),
              let least = perPrayer.min(by: { $0.onTimeCount < $1.onTimeCount }) else {
            return ""
        }

        var sentences: [String] = []

        sentences.append(
            "\(most.prayer.displayNameEnglish) was prayed on time on "
            + "\(most.onTimeCount) of \(most.totalActiveDays) days."
        )

        if least.prayer != most.prayer {
            sentences.append(
                "\(least.prayer.displayNameEnglish) was prayed on time on "
                + "\(least.onTimeCount) of \(least.totalActiveDays) days."
            )
        }

        if aggregate.qadaCount > 0 {
            let prayerWord = aggregate.qadaCount == 1 ? "prayer" : "prayers"
            sentences.append(
                "\(aggregate.qadaCount) \(prayerWord) made up as qada."
            )
        }

        if aggregate.travelingDays > 0 {
            let dayWord = aggregate.travelingDays == 1 ? "day" : "days"
            sentences.append("\(aggregate.travelingDays) \(dayWord) traveling.")
        }

        return sentences.joined(separator: " ")
    }
}
