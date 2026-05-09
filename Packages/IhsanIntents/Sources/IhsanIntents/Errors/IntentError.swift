import AppIntents

public enum IntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case modelContextUnavailable
    case prayerLogServiceUnavailable
    case invalidPrayer(String)
    case invalidStatus(String)
    case prayerTimesCalculationFailed(underlying: String)
    case noActiveSettings

    public var localizedStringResource: LocalizedStringResource {
        switch self {
        case .modelContextUnavailable:
            return "Could not access local storage."
        case .prayerLogServiceUnavailable:
            return "The prayer log service is not available."
        case .invalidPrayer(let raw):
            return "Unknown prayer: \(raw)."
        case .invalidStatus(let raw):
            return "Unknown status: \(raw)."
        case .prayerTimesCalculationFailed(let underlying):
            return "Could not compute prayer times: \(underlying)."
        case .noActiveSettings:
            return "User settings are not configured."
        }
    }
}
