import Foundation
import IhsanCore

/// The plate's weather vocabulary: six painted treatments, no more.
///
/// Weather on the plate is an illuminator's device — washes, veils,
/// hatching, value shifts — never a weather app's renderer. The
/// vocabulary is deliberately smaller than the provider's: storm is
/// overcast plus rain one step deeper, wind is a dua trigger and not a
/// visual, and anything unrecognized is the idealized page. Every
/// treatment renders behind the instrument layer, and the idealized
/// sky (`clear`) is the permanent fallback for all of them.
public enum SkyWeatherTreatment: String, CaseIterable, Codable, Sendable {
    case clear
    case partlyVeiled
    case overcast
    case rain
    case snow
    case storm

    /// The mapping table from a sky reading to its treatment.
    /// Kind-driven on purpose: the bands refine dua offers, not the
    /// painting, so the same condition always paints the same page.
    public static func resolved(for conditions: SkyConditions) -> SkyWeatherTreatment {
        switch conditions.kind {
        case .clear, .breezy, .windy, .blowingDust, .frigid, .hot, .unknown:
            return .clear
        case .mostlyClear, .partlyCloudy:
            return .partlyVeiled
        case .mostlyCloudy, .cloudy, .foggy, .haze, .smoky:
            return .overcast
        case .drizzle, .rain, .heavyRain, .sunShowers,
             .freezingDrizzle, .freezingRain, .sleet, .wintryMix, .hail:
            return .rain
        case .flurries, .snow, .heavySnow, .blowingSnow, .sunFlurries, .blizzard:
            return .snow
        case .isolatedThunderstorms, .scatteredThunderstorms, .thunderstorms,
             .strongStorms, .hurricane, .tropicalStorm:
            return .storm
        }
    }

    /// Each treatment ships only after its own maintainer gate. A
    /// treatment that is not in the approved set falls back along this
    /// chain to the nearest approved one, ending at the idealized page,
    /// which needs no approval.
    private var fallback: SkyWeatherTreatment? {
        switch self {
        case .clear: return nil
        case .partlyVeiled: return .clear
        case .overcast: return .partlyVeiled
        case .rain: return .overcast
        case .snow: return .clear
        case .storm: return .rain
        }
    }

    public func resolvedAgainst(approved: Set<SkyWeatherTreatment>) -> SkyWeatherTreatment {
        var current = self
        while current != .clear, !approved.contains(current) {
            guard let next = current.fallback else { return .clear }
            current = next
        }
        return current
    }
}
