import IhsanCore
import Testing
@testable import IhsanPrayerTimes

@Test
func calculationMethodMappingsReturnValidParametersExceptOther() throws {
    for method in CalculationMethodChoice.allCases where method != .other {
        let parameters = try method.toAdhanCalculationParameters()
        #expect(parameters.fajrAngle >= 0)
    }

    #expect(throws: PrayerTimesError.self) {
        try CalculationMethodChoice.other.toAdhanCalculationParameters()
    }
}

@Test
func madhabMappingsDoNotThrow() {
    for madhab in MadhabChoice.allCases {
        _ = madhab.toAdhanMadhab()
    }
}

@Test
func highLatitudeRuleMappingsDoNotThrow() {
    for rule in HighLatitudeRule.allCases {
        _ = rule.toAdhanHighLatitudeRule()
    }
}

@Test
func adhanPrayerMapsOnlyFardhPrayers() {
    #expect(Prayer.from(adhan: .fajr) == .fajr)
    #expect(Prayer.from(adhan: .sunrise) == nil)
}
