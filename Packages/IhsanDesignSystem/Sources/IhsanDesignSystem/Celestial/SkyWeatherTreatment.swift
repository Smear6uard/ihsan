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

    /// The maintainer's per-condition gate ledger. Every treatment
    /// ships only after being seen on device in a day and a night
    /// state; a condition the review rejects is CUT from this set and
    /// falls back along its chain — it does not ship half-approved.
    /// (`clear` needs no approval; it is the idealized page.)
    public static let gateApproved: Set<SkyWeatherTreatment> = Set(allCases)
}

// MARK: - The painted dials

/// Everything a treatment is allowed to do to the page, as numbers.
/// Value shifts, engraved marks, and washes — nothing photographic,
/// nothing animated beyond an imperceptible drift, nothing that
/// flashes. The dials are pinned by `LivingSkyTreatmentTests`.
public extension SkyWeatherTreatment {
    /// Value compression of the sky ramp toward its (slightly lowered)
    /// middle — the page on a gray day. Identity everywhere except the
    /// two gray pages. First calibration (0.80/0.70) measured ±2
    /// points of channel change on device frames — applied but
    /// unreadable; a gray day must be seen at a glance.
    ///
    /// Rain and snow gray the page too. Hatching drawn over a clear,
    /// sunlit blue read as a sun shower, and white flecks drawn over
    /// an ungrayed day field vanished into it: falling weather needs
    /// the veiled sky it falls from. Both stay lighter than overcast —
    /// rain is a softer gray, snow the bright white-gray of a snow sky.
    var valueCompression: Double {
        switch self {
        case .clear, .partlyVeiled: 1.0
        case .rain: 0.76
        case .snow: 0.66
        case .overcast: 0.62
        case .storm: 0.52
        }
    }

    /// The gray pages pivot a touch below the ramp's middle: an
    /// overcast day is not only flatter, it is a shade darker.
    var grayPivotShift: Double {
        switch self {
        case .clear, .partlyVeiled: 0
        case .rain, .snow: -0.01
        case .overcast: -0.015
        case .storm: -0.03
        }
    }

    /// Chroma calms on the gray pages. Desaturation is not a new hue —
    /// it is the same page with the color sky drawn through a veil.
    var chromaCalm: Double {
        switch self {
        case .clear, .partlyVeiled: 1.0
        case .rain: 0.68
        case .snow: 0.45
        case .overcast: 0.55
        case .storm: 0.45
        }
    }

    /// How much the engraved metal quiets on the gray pages. The
    /// terrain chord and the gilded traversed passage are exempt —
    /// the horizon and the day's record stay at full presence.
    var metalQuiet: Double {
        switch self {
        case .clear, .partlyVeiled: 1.0
        case .rain, .snow: 0.92
        case .overcast: 0.85
        case .storm: 0.78
        }
    }

    /// Extra deepening of the ground band under falling rain.
    var groundDeepening: Double {
        switch self {
        case .clear, .partlyVeiled, .overcast, .snow: 1.0
        case .rain: 0.96
        case .storm: 0.92
        }
    }

    /// Damping of the sun's painted horizon bloom and dawn wash when
    /// the sky is veiled gray. Partly veiled keeps the bloom whole —
    /// it warms the wash it sits behind.
    var bloomDamping: Double {
        switch self {
        case .clear, .partlyVeiled: 1.0
        case .rain: 0.55
        case .snow: 0.45
        case .overcast: 0.45
        case .storm: 0.30
        }
    }

    /// How present the sun's and moon's discs are through the weather.
    /// A veiled body is a pale disc, not a missing one: the sun is the
    /// plate's hand on the day's clock, so it dims and never leaves.
    /// The first gray pages left it blazing, which read as a sunny day
    /// with a gray filter on it.
    var bodyVeil: Double {
        switch self {
        case .clear, .partlyVeiled: 1.0
        case .rain: 0.5
        case .snow: 0.55
        case .overcast: 0.55
        case .storm: 0.35
        }
    }

    /// How much of the star field shows through the weather. Cloud
    /// that grays the day page hides the night's stars; under snow the
    /// flecks take the stars' place entirely, so the two never read as
    /// one field.
    var starVisibility: Double {
        switch self {
        case .clear: 1.0
        case .partlyVeiled: 0.75
        case .overcast: 0.2
        case .rain: 0.15
        case .snow, .storm: 0
        }
    }

    var showsRainHatching: Bool { self == .rain || self == .storm }
    var showsSnowFlecks: Bool { self == .snow }
    var showsCloudWashes: Bool { self == .partlyVeiled }
}
