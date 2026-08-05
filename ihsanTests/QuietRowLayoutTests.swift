import CoreGraphics
import Testing
@testable import ihsan

/// How the Path's summary stats break across lines.
///
/// A plain greedy fill packs the first row until the next item will not
/// fit and drops the remainder below. For five stats on an iPhone that
/// means four across the top and a single stranded `QADĀ: 0`
/// underneath, which reads as a mistake rather than a line — and
/// renaming LATE to the longer DELAYED made it more likely, not less.
@Suite("Quiet row layout")
struct QuietRowLayoutTests {

    private let spacing: CGFloat = 24

    private func sizes(_ widths: [CGFloat]) -> [CGSize] {
        widths.map { CGSize(width: $0, height: 14) }
    }

    /// Roughly the five inscription stats at default type size.
    private var fiveStats: [CGSize] {
        sizes([88, 96, 92, 84, 70])
    }

    private func split(width: CGFloat, sizes: [CGSize]) -> [[Int]] {
        let rows = QuietRowLayout.minimumRowCount(
            width: width, sizes: sizes, spacing: spacing
        )
        return QuietRowLayout.balancedSplit(
            width: width, sizes: sizes, spacing: spacing, rowCount: rows
        )
    }

    // MARK: - The repair

    @Test
    func fiveStatsOnAPhoneBreakThreeThenTwo() {
        let rows = split(width: 361, sizes: fiveStats)
        #expect(rows.map(\.count) == [3, 2])
    }

    @Test
    func aRemainderLandsOnTheEarlierRow() {
        // Never 2 + 3: the top line carries the extra, so the block
        // reads as settling rather than growing.
        let rows = split(width: 361, sizes: fiveStats)
        #expect(rows.first!.count >= rows.last!.count)
    }

    // MARK: - Everything it must not break

    @Test
    func oneWideRowStaysOneRow() {
        let rows = split(width: 1200, sizes: fiveStats)
        #expect(rows.count == 1)
        #expect(rows[0].count == 5)
    }

    @Test
    func everyItemIsPlacedExactlyOnce() {
        for width in stride(from: 120.0, through: 1200.0, by: 17.0) {
            let rows = split(width: CGFloat(width), sizes: fiveStats)
            let placed = rows.flatMap { $0 }.sorted()
            #expect(placed == Array(0..<5), "width \(width) placed \(placed)")
        }
    }

    @Test
    func orderIsPreserved() {
        for width in stride(from: 120.0, through: 1200.0, by: 17.0) {
            let placed = split(width: CGFloat(width), sizes: fiveStats).flatMap { $0 }
            #expect(placed == placed.sorted(), "width \(width) reordered")
        }
    }

    /// Balancing may lengthen a line but must never overflow one.
    @Test
    func balancingNeverOverflowsARow() {
        for width in stride(from: 120.0, through: 1200.0, by: 17.0) {
            let w = CGFloat(width)
            for row in split(width: w, sizes: fiveStats) where row.count > 1 {
                let content = row.reduce(CGFloat(0)) { $0 + fiveStats[$1].width }
                let total = content + spacing * CGFloat(row.count - 1)
                #expect(total <= w, "width \(w) row consumed \(total)")
            }
        }
    }

    /// An item wider than the whole row still has to be placed, or the
    /// layout loses a stat rather than clipping one.
    @Test
    func anOversizeItemIsStillPlaced() {
        let odd = sizes([400, 60, 60])
        let placed = split(width: 200, sizes: odd).flatMap { $0 }.sorted()
        #expect(placed == [0, 1, 2])
    }

    @Test
    func emptyInputProducesNoRows() {
        #expect(split(width: 361, sizes: []).flatMap { $0 }.isEmpty)
    }
}
