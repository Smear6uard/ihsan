import Foundation
import WeatherKit
import IhsanCore
import IhsanPrayerTimes
// CLLocation is the currency WeatherKit trades in, and WeatherKit does
// not re-export it. This scoped import brings in the one class needed
// to phrase the request — no manager, no delegate, no geocoding.
// Location acquisition stays where it belongs, in
// CoreLocationCoordinator; the coordinates arriving here are already
// transient by the `LocatedPlace` contract and leave with this call.
import class CoreLocation.CLLocation

/// Asks Apple Weather for the current conditions and reduces the answer
/// to the app's coarse `SkyConditions` vocabulary.
///
/// Privacy: the user's coordinates are passed in, used to scope one
/// WeatherKit request, and discarded with this actor's stack. Nothing
/// is retained, persisted, or logged. The reading that leaves this
/// actor carries no location.
actor WeatherKitSkyProvider: SkyWeatherProviding {
    func currentConditions(at coordinates: Coordinates, asOf now: Date) async throws -> SkyConditions {
        let location = CLLocation(
            latitude: coordinates.latitude,
            longitude: coordinates.longitude
        )
        let current = try await WeatherService.shared.weather(
            for: location,
            including: .current
        )
        return Self.conditions(
            condition: current.condition,
            windKilometersPerHour: current.wind.speed
                .converted(to: .kilometersPerHour).value,
            cloudCover: current.cloudCover,
            precipitationIntensityMMPerHour: current.precipitationIntensity
                .converted(to: .metersPerSecond).value * 3_600_000,
            asOf: now
        )
    }

    /// Pure reduction kept separate from WeatherKit I/O so the mapping
    /// contract is pinned by tests.
    nonisolated static func conditions(
        condition: WeatherCondition,
        windKilometersPerHour: Double,
        cloudCover: Double,
        precipitationIntensityMMPerHour: Double,
        asOf now: Date
    ) -> SkyConditions {
        let kind = SkyConditions.Kind(condition)
        return SkyConditions(
            kind: kind,
            isPrecipitating: kind.impliesPrecipitation
                || precipitationIntensityMMPerHour >= 0.1,
            windBand: SkyConditions.WindBand(kilometersPerHour: windKilometersPerHour),
            cloudBand: SkyConditions.CloudBand(cloudCover: cloudCover),
            fetchedAt: now
        )
    }
}

extension SkyConditions.Kind {
    /// The provider's vocabulary, case for case. A condition this build
    /// has never heard of becomes `unknown`, which renders as the
    /// idealized sky.
    init(_ condition: WeatherCondition) {
        switch condition {
        case .clear: self = .clear
        case .mostlyClear: self = .mostlyClear
        case .partlyCloudy: self = .partlyCloudy
        case .mostlyCloudy: self = .mostlyCloudy
        case .cloudy: self = .cloudy
        case .foggy: self = .foggy
        case .haze: self = .haze
        case .smoky: self = .smoky
        case .blowingDust: self = .blowingDust
        case .drizzle: self = .drizzle
        case .rain: self = .rain
        case .heavyRain: self = .heavyRain
        case .sunShowers: self = .sunShowers
        case .freezingDrizzle: self = .freezingDrizzle
        case .freezingRain: self = .freezingRain
        case .sleet: self = .sleet
        case .wintryMix: self = .wintryMix
        case .hail: self = .hail
        case .snow: self = .snow
        case .heavySnow: self = .heavySnow
        case .flurries: self = .flurries
        case .blowingSnow: self = .blowingSnow
        case .sunFlurries: self = .sunFlurries
        case .blizzard: self = .blizzard
        case .isolatedThunderstorms: self = .isolatedThunderstorms
        case .scatteredThunderstorms: self = .scatteredThunderstorms
        case .thunderstorms: self = .thunderstorms
        case .strongStorms: self = .strongStorms
        case .hurricane: self = .hurricane
        case .tropicalStorm: self = .tropicalStorm
        case .windy: self = .windy
        case .breezy: self = .breezy
        case .frigid: self = .frigid
        case .hot: self = .hot
        @unknown default: self = .unknown
        }
    }
}
