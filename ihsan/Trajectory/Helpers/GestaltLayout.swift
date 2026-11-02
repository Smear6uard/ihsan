import CoreGraphics
import Foundation

/// The pattern card's column grid, as a value.
///
/// Every row on the card — the five fardh rows and the rows beneath
/// them — is positioned from this one type, and so is the column a
/// finger lands on. A mark that is one pitch out of step reads as
/// debris rather than as a row, and a touch that resolves to the wrong
/// column edits the wrong day. `GestaltLayoutTests` holds these to each
/// other, column by column, at every period and width.
///
/// The columns divide the whole width after the labels: at seven days
/// the marks spread out rather than huddling at the left, and "Today"
/// on the axis sits over the column it means.
///
/// Coordinates are measured from the leading edge of the whole block,
/// label gutter included, so a caller can reason about the row and the
/// label in one space.
struct GestaltLayout: Equatable {

    let columnCount: Int
    /// Diameter of one fardh dot.
    let dotSize: CGFloat
    /// Distance from one column's centre to the next.
    let pitch: CGFloat
    /// Width reserved at the leading edge for the row labels.
    let labelGutter: CGFloat
    /// Height of every row on the card. Always room for its label: a
    /// row nobody can name is the defect these labels exist to repair.
    let rowHeight: CGFloat

    init(
        period: TrajectoryPeriod,
        availableWidth: CGFloat,
        labelGutter: CGFloat = 0,
        labelHeight: CGFloat = 0
    ) {
        let columns = Self.columnCount(for: period)
        let spec = Self.spec(for: period)

        // The gutter never takes more than a quarter of the card. A
        // reader at the largest type sizes on the narrowest phone can
        // otherwise ask for a label wider than the pattern it names.
        let gutter = min(labelGutter, availableWidth * 0.25)
        let gridWidth = max(0, availableWidth - gutter)
        let pitch = gridWidth / CGFloat(columns)

        self.columnCount = columns
        self.labelGutter = gutter
        self.pitch = pitch
        self.dotSize = min(spec.dot, pitch * spec.fill)
        self.rowHeight = max(spec.rowHeight, labelHeight)
    }

    // MARK: - Column geometry

    /// Gap between adjacent marks.
    var spacing: CGFloat { pitch - dotSize }

    /// Below this a hollow ring has no line to draw, so the long
    /// periods mark each prayer with a tick the height of its row:
    /// `GestaltTick` instead of `GestaltDot`.
    static let tickThreshold: CGFloat = 5

    var drawsTicks: Bool { dotSize < Self.tickThreshold }

    /// The x-centre of the fardh mark in `column`.
    func prayerDotCenter(column: Int) -> CGFloat {
        columnOrigin(column) + pitch / 2
    }

    /// The x-centre of the presence mark in `column`.
    ///
    /// Deliberately its own function rather than an alias: the two are
    /// required to agree, and a requirement no test can see is not a
    /// requirement. They are held equal in `GestaltLayoutTests`.
    func presenceMarkCenter(column: Int) -> CGFloat {
        columnOrigin(column) + pitch / 2
    }

    /// Presence marks are drawn at the fardh dot's size — one size
    /// rule for the whole card, so a mark can never be a fraction of a
    /// pitch out of step with the column it belongs to.
    var presenceMarkSize: CGFloat { dotSize }

    func columnOrigin(_ column: Int) -> CGFloat {
        labelGutter + CGFloat(column) * pitch
    }

    /// The column under a touch. A touch in the label gutter means the
    /// first column; one past the end means the last. Nobody aiming at
    /// a day should get nothing for missing it by a point.
    func column(atX x: CGFloat) -> Int {
        guard pitch > 0 else { return 0 }
        let raw = Int(((x - labelGutter) / pitch).rounded(.down))
        return min(max(raw, 0), columnCount - 1)
    }

    /// Total width the grid occupies, gutter included.
    var totalWidth: CGFloat {
        labelGutter + CGFloat(columnCount) * pitch
    }

    // MARK: - Per-period specification

    private struct Spec {
        /// The dot's ideal diameter.
        let dot: CGFloat
        /// The most of a column's width the dot may take.
        let fill: CGFloat
        let rowHeight: CGFloat
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
            return Spec(dot: 20, fill: 0.70, rowHeight: 28)
        case .thirtyDays:
            return Spec(dot: 8, fill: 0.84, rowHeight: 18)
        case .ninetyDays:
            return Spec(dot: 2.4, fill: 0.78, rowHeight: 18)
        case .year:
            return Spec(dot: 4, fill: 0.78, rowHeight: 18)
        }
    }
}
