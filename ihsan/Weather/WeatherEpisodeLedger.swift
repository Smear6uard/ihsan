import Foundation
import IhsanCore

/// When the current weather began, kind by kind — the app's whole
/// memory of "an episode".
///
/// A dua line is dismissible for the episode and returns only on a new
/// one, so the ledger records when rain, hard wind, and thunder began
/// (and when rain ended, for the after-rain remembrance). Episode
/// starts double as episode identity: dismissals key on them. Derived
/// weather only; nothing about where.
struct WeatherEpisodeLedger: Codable, Equatable, Sendable {
    var rainStartedAt: Date?
    var rainEndedAt: Date?
    var windStartedAt: Date?
    var thunderStartedAt: Date?

    init() {}

    /// Folds one fresh reading in. Idempotent for an unchanged sky:
    /// an episode already open keeps its original start.
    func advanced(with conditions: SkyConditions, now: Date) -> WeatherEpisodeLedger {
        var next = self
        if conditions.isRaining {
            next.rainStartedAt = rainStartedAt ?? now
            next.rainEndedAt = nil
        } else {
            if rainStartedAt != nil {
                next.rainEndedAt = now
            }
            next.rainStartedAt = nil
        }
        next.windStartedAt = conditions.windBand == .strong ? (windStartedAt ?? now) : nil
        next.thunderStartedAt = conditions.isThundery ? (thunderStartedAt ?? now) : nil
        return next
    }
}

/// App-Group persistence beside the conditions cache, so an episode
/// survives a relaunch mid-rain rather than greeting the same rain as
/// new.
enum WeatherEpisodeLedgerStore {
    static let suiteName = IhsanModelContainerFactory.appGroupIdentifier
    static let key = "ihsan.weather-episodes.v1"

    static func write(_ ledger: WeatherEpisodeLedger) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        guard let data = try? JSONEncoder().encode(ledger) else { return }
        defaults.set(data, forKey: key)
    }

    static func read() -> WeatherEpisodeLedger? {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return nil }
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WeatherEpisodeLedger.self, from: data)
    }

    static func clear() {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        defaults.removeObject(forKey: key)
    }
}
