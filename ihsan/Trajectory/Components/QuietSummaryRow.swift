import SwiftUI
import IhsanCore
import IhsanDesignSystem

/// The five factual counts a quiet summary can draw. This narrow value
/// also lets privacy-sensitive renderers receive only what they use,
/// instead of a wider aggregate carrying pause or travel metadata.
struct QuietSummary: Equatable, Sendable {
    let onTimeCount: Int
    let jamaahCount: Int
    let lateCount: Int
    let missedCount: Int
    let qadaCount: Int

    init(aggregate: TrajectoryAggregate) {
        onTimeCount = aggregate.onTimeCount
        jamaahCount = aggregate.jamaahCount
        lateCount = aggregate.lateCount
        missedCount = aggregate.missedCount
        qadaCount = aggregate.qadaCount
    }
}

/// A single quiet line of period-summary counts.
///
/// The gestalt dot grid above does the work of *showing* the user's
/// pattern; this row's job is just to *count*, quietly, in the
/// manuscript palette's inscriptional small caps.
///
///     ON TIME: 47   JAMĀʿAH: 13   DELAYED: 5   MISSED: 2   QADĀ: 3
///
/// One line if it fits, otherwise as few as it needs — and `QuietRowLayout`
/// spreads the stats evenly across those rows rather than packing the
/// first one full and leaving a single orphan below it.
struct QuietSummaryRow: View {
    let summary: QuietSummary
    let tokens: SkyPaletteTokens

    init(aggregate: TrajectoryAggregate, tokens: SkyPaletteTokens) {
        self.init(summary: QuietSummary(aggregate: aggregate), tokens: tokens)
    }

    init(summary: QuietSummary, tokens: SkyPaletteTokens) {
        self.summary = summary
        self.tokens = tokens
    }

