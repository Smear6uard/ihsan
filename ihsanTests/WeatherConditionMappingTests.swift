import Foundation
import Testing
import WeatherKit
import IhsanCore
@testable import ihsan

@Suite("WeatherKit condition mapping")
struct WeatherConditionMappingTests {
    @Test("Every WeatherKit condition maps to the kind of the same name")
    func mappingIsFaithful() {
        for condition in WeatherCondition.allCases {
            let mapped = SkyConditions.Kind(condition)
            #expect(
                mapped.rawValue == condition.rawValue,
                "WeatherKit \(condition.rawValue) mapped to \(mapped)"
            )
        }
    }

    @Test("No WeatherKit condition falls into unknown")
    func nothingFallsThrough() {
        // If the SDK grows a new condition this fails, prompting a
        // deliberate mapping decision. Until then the runtime already
        // handles it: unknown renders as the idealized sky.
        for condition in WeatherCondition.allCases {
            #expect(SkyConditions.Kind(condition) != .unknown, "\(condition)")
        }
    }

    @Test("A reading derives its bands from the raw measurements")
    func readingDerivesBands() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let reading = WeatherKitSkyProvider.conditions(
            condition: .partlyCloudy,
            windKilometersPerHour: 24,
            cloudCover: 0.4,
            precipitationIntensityMMPerHour: 0,
            asOf: now
        )
        #expect(reading.kind == .partlyCloudy)
        #expect(reading.windBand == .breezy)
        #expect(reading.cloudBand == .scattered)
        #expect(!reading.isPrecipitating)
        #expect(reading.fetchedAt == now)
    }

    @Test("Precipitation follows the kind even when intensity reads zero")
    func precipitationFollowsKind() {
        let reading = WeatherKitSkyProvider.conditions(
            condition: .rain,
            windKilometersPerHour: 0,
            cloudCover: 1,
            precipitationIntensityMMPerHour: 0,
            asOf: .now
        )
        #expect(reading.isPrecipitating)
    }

    @Test("Measured intensity marks precipitation even under a dry kind")
    func precipitationFollowsIntensity() {
        let reading = WeatherKitSkyProvider.conditions(
            condition: .cloudy,
            windKilometersPerHour: 0,
            cloudCover: 1,
            precipitationIntensityMMPerHour: 0.5,
            asOf: .now
        )
        #expect(reading.isPrecipitating)
    }
}
