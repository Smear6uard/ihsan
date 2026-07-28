import Foundation
import SwiftData

/// Materialized per-category counts for makeup worship. One row per tracked
/// category. The row's counts are always derivable from the `QadaEntry` log
/// (`QadaMath.materialize`); they are stored so surfaces can read state
/// without replaying history.
@Model
public final class QadaLedger {
    public var id: UUID = UUID()

    public var categoryRaw: String = QadaCategory.fajr.rawValue
    public var remainingCount: Int = 0
    public var madeUpCount: Int = 0

    public var createdAt: Date = Date.distantPast
    public var modifiedAt: Date = Date.distantPast

    public init(
        id: UUID = UUID(),
        category: QadaCategory,
        remainingCount: Int = 0,
        madeUpCount: Int = 0,
        createdAt: Date = .now,
        modifiedAt: Date = .now
    ) {
        self.id = id
        self.categoryRaw = category.rawValue
        self.remainingCount = remainingCount
        self.madeUpCount = madeUpCount
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

public extension QadaLedger {
    var category: QadaCategory? {
        QadaCategory(rawValue: categoryRaw)
    }
}
