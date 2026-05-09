import Foundation

/// Symbolic references to canonical times of day. Used by previews to render
/// the same component at every prayer time so the iridescent glass treatment
/// can be visually verified without clock-mocking.
public enum TimeOfDay: CaseIterable, Sendable {
    case fajr
    case sunrise
    case dhuhr
    case asr
    case maghrib
    case isha
    case night

    /// Representative wall-clock time for previews. Anchored to a fixed
    /// calendar date so previews remain deterministic across rebuilds.
    public var representativeDate: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 15
        switch self {
        case .fajr:
            components.hour = 5
            components.minute = 0
        case .sunrise:
            components.hour = 6
            components.minute = 30
        case .dhuhr:
            components.hour = 12
            components.minute = 30
        case .asr:
            components.hour = 15
            components.minute = 30
        case .maghrib:
            components.hour = 19
            components.minute = 0
        case .isha:
            components.hour = 21
            components.minute = 30
        case .night:
            components.hour = 23
            components.minute = 30
        }
        return Calendar.current.date(from: components) ?? .now
    }

    public var displayName: String {
        switch self {
        case .fajr: return "Fajr"
        case .sunrise: return "Sunrise"
        case .dhuhr: return "Dhuhr"
        case .asr: return "Asr"
        case .maghrib: return "Maghrib"
        case .isha: return "Isha"
        case .night: return "Night"
        }
    }
}
