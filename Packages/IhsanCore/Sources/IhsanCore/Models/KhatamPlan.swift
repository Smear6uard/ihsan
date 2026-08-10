import Foundation
import SwiftData

/// A finite numeric reading plan for a person's own mushaf.
///
/// Plans are retained in sequence. `retiredAt == nil && completedAt == nil`
/// identifies the one active plan; `KhatamPlanWriter` preserves that invariant.
@Model
public final class KhatamPlan {
    public var id: UUID = UUID()
    public var startDate: Date = Date.distantPast
    public var endDate: Date = Date.distantPast
    public var unitRaw: String = KhatamUnit.pages.rawValue
    public var mushafPageTotal: Int = 604
    public var targetCount: Int = 1
    public var isRamadan: Bool = false
    public var completedAt: Date?
    public var retiredAt: Date?
    public var completionMomentShownAt: Date?
    public var createdAt: Date = Date.distantPast
    public var modifiedAt: Date = Date.distantPast

    #Index<KhatamPlan>([\.createdAt], [\.completedAt], [\.retiredAt])

    public init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date,
        unit: KhatamUnit = .pages,
        mushafPageTotal: Int = 604,
        targetCount: Int = 1,
        isRamadan: Bool = false,
        completedAt: Date? = nil,
        retiredAt: Date? = nil,
        completionMomentShownAt: Date? = nil,
        createdAt: Date = .now,
        modifiedAt: Date = .now
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.unitRaw = unit.rawValue
        self.mushafPageTotal = max(1, mushafPageTotal)
        self.targetCount = max(1, targetCount)
        self.isRamadan = isRamadan
        self.completedAt = completedAt
        self.retiredAt = retiredAt
        self.completionMomentShownAt = completionMomentShownAt
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

public extension KhatamPlan {
    var unit: KhatamUnit {
        get { KhatamUnit(rawValue: unitRaw) ?? .pages }
        set { unitRaw = newValue.rawValue }
    }

    var unitsPerCompletion: Int {
        unit == .pages ? max(1, mushafPageTotal) : 30
    }

    var targetUnits: Int {
        unitsPerCompletion * max(1, targetCount)
    }

    var isActive: Bool {
        completedAt == nil && retiredAt == nil
    }
}
