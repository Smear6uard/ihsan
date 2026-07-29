import Foundation
import IhsanCore

/// One screen per question. The two paths share the closing tail:
/// manual — counts → witr → missedFlow → closing
/// estimate — birthDate → accountabilityAge → prayerBegan → excusedDays
///            → review → witr → missedFlow → closing
enum RepairSetupStep: Hashable {
    case manualCounts
    case birthDate
    case accountabilityAge
    case prayerBegan
    case excusedDays
    case review
    case witr
    case missedFlow
    case closing
}

/// Everything the user has told us so far, held in memory until the closing
/// screen commits once — mirroring the onboarding flow's single-commit shape.
struct RepairSetupDraft {
    var birthDate: Date
    var accountabilityAgeYears: Int = 14
    var consistentPrayerBegan: Date
    var averageExcusedDaysPerMonth: Int = 0
    var manualCounts: [QadaCategory: Int]
    var tracksWitr: Bool = false
    var witrManualCount: Int = 0
    var missedFlowEnabled: Bool = false

    init(now: Date = .now, calendar: Calendar = .current) {
        // Neutral starting points, not guesses about the person: birth date
        // opens 25 years back, consistent prayer at the present day.
        birthDate = calendar.date(byAdding: .year, value: -25, to: now) ?? now
        consistentPrayerBegan = now
        manualCounts = Dictionary(
            uniqueKeysWithValues: QadaCategory.fardCategories.map { ($0, 0) }
        )
    }
}
