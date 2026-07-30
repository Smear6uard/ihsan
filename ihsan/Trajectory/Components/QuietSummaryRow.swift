import SwiftUI
import IhsanCore
import IhsanDesignSystem

/// A single quiet line of period-summary counts.
///
/// The gestalt dot grid above does the work of *showing* the user's
/// pattern; this row's job is just to *count*, quietly, in the
/// manuscript palette's inscriptional small caps.
///
///     ON TIME: 47   JAMAʿAH: 13   LATE: 5   MISSED: 2   QADĀ: 3
///
/// One line if it fits, two if not (handled by `QuietRowLayout` below).
struct QuietSummaryRow: View {
    let aggregate: TrajectoryAggregate
    let tokens: SkyPaletteTokens

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
            ("ON TIME", aggregate.onTimeCount),
            (IhsanVocabulary.jamaahInscription, aggregate.jamaahCount),
            ("LATE",    aggregate.lateCount),
            ("MISSED",  aggregate.missedCount),
            ("QADĀ",    aggregate.qadaCount)
        ]
    }

    private var accessibilityLabel: String {
        "On time: \(aggregate.onTimeCount). "
        + "\(IhsanVocabulary.jamaahTitle): \(aggregate.jamaahCount). "
        + "Late: \(aggregate.lateCount). "
        + "Missed: \(aggregate.missedCount). "
        + "Qadā: \(aggregate.qadaCount)."
    }
}

/// Flow layout that places its children on as few rows as needed,
/// distributing them evenly within each row. Used by `QuietSummaryRow`
/// so the five inscription stats land on one line on wide screens and
/// reflow to two lines on narrow ones without any explicit breakpoint
/// logic.
private struct QuietRowLayout: Layout {
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
        var rows: [Row] = [Row()]
        var current = 0
        var consumed: CGFloat = 0
        for (i, sub) in subviews.enumerated() {
            let size = sub.sizeThatFits(.unspecified)
            let prospective = consumed == 0 ? size.width : consumed + spacing + size.width
            if prospective > width && !rows[current].indices.isEmpty {
                rows.append(Row())
                current += 1
                consumed = size.width
            } else {
                consumed = prospective
            }
            rows[current].indices.append(i)
            rows[current].sizes.append(size)
            rows[current].maxHeight = max(rows[current].maxHeight, size.height)
        }
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
            totalActiveDays: 30,
            dailyFractions: []
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
