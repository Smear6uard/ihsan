import Foundation
import IhsanCore

/// Which weather dua, if any, this moment is offering.
///
/// Pure logic in the `AdhkarOffer` mold: the gates, the priority, and
/// the per-episode dismissal all live here and are tested here. The
/// line this produces is a quiet register inscription on the Today
/// header — never a notification — and it opens a transmitted text in
/// the remembrance reader.
///
/// There is deliberately no pause input. An excused pause suspends
/// salah and fasting, never remembrance (`AdhkarOffer.pauseSuppresses`
/// writes that rule down); this context has nothing to suppress with.
enum WeatherDuaOffer {

    /// Priority order: thunder is the most momentary, then the rain
    /// that is falling, then the rain that has just passed, then wind.
    /// One line at a time; dismissing one reveals the next, each with
    /// its own episode.
    enum Kind: String, CaseIterable {
        case thunder, rain, afterRain, wind

        /// The situational item the line opens.
        var itemID: String {
            switch self {
            case .thunder: "situational.thunder"
            case .rain: "situational.rain"
            case .afterRain: "situational.after-rain"
            case .wind: "situational.wind"
            }
        }

        /// The register line, in the significant-day inscription style.
        var inscription: String {
            switch self {
            case .thunder: "THUNDER · ITS DHIKR"
            case .rain: "IT IS RAINING · THE DUA OF RAIN"
            case .afterRain: "THE RAIN HAS PASSED · ITS REMEMBRANCE"
            case .wind: "THE WIND IS STRONG · ITS DUA"
            }
        }

        var spokenLabel: String {
            switch self {
            case .thunder: "Thunder. Its dhikr."
            case .rain: "It is raining. The dua of rain."
            case .afterRain: "The rain has passed. Its remembrance."
            case .wind: "The wind is strong. Its dua."
            }
        }
    }

    struct Offer: Equatable {
        var kind: Kind
        /// Identity of the weather that prompted the line. Dismissals
        /// key on this, so the same rain never asks twice and the next
        /// rain may ask again.
        var episodeKey: String
    }

    struct Context {
        /// The current reading, already staleness-filtered by the
        /// caller (`SkyWeatherModel.current(at:)`). Nil means the sky
        /// is unknown, and an unknown sky offers nothing.
        var conditions: SkyConditions?
        var ledger: WeatherEpisodeLedger
        var now: Date
        var dismissedEpisodes: Set<String>
        /// False while the content file is unreviewed in a release
        /// build — see `AdhkarAvailability`.
        var isContentAvailable: Bool
        /// The adhkar layer's master switch. A person who turned
        /// remembrance off is not offered remembrance.
        var layerEnabled: Bool
    }

    /// How long the after-rain remembrance stays available once the
    /// rain has stopped.
    static let afterRainWindow: TimeInterval = 60 * 60

    static func offer(_ context: Context) -> Offer? {
        guard context.isContentAvailable, context.layerEnabled else { return nil }
        guard let conditions = context.conditions else { return nil }

        var candidates: [Offer] = []
        if let start = context.ledger.thunderStartedAt, conditions.isThundery {
            candidates.append(Offer(kind: .thunder, episodeKey: key("thunder", start)))
        }
        if let start = context.ledger.rainStartedAt, conditions.isRaining {
            candidates.append(Offer(kind: .rain, episodeKey: key("rain", start)))
        }
        if let ended = context.ledger.rainEndedAt,
           context.now.timeIntervalSince(ended) < Self.afterRainWindow,
           !conditions.isRaining {
            candidates.append(Offer(kind: .afterRain, episodeKey: key("after-rain", ended)))
        }
        if let start = context.ledger.windStartedAt, conditions.windBand == .strong {
            candidates.append(Offer(kind: .wind, episodeKey: key("wind", start)))
        }
        return candidates.first { !context.dismissedEpisodes.contains($0.episodeKey) }
    }

    /// Every episode key the ledger can currently justify. The
    /// dismissal store prunes to this set, so it cleans itself as
    /// weather passes.
    static func liveEpisodeKeys(ledger: WeatherEpisodeLedger) -> Set<String> {
        var keys = Set<String>()
        if let start = ledger.thunderStartedAt { keys.insert(key("thunder", start)) }
        if let start = ledger.rainStartedAt { keys.insert(key("rain", start)) }
        if let ended = ledger.rainEndedAt { keys.insert(key("after-rain", ended)) }
        if let start = ledger.windStartedAt { keys.insert(key("wind", start)) }
        return keys
    }

    private static func key(_ name: String, _ start: Date) -> String {
        "\(name):\(Int(start.timeIntervalSince1970))"
    }
}

/// Dismissed episode keys, stored as presentation state — never worship
/// data. Encoding keeps only keys that still name a live episode, so
/// the store cleans itself as weather passes.
enum WeatherDuaDismissal {
    static func decode(_ stored: String) -> Set<String> {
        Set(stored.split(separator: ",").map(String.init)).filter { !$0.isEmpty }
    }

    static func encode(_ keys: Set<String>, keeping live: Set<String>) -> String {
        keys.intersection(live).sorted().joined(separator: ",")
    }
}
