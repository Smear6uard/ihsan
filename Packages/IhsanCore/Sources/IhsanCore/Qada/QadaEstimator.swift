import Foundation

public struct QadaEstimateInput: Equatable, Sendable {
    public var birthDate: Date
    public var accountabilityAgeYears: Int
    public var consistentPrayerBegan: Date
    /// Average days per month to deduct across the span (e.g. recurring
    /// excused days). 0 means no deduction.
    public var averageExcusedDaysPerMonth: Int
    public var includeWitr: Bool

    public init(
        birthDate: Date,
        accountabilityAgeYears: Int,
        consistentPrayerBegan: Date,
        averageExcusedDaysPerMonth: Int = 0,
        includeWitr: Bool = false
    ) {
        self.birthDate = birthDate
        self.accountabilityAgeYears = accountabilityAgeYears
        self.consistentPrayerBegan = consistentPrayerBegan
        self.averageExcusedDaysPerMonth = averageExcusedDaysPerMonth
        self.includeWitr = includeWitr
    }
}

/// The full arithmetic of an estimate, every intermediate exposed. The setup
/// UI renders these exact values as the math builds on screen, which is what
/// keeps the displayed arithmetic and the computed counts identical.
public struct QadaEstimate: Equatable, Sendable {
    public var accountabilityBegan: Date
    /// Whole days from `accountabilityBegan` to `consistentPrayerBegan`,
    /// never negative.
    public var spanDays: Int
    /// `spanDays / 30` — the month count used for the excused deduction.
    public var wholeMonths: Int
    /// `wholeMonths × averageExcusedDaysPerMonth`, capped at `spanDays`.
    public var excusedDaysDeducted: Int
    /// `spanDays − excusedDaysDeducted`.
    public var obligatedDays: Int
    /// One count per obligated day for each tracked category. Witr appears
    /// only when the input asked for it.
    public var perCategory: [QadaCategory: Int]
}

public enum QadaEstimator {
    public static func estimate(
        _ input: QadaEstimateInput,
        calendar: Calendar
    ) -> QadaEstimate {
        let accountabilityBegan = calendar.date(
            byAdding: .year,
            value: input.accountabilityAgeYears,
            to: input.birthDate
        ) ?? input.birthDate

        let rawSpan = calendar.dateComponents(
            [.day],
            from: accountabilityBegan,
            to: input.consistentPrayerBegan
        ).day ?? 0
        let spanDays = max(0, rawSpan)

        let wholeMonths = spanDays / 30
        let excusedDaysDeducted = min(
            wholeMonths * max(0, input.averageExcusedDaysPerMonth),
            spanDays
        )
        let obligatedDays = spanDays - excusedDaysDeducted

        var perCategory: [QadaCategory: Int] = [:]
        for category in QadaCategory.fardCategories {
            perCategory[category] = obligatedDays
        }
        if input.includeWitr {
            perCategory[.witr] = obligatedDays
        }

        return QadaEstimate(
            accountabilityBegan: accountabilityBegan,
            spanDays: spanDays,
            wholeMonths: wholeMonths,
            excusedDaysDeducted: excusedDaysDeducted,
            obligatedDays: obligatedDays,
            perCategory: perCategory
        )
    }
}
