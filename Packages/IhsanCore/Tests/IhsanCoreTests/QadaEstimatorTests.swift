import Foundation
import Testing
@testable import IhsanCore

private var utcGregorian: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}

private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
    try #require(
        utcGregorian.date(from: DateComponents(year: year, month: month, day: day, hour: 12))
    )
}

@Test
func basicSpanYieldsOneCountPerFardPerDay() throws {
    let input = QadaEstimateInput(
        birthDate: try date(2000, 1, 1),
        accountabilityAgeYears: 14,
        consistentPrayerBegan: try date(2014, 1, 31),
        averageExcusedDaysPerMonth: 0,
        includeWitr: false
    )

    let estimate = QadaEstimator.estimate(input, calendar: utcGregorian)

    #expect(estimate.accountabilityBegan == (try date(2014, 1, 1)))
    #expect(estimate.spanDays == 30)
    #expect(estimate.excusedDaysDeducted == 0)
    #expect(estimate.obligatedDays == 30)
    for category in QadaCategory.fardCategories {
        #expect(estimate.perCategory[category] == 30)
    }
    #expect(estimate.perCategory[.witr] == nil)
}

@Test
func witrIncludedTracksSameDailyCount() throws {
    let input = QadaEstimateInput(
        birthDate: try date(2000, 1, 1),
        accountabilityAgeYears: 14,
        consistentPrayerBegan: try date(2014, 1, 31),
        averageExcusedDaysPerMonth: 0,
        includeWitr: true
    )

    let estimate = QadaEstimator.estimate(input, calendar: utcGregorian)

    #expect(estimate.perCategory[.witr] == 30)
}

@Test
func prayerBeganBeforeAccountabilityYieldsZero() throws {
    let input = QadaEstimateInput(
        birthDate: try date(2000, 1, 1),
        accountabilityAgeYears: 14,
        consistentPrayerBegan: try date(2012, 6, 1),
        averageExcusedDaysPerMonth: 0,
        includeWitr: false
    )

    let estimate = QadaEstimator.estimate(input, calendar: utcGregorian)

    #expect(estimate.spanDays == 0)
    #expect(estimate.obligatedDays == 0)
    for category in QadaCategory.fardCategories {
        #expect(estimate.perCategory[category] == 0)
    }
}

@Test
func zeroSpanYieldsZero() throws {
    let input = QadaEstimateInput(
        birthDate: try date(2000, 1, 1),
        accountabilityAgeYears: 14,
        consistentPrayerBegan: try date(2014, 1, 1),
        averageExcusedDaysPerMonth: 0,
        includeWitr: false
    )

    let estimate = QadaEstimator.estimate(input, calendar: utcGregorian)

    #expect(estimate.spanDays == 0)
    #expect(estimate.obligatedDays == 0)
}

@Test
func excusedDeductionReducesObligatedDays() throws {
    let input = QadaEstimateInput(
        birthDate: try date(2000, 1, 1),
        accountabilityAgeYears: 14,
        consistentPrayerBegan: try date(2015, 1, 1),
        averageExcusedDaysPerMonth: 6,
        includeWitr: false
    )

    let estimate = QadaEstimator.estimate(input, calendar: utcGregorian)

    #expect(estimate.spanDays == 365)
    #expect(estimate.wholeMonths == 12)
    #expect(estimate.excusedDaysDeducted == 72)
    #expect(estimate.obligatedDays == 293)
    #expect(estimate.perCategory[.fajr] == 293)
}

@Test
func excusedDeductionExceedingSpanClampsToZero() throws {
    let input = QadaEstimateInput(
        birthDate: try date(2000, 1, 1),
        accountabilityAgeYears: 14,
        consistentPrayerBegan: try date(2014, 1, 31),
        averageExcusedDaysPerMonth: 45,
        includeWitr: false
    )

    let estimate = QadaEstimator.estimate(input, calendar: utcGregorian)

    #expect(estimate.spanDays == 30)
    #expect(estimate.excusedDaysDeducted == 30)
    #expect(estimate.obligatedDays == 0)
    #expect(estimate.perCategory[.isha] == 0)
}

/// The displayed arithmetic is these exact fields, so their internal
/// consistency is what guarantees the UI's math matches the result.
@Test
func intermediateValuesAreArithmeticallyConsistent() throws {
    let input = QadaEstimateInput(
        birthDate: try date(1994, 7, 23),
        accountabilityAgeYears: 15,
        consistentPrayerBegan: try date(2021, 3, 9),
        averageExcusedDaysPerMonth: 7,
        includeWitr: true
    )

    let estimate = QadaEstimator.estimate(input, calendar: utcGregorian)

    #expect(estimate.wholeMonths == estimate.spanDays / 30)
    #expect(estimate.excusedDaysDeducted == min(estimate.wholeMonths * 7, estimate.spanDays))
    #expect(estimate.obligatedDays == estimate.spanDays - estimate.excusedDaysDeducted)
    for category in QadaCategory.fardCategories {
        #expect(estimate.perCategory[category] == estimate.obligatedDays)
    }
    #expect(estimate.perCategory[.witr] == estimate.obligatedDays)
}
