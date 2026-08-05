import CoreGraphics
import Foundation

/// The pattern card's column grid, as a value.
///
/// Every row on the card — the five fardh rows and the two presence
/// rows beneath them — is positioned from this one type. That is the
/// whole point of its existing: the presence marks used to be laid out
/// by their own HStack with their own idea of where a column was, and
/// a mark that is one pitch out of step reads as debris rather than as
/// a row. `GestaltLayoutTests` holds the two center functions to each
/// other, column by column, at every period and width.
///
/// Coordinates are measured from the leading edge of the whole block,
/// label gutter included, so a caller can reason about the row and the
/// label in one space.
struct GestaltLayout: Equatable {

    let columnCount: Int
    /// Diameter of one fardh dot.
    let dotSize: CGFloat
    /// Gap between adjacent dots.
    let spacing: CGFloat
    /// Width reserved at the leading edge for the row labels. Zero
    /// when no presence row is drawn — a card with nothing to label
    /// keeps its full width for the pattern.
    let labelGutter: CGFloat
    /// Height of one presence row. At the long periods the dots are a
    /// few points apart and a label is eleven, so the presence rows
    /// take the height they need; their marks stay dot-sized and
    /// dot-centred, and x never moves.
    let presenceRowHeight: CGFloat

    init(
        period: TrajectoryPeriod,
        availableWidth: CGFloat,
        labelGutter: CGFloat = 0,
        labelHeight: CGFloat = 0
    ) {
        let columns = Self.columnCount(for: period)
        let spec = Self.spec(for: period)
        let count = CGFloat(columns)

        // The gutter never takes more than a quarter of the card. A
        // reader at the largest type sizes on the narrowest phone can
        // otherwise ask for a label wider than the pattern it names.
        let gutter = availableWidth.isFinite
            ? min(labelGutter, availableWidth * 0.25)
            : labelGutter
        let gridWidth = max(0, availableWidth - gutter)
        let idealRowWidth = spec.dot * count + spec.dot * spec.spacingRatio * (count - 1)

        self.columnCount = columns
        self.labelGutter = gutter

        if gridWidth >= idealRowWidth {
            self.dotSize = spec.dot
            self.spacing = spec.dot * spec.spacingRatio
        } else {
            // Squeeze the dot proportionally so 90 / 52 columns still
            // fit on narrower iPhones rather than overflowing the panel.
            let proportional = gridWidth / (count + spec.spacingRatio * (count - 1))
            let dot = max(spec.minDot, min(spec.dot, proportional))
            let remaining = max(0, gridWidth - dot * count)
            let gap = max(spec.minSpacing, remaining / (count - 1))

            if dot * count + gap * (count - 1) <= gridWidth {
                self.dotSize = dot
                self.spacing = gap
            } else {
                // The per-period floors themselves no longer fit. Fit
                // is not negotiable — a column that renders past the
                // panel edge is off-grid by definition — so the whole
                // row scales down proportionally and the pattern
                // becomes the fine texture it was always going to be
                // at this width.
                self.dotSize = max(0, proportional)
                self.spacing = max(0, proportional * spec.spacingRatio)
            }
        }

        self.presenceRowHeight = max(self.dotSize, labelHeight)
    }

    // MARK: - Column geometry

    /// Distance from one column's centre to the next.
    var pitch: CGFloat { dotSize + spacing }

    /// The x-centre of the fardh dot in `column`.
    func prayerDotCenter(column: Int) -> CGFloat {
        columnOrigin(column) + dotSize / 2
    }

    /// The x-centre of the presence mark in `column`.
    ///
    /// Deliberately its own function rather than an alias: the two are
    /// required to agree, and a requirement no test can see is not a
    /// requirement. They are held equal in `GestaltLayoutTests`.
    func presenceMarkCenter(column: Int) -> CGFloat {
        columnOrigin(column) + dotSize / 2
    }

    /// Presence marks are drawn at the fardh dot's size — one size
    /// rule for the whole card, so a mark can never be a fraction of a
    /// pitch out of step with the column it belongs to.
    var presenceMarkSize: CGFloat { dotSize }

    private func columnOrigin(_ column: Int) -> CGFloat {
        labelGutter + CGFloat(column) * pitch
    }

    /// Total width the grid occupies, gutter included.
    var totalWidth: CGFloat {
        labelGutter + CGFloat(columnCount) * dotSize
            + CGFloat(max(0, columnCount - 1)) * spacing
    }

    // MARK: - Per-period specification

    private struct Spec {
        let dot: CGFloat
        let minDot: CGFloat
        let spacingRatio: CGFloat
        let minSpacing: CGFloat
    }

    static func columnCount(for period: TrajectoryPeriod) -> Int {
        switch period {
        case .sevenDays:  return 7
        case .thirtyDays: return 30
        case .ninetyDays: return 90
        case .year:       return 52
        }
    }

    private static func spec(for period: TrajectoryPeriod) -> Spec {
        switch period {
        case .sevenDays:
            return Spec(dot: 16, minDot: 12, spacingRatio: 0.50, minSpacing: 4)
        case .thirtyDays:
            return Spec(dot: 7,  minDot: 5,  spacingRatio: 0.43, minSpacing: 1.5)
        case .ninetyDays:
            return Spec(dot: 3,  minDot: 2,  spacingRatio: 0.30, minSpacing: 0.3)
        case .year:
            return Spec(dot: 5,  minDot: 3,  spacingRatio: 0.40, minSpacing: 0.5)
        }
    }

    /// The row spacing the card uses at each period, and the height the
    /// pattern block needs. Pinned per period rather than measured, so
    /// the parent's VStack has a stable height before layout runs.
    static func rowSpacing(for period: TrajectoryPeriod) -> CGFloat {
        switch period {
        case .sevenDays:  return 8
        case .thirtyDays: return 3
        case .ninetyDays: return 1.0
        case .year:       return 1.5
        }
    }
}
