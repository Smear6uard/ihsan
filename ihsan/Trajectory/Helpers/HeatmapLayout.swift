import CoreFoundation

/// Per-period geometry for the hero heatmap. The columns choice is what makes
/// the grid read as a coherent shape at each window — six columns for 30 days
/// gives a clean rectangle that fills the card; the year view runs twelve so
/// every column corresponds to roughly one month.
enum HeatmapLayout {
    static func columns(for period: TrajectoryPeriod) -> Int {
        switch period {
        case .sevenDays: return 7
        case .thirtyDays: return 6   // 6 × 5 = 30
        case .ninetyDays: return 9   // 9 × 10 = 90
        case .year: return 12        // 12 × ~31 ≈ 365
        }
    }

    static func rows(for period: TrajectoryPeriod) -> Int {
        let cols = columns(for: period)
        return (period.dayCount + cols - 1) / cols
    }

    static func dotDiameter(for period: TrajectoryPeriod) -> CGFloat {
        switch period {
        case .sevenDays: return 22
        case .thirtyDays: return 16
        case .ninetyDays: return 10
        case .year: return 6
        }
    }

    static func dotSpacing(for period: TrajectoryPeriod) -> CGFloat {
        switch period {
        case .sevenDays: return 12
        case .thirtyDays: return 10
        case .ninetyDays: return 7
        case .year: return 4
        }
    }
}
