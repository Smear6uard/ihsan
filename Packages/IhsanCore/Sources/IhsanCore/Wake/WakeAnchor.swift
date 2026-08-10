import Foundation

/// The four moments a person asks to be woken for.
///
/// Each is a real instant in that day's own solar arithmetic, never a
/// clock time: the wake follows the sky, so it moves with the season and
/// with the place.
public enum WakeAnchor: String, CaseIterable, Codable, Sendable {
    /// The last third of the night begins.
    case lastThird
    /// Fajr begins — suhoor's end.
    case fajrStart
    /// Sunrise — Fajr's window closing.
    case sunrise
    /// Maghrib — iftar.
    case maghrib
}

/// One anchor's settings. Strictly opt-in, and off until asked for.
public struct WakeAnchorConfig: Codable, Sendable, Equatable {
    public var anchor: WakeAnchor
    public var isEnabled: Bool
    /// Minutes **before** the anchor's instant. Zero fires at the instant
    /// itself.
    public var offsetMinutes: Int

    public init(anchor: WakeAnchor, isEnabled: Bool = false, offsetMinutes: Int = 0) {
        self.anchor = anchor
        self.isEnabled = isEnabled
        self.offsetMinutes = offsetMinutes
    }

    /// Decoded leniently so a payload from an earlier build still reads
    /// rather than silently retiring a wake someone relies on.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        anchor = try container.decode(WakeAnchor.self, forKey: .anchor)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        offsetMinutes = try container.decodeIfPresent(Int.self, forKey: .offsetMinutes) ?? 0
    }

    /// Every anchor, off. The default for a fresh install: nothing rings
    /// until someone asks it to.
    public static var allOff: [WakeAnchorConfig] {
        WakeAnchor.allCases.map { WakeAnchorConfig(anchor: $0) }
    }

    /// Sorted keys so the stored default is byte-stable across processes.
    /// Tests compare decoded values, never this string.
    public static func encode(_ configs: [WakeAnchorConfig]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(configs),
              let json = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return json
    }

    public static func decode(_ json: String) -> [WakeAnchorConfig] {
        guard let data = json.data(using: .utf8),
              let configs = try? JSONDecoder().decode([WakeAnchorConfig].self, from: data)
        else {
            return []
        }
        return configs
    }
}
