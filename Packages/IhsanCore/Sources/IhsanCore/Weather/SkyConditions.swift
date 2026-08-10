import Foundation

/// A coarse, derived reading of the sky: what the weather is like, not
/// where it was measured.
///
/// This is the whole of what the app retains from a weather fetch. The
/// vocabulary is deliberately small — a condition kind, whether water is
/// falling, and two banded intensities — because everything downstream
/// (the plate's painted treatments, the weather dua offers) needs no
/// more than that. Coordinates are used transiently to ask the provider
/// and are never part of this value; the privacy contract on
/// `LocatedPlace` extends here unchanged.
public struct SkyConditions: Codable, Sendable, Equatable {
    /// Mirrors the provider's condition vocabulary one to one, plus
    /// `unknown` for anything a future provider reports that this build
    /// has never heard of. Unknown always renders as the idealized sky.
    public enum Kind: String, Codable, Sendable, CaseIterable {
        case clear, mostlyClear, partlyCloudy, mostlyCloudy, cloudy
        case foggy, haze, smoky, blowingDust
        case drizzle, rain, heavyRain, sunShowers
        case freezingDrizzle, freezingRain, sleet, wintryMix, hail
        case snow, heavySnow, flurries, blowingSnow, sunFlurries, blizzard
        case isolatedThunderstorms, scatteredThunderstorms, thunderstorms, strongStorms
        case hurricane, tropicalStorm
        case windy, breezy
        case frigid, hot
        case unknown

        public init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Kind(rawValue: raw) ?? .unknown
        }

        /// Kinds that are precipitation by definition, so a reading can
        /// be marked precipitating even when the measured intensity
        /// happens to read zero at the sample instant.
        public var impliesPrecipitation: Bool {
            switch self {
            case .drizzle, .rain, .heavyRain, .sunShowers,
                 .freezingDrizzle, .freezingRain, .sleet, .wintryMix, .hail,
                 .snow, .heavySnow, .flurries, .blowingSnow, .sunFlurries, .blizzard,
                 .isolatedThunderstorms, .scatteredThunderstorms, .thunderstorms,
                 .strongStorms, .hurricane, .tropicalStorm:
                return true
            case .clear, .mostlyClear, .partlyCloudy, .mostlyCloudy, .cloudy,
                 .foggy, .haze, .smoky, .blowingDust, .windy, .breezy,
                 .frigid, .hot, .unknown:
                return false
            }
        }
    }

    /// Wind, banded. `strong` is the dua trigger — the transmitted wind
    /// supplication is for wind that blows hard, not for a breeze.
    public enum WindBand: String, Codable, Sendable, Equatable {
        case calm, breezy, strong

        public static let breezyThresholdKPH: Double = 20
        public static let strongThresholdKPH: Double = 38

        public init(kilometersPerHour: Double) {
            if kilometersPerHour >= Self.strongThresholdKPH {
                self = .strong
            } else if kilometersPerHour >= Self.breezyThresholdKPH {
                self = .breezy
            } else {
                self = .calm
            }
        }
    }

    /// Cloud cover, banded on fixed fractions of the sky.
    public enum CloudBand: String, Codable, Sendable, Equatable {
        case clear, scattered, broken, overcast

        public init(cloudCover: Double) {
            switch cloudCover {
            case ..<0.2: self = .clear
            case ..<0.5: self = .scattered
            case ..<0.85: self = .broken
            default: self = .overcast
            }
        }
    }

    public let kind: Kind
    public let isPrecipitating: Bool
    public let windBand: WindBand
    public let cloudBand: CloudBand
    public let fetchedAt: Date

    public init(
        kind: Kind,
        isPrecipitating: Bool,
        windBand: WindBand,
        cloudBand: CloudBand,
        fetchedAt: Date
    ) {
        self.kind = kind
        self.isPrecipitating = isPrecipitating
        self.windBand = windBand
        self.cloudBand = cloudBand
        self.fetchedAt = fetchedAt
    }
}

public extension SkyConditions {
    /// How long a reading is trusted before a refresh is worth asking
    /// for. Between the two intervals the old reading keeps serving.
    static let refreshInterval: TimeInterval = 60 * 60
    /// How long a reading is served at all. Past this the sky reverts
    /// to the idealized rendering rather than painting stale weather.
    static let expiryInterval: TimeInterval = 3 * 60 * 60

    func isStale(at now: Date) -> Bool {
        now.timeIntervalSince(fetchedAt) >= Self.refreshInterval
    }

    func isExpired(at now: Date) -> Bool {
        now.timeIntervalSince(fetchedAt) >= Self.expiryInterval
    }

    /// The reading if it is still fit to serve, else nil.
    func usable(at now: Date) -> SkyConditions? {
        isExpired(at: now) ? nil : self
    }
}

/// When to actually go to the network. Kept pure so the policy is
/// pinned by tests rather than implied by call sites.
public enum SkyWeatherRefreshPolicy {
    public static func shouldFetch(
        cached: SkyConditions?,
        now: Date,
        force: Bool = false
    ) -> Bool {
        if force { return true }
        guard let cached else { return true }
        return cached.isStale(at: now)
    }
}

/// App-Group cache for the last sky reading, in the exact mold of
/// `PrayerTimesCacheStore`. Persists derived weather only — a condition
/// kind and three bands. No coordinates, no place names, nothing that
/// locates the reading.
public enum SkyConditionsCacheStore {
    public static let suiteName = "group.com.sameerstudios.ihsan"
    public static let key = "ihsan.sky-conditions-cache.v1"

    public static func write(_ conditions: SkyConditions) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        guard let data = try? JSONEncoder().encode(conditions) else { return }
        defaults.set(data, forKey: key)
    }

    public static func read() -> SkyConditions? {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return nil }
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SkyConditions.self, from: data)
    }

    public static func clear() {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        defaults.removeObject(forKey: key)
    }
}