    var body: some View {
        QuietRowLayout(spacing: IhsanSpacing.lg, rowSpacing: IhsanSpacing.xs) {
            ForEach(entries, id: \.label) { entry in
                stat(label: entry.label, count: entry.count)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private func stat(label: String, count: Int) -> some View {
        HStack(spacing: 4) {
            Text("\(label):")
                .font(IhsanFont.inscription)
                .tracking(1.4)
                .foregroundStyle(tokens.inkSecondary)
            Text("\(count)")
                .font(IhsanFont.tabular)
                .foregroundStyle(tokens.ink)
        }
        .fixedSize()
    }

    private var entries: [(label: String, count: Int)] {
        [
            (PrayerStatus.onTime.inscription, summary.onTimeCount),
            (IhsanVocabulary.jamaahInscription, summary.jamaahCount),
            (PrayerStatus.late.inscription, summary.lateCount),
            (PrayerStatus.missed.inscription, summary.missedCount),
            (PrayerStatus.qada.inscription, summary.qadaCount)
        ]
    }

    private var accessibilityLabel: String {
        "\(PrayerStatus.onTime.displayName): \(summary.onTimeCount). "
        + "\(IhsanVocabulary.jamaahTitle): \(summary.jamaahCount). "
        + "\(PrayerStatus.late.displayName): \(summary.lateCount). "
        + "\(PrayerStatus.missed.displayName): \(summary.missedCount). "
        + "\(PrayerStatus.qada.displayName): \(summary.qadaCount)."
    }
}

/// Flow layout that places its children on as few rows as needed,
/// then spreads them evenly ACROSS those rows. Used by
/// `QuietSummaryRow` so the five inscription stats land on one line on
/// wide screens and reflow to two on narrow ones without any explicit
/// breakpoint logic.
///
/// The two-step matters. A plain greedy fill packs row one until the
/// next item will not fit and drops the remainder below, which for five
/// stats on an iPhone means four across the top and a single stranded
/// `QADĀ: 0` underneath — it reads as a mistake rather than a line.
/// Finding the row count greedily and *then* balancing gives 3 + 2.
struct QuietRowLayout: Layout {
    let spacing: CGFloat
    let rowSpacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = computeRows(width: width, subviews: subviews)
        let height = rows.reduce(into: CGFloat(0)) { partial, row in
            partial += row.maxHeight
        } + CGFloat(max(0, rows.count - 1)) * rowSpacing
        return CGSize(width: width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        let rows = computeRows(width: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            let totalContent = row.sizes.reduce(0) { $0 + $1.width }
            let spacingCount = max(0, row.indices.count - 1)
            let totalSpacing = bounds.width - totalContent
            let gap = spacingCount > 0 ? totalSpacing / CGFloat(spacingCount) : 0
            var x = bounds.minX
            for (i, idx) in row.indices.enumerated() {
                subviews[idx].place(
                    at: CGPoint(x: x, y: y + (row.maxHeight - row.sizes[i].height) / 2),
                    proposal: ProposedViewSize(width: row.sizes[i].width, height: row.sizes[i].height)
                )
                x += row.sizes[i].width + gap
            }
            y += row.maxHeight + rowSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var sizes: [CGSize] = []
        var maxHeight: CGFloat = 0
    }

    private func computeRows(width: CGFloat, subviews: Subviews) -> [Row] {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        guard !sizes.isEmpty else { return [] }

        let rowCount = Self.minimumRowCount(width: width, sizes: sizes, spacing: spacing)
        let split = Self.balancedSplit(
            width: width, sizes: sizes, spacing: spacing, rowCount: rowCount
        )

        return split.map { indices in
            var row = Row()
            for i in indices {
                row.indices.append(i)
                row.sizes.append(sizes[i])
                row.maxHeight = max(row.maxHeight, sizes[i].height)
            }
            return row
        }
    }

    /// How few rows the items can possibly occupy, found the ordinary
    /// greedy way. This is only the *count*; which item lands where is
    /// decided afterwards.
    static func minimumRowCount(
        width: CGFloat, sizes: [CGSize], spacing: CGFloat
    ) -> Int {
        var rows = 1
        var consumed: CGFloat = 0
        for size in sizes {
            let prospective = consumed == 0 ? size.width : consumed + spacing + size.width
            if prospective > width && consumed > 0 {
                rows += 1
                consumed = size.width
            } else {
                consumed = prospective
            }
        }
        return rows
    }

    /// Distributes the items across exactly `rowCount` rows as evenly as
    /// their widths allow, preserving order.
    ///
    /// Even means by count, not by pixels: the stats are short and of
    /// similar length, and an equal number per row is what reads as
    /// deliberate. A row that would overflow takes fewer items — never
    /// more — so balancing can lengthen a line but can never break one.
    static func balancedSplit(
        width: CGFloat, sizes: [CGSize], spacing: CGFloat, rowCount: Int
    ) -> [[Int]] {
        guard rowCount > 1 else { return [Array(sizes.indices)] }

        var rows: [[Int]] = []
        var remaining = Array(sizes.indices)

        for row in 0..<rowCount {
            let rowsLeft = rowCount - row
            // Ceiling division, so any remainder lands on the earlier
            // rows: five items over two rows reads 3 + 2, not 2 + 3.
            let target = (remaining.count + rowsLeft - 1) / rowsLeft
            var taken: [Int] = []
            var consumed: CGFloat = 0
            for index in remaining.prefix(target) {
                let w = sizes[index].width
                let prospective = taken.isEmpty ? w : consumed + spacing + w
                if prospective > width && !taken.isEmpty { break }
                taken.append(index)
                consumed = prospective
            }
            // Defensive: a single item wider than the row still has to
            // be placed, or the loop cannot make progress.
            if taken.isEmpty, let first = remaining.first { taken = [first] }
            rows.append(taken)
            remaining.removeFirst(taken.count)
            if remaining.isEmpty { break }
        }

        // Anything left over (only reachable when the widths defeated
        // the even split) trails on its own line rather than vanishing.
        if !remaining.isEmpty { rows.append(remaining) }
        return rows
    }
}

#Preview("Quiet summary — typical month") {
    let perPrayer = Prayer.allCases.map { prayer in
        TrajectoryAggregate.PrayerAggregate(
            prayer: prayer,
            onTimeCount: 26,
            lateCount: 2,
            missedCount: 1,
            qadaCount: 1,
            totalActiveDays: 30
        )
    }
    let aggregate = TrajectoryAggregate(
        totalActiveDays: 30,
        pausedDays: 0,
        travelingDays: 2,
        totalLogged: 142,
        totalPossible: 150,
        onTimeCount: 47,
        lateCount: 5,
        missedCount: 2,
        qadaCount: 3,
        jamaahCount: 13,
        perPrayer: perPrayer
    )
    return VStack {
        Spacer()
        QuietSummaryRow(aggregate: aggregate, tokens: PaletteState.afternoon.tokens)
            .padding(.horizontal, IhsanSpacing.md)
        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .ihsanManuscriptPage()
}
