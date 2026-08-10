import Foundation
import SwiftData

/// The single mutation boundary for Khatam plans and entries.
@MainActor
public struct KhatamPlanWriter {
    public init() {}

    @discardableResult
    public func begin(
        startDate: Date,
        endDate: Date,
        unit: KhatamUnit,
        mushafPageTotal: Int = 604,
        targetCount: Int = 1,
        isRamadan: Bool,
        now: Date = .now,
        in context: ModelContext
    ) throws -> KhatamPlan {
        let plans = try context.fetch(FetchDescriptor<KhatamPlan>())
        for plan in plans where plan.isActive {
            plan.retiredAt = now
            plan.modifiedAt = now
        }
        let plan = KhatamPlan(
            startDate: startDate,
            endDate: max(startDate, endDate),
            unit: unit,
            mushafPageTotal: mushafPageTotal,
            targetCount: targetCount,
            isRamadan: isRamadan,
            createdAt: now,
            modifiedAt: now
        )
        context.insert(plan)
        try context.save()
        return plan
    }

    @discardableResult
    public func log(
        units: Int,
        on date: Date,
        after prayer: Prayer? = nil,
        for plan: KhatamPlan,
        now: Date = .now,
        in context: ModelContext
    ) throws -> KhatamEntry {
        let entry = KhatamEntry(
            planID: plan.id,
            entryDate: date,
            unitsRead: max(1, units),
            afterPrayer: prayer,
            createdAt: now,
            modifiedAt: now
        )
        context.insert(entry)
        try settleCompletion(of: plan, now: now, in: context)
        try context.save()
        return entry
    }

    public func update(
        _ entry: KhatamEntry,
        units: Int,
        date: Date,
        after prayer: Prayer?,
        now: Date = .now,
        in context: ModelContext
    ) throws {
        entry.unitsRead = max(1, units)
        entry.entryDate = date
        entry.afterPrayer = prayer
        entry.modifiedAt = now
        if let plan = try plan(id: entry.planID, in: context) {
            try settleCompletion(of: plan, now: now, in: context)
        }
        try context.save()
    }

    public func remove(
        _ entry: KhatamEntry,
        now: Date = .now,
        in context: ModelContext
    ) throws {
        let planID = entry.planID
        context.delete(entry)
        if let plan = try plan(id: planID, in: context) {
            plan.completedAt = nil
            plan.modifiedAt = now
        }
        try context.save()
    }

    public func markCompletionMomentShown(
        for plan: KhatamPlan,
        at date: Date = .now,
        in context: ModelContext
    ) throws {
        guard plan.completedAt != nil, plan.completionMomentShownAt == nil else { return }
        plan.completionMomentShownAt = date
        plan.modifiedAt = date
        try context.save()
    }

    private func settleCompletion(
        of plan: KhatamPlan,
        now: Date,
        in context: ModelContext
    ) throws {
        let id = plan.id
        let entries = try context.fetch(FetchDescriptor<KhatamEntry>(
            predicate: #Predicate { $0.planID == id }
        ))
        let total = entries.reduce(0) { $0 + $1.unitsRead }
        plan.completedAt = total >= plan.targetUnits ? (plan.completedAt ?? now) : nil
        plan.modifiedAt = now
    }

    private func plan(id: UUID, in context: ModelContext) throws -> KhatamPlan? {
        try context.fetch(FetchDescriptor<KhatamPlan>(
            predicate: #Predicate { $0.id == id }
        )).first
    }
}
