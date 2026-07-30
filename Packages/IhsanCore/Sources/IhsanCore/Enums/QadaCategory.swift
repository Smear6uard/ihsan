import Foundation

/// A ledger category for makeup worship. String-backed so future categories
/// (e.g. fasting) can be added without breaking stored data.
public enum QadaCategory: String, Codable, CaseIterable, Sendable {
    case fajr
    case dhuhr
    case asr
    case maghrib
    case isha
    case witr
    case fasting

    /// The five daily prayers, in day order. Witr and fasting are
    /// separate optional categories and are never included here.
    public static var fardCategories: [QadaCategory] {
        [.fajr, .dhuhr, .asr, .maghrib, .isha]
    }

    /// Whether the setup estimator may derive a starting count for
    /// this category. Fasting is manual-entry only — days owed are
    /// counted by the user, never estimated by the app.
    public var supportsAutoEstimation: Bool {
        self != .fasting
    }

    public init(prayer: Prayer) {
        switch prayer {
        case .fajr: self = .fajr
        case .dhuhr: self = .dhuhr
        case .asr: self = .asr
        case .maghrib: self = .maghrib
        case .isha: self = .isha
        }
    }

    /// The fard prayer this category corresponds to, if any.
    public var prayer: Prayer? {
        Prayer(rawValue: rawValue)
    }

    public var displayNameEnglish: String {
        switch self {
        case .witr:
            "Witr"
        case .fasting:
            "Fasts"
        case .fajr, .dhuhr, .asr, .maghrib, .isha:
            prayer?.displayNameEnglish ?? rawValue.capitalized
        }
    }

    public var displayNameArabic: String {
        switch self {
        case .witr:
            "الوتر"
        case .fasting:
            "الصيام"
        case .fajr, .dhuhr, .asr, .maghrib, .isha:
            prayer?.displayNameArabic ?? rawValue
        }
    }
}
