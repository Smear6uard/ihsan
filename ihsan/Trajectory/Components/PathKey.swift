import SwiftUI
import IhsanCore
import IhsanDesignSystem

/// The key to the pattern above it, and the period's only counts.
///
/// These were two things, and neither could do its job alone. The marks
/// had no explanation anywhere on the screen, and the counts sat in a
/// colon-separated line that read as a scoreboard, with nothing to tie
/// "Delayed" to the hollow ring it counted. Putting each number beside
/// the mark it counts answers "what does this mean?" and "how many?"
/// together.
///
/// "Missed" and "No record" are separate lines on purpose. One is
/// something a person told the app; the other is something the app does
/// not know, and running them together is what made "Missed: 0" beside
/// sixteen blank marks look like a mistake.
struct PathKey: View {
    let tally: PathTally
    let period: TrajectoryPeriod
    let tokens: SkyPaletteTokens

    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .footnote) private var markSize: CGFloat = 13

    /// A mark and its count. On Time sits beside the jamāʿah halo, which
    /// is the gold form with a ring: the pair teach each other.
    private struct Entry: Identifiable {
        let label: String
        let count: Int
        let completion: PrayerCompletion
        var id: String { label }
    }

    private var entries: [Entry] {
        func mark(_ status: PrayerStatus?, jamaah: Bool = false) -> PrayerCompletion {
            PrayerCompletion(prayer: .fajr, status: status, withJamaah: jamaah)
        }
        return [
            Entry(label: PrayerStatus.onTime.sentenceName, count: tally.onTime, completion: mark(.onTime)),
            Entry(label: "In \(IhsanVocabulary.jamaah)", count: tally.inJamaah, completion: mark(.onTime, jamaah: true)),
            Entry(label: PrayerStatus.late.sentenceName, count: tally.delayed, completion: mark(.late)),
            Entry(label: PrayerStatus.qada.sentenceName, count: tally.qada, completion: mark(.qada)),
            Entry(label: PrayerStatus.missed.sentenceName, count: tally.missed, completion: mark(.missed)),
            Entry(label: "No record", count: tally.noRecord, completion: mark(nil))
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
            Text("\(tally.recorded) of \(tally.counted) prayers recorded")
                .font(IhsanFont.bodyEnglishBold)
                .foregroundStyle(tokens.ink)
                .fixedSize(horizontal: false, vertical: true)

            Grid(
                alignment: .leading,
                horizontalSpacing: IhsanSpacing.lg,
                verticalSpacing: IhsanSpacing.xs
            ) {
                ForEach(rows.indices, id: \.self) { index in
                    GridRow {
                        ForEach(rows[index]) { entry in
                            cell(entry)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Two columns, until the type is too large to share a line.
    private var rows: [[Entry]] {
        let width = typeSize.isAccessibilitySize ? 1 : 2
        return stride(from: 0, to: entries.count, by: width).map {
            Array(entries[$0..<min($0 + width, entries.count)])
        }
    }

    private func cell(_ entry: Entry) -> some View {
        HStack(spacing: IhsanSpacing.sm) {
            mark(entry.completion)
                .frame(width: markSize, height: markSize)
                .accessibilityHidden(true)
            Text(entry.label)
                .font(.footnote)
                .foregroundStyle(tokens.inkSecondary)
            Spacer(minLength: IhsanSpacing.xs)
            Text(entry.count, format: .number)
                .font(.footnote.weight(.semibold).monospacedDigit())
                .foregroundStyle(tokens.ink)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.label), \(entry.count)")
    }

    /// The key draws what the grid draws: rings where the grid has room
    /// for rings, ticks at the periods where it does not.
    @ViewBuilder
    private func mark(_ completion: PrayerCompletion) -> some View {
        if period == .ninetyDays || period == .year {
            GestaltTick(
                completion: completion,
                width: 3,
                height: markSize,
                tokens: tokens
            )
        } else {
            GestaltDot(completion: completion, size: markSize, tokens: tokens)
        }
    }
}
