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

    /// The five daily prayers, in day order. Witr is a separate optional
    /// category and is never included here.
    public static var fardCategories: [QadaCategory] {
        [.fajr, .dhuhr, .asr, .maghrib, .isha]
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
        case .fajr, .dhuhr, .asr, .maghrib, .isha:
            prayer?.displayNameEnglish ?? rawValue.capitalized
        }
    }

    public var displayNameArabic: String {
        switch self {
        case .witr:
            "الوتر"
        case .fajr, .dhuhr, .asr, .maghrib, .isha:
            prayer?.displayNameArabic ?? rawValue
        }
    }
}
