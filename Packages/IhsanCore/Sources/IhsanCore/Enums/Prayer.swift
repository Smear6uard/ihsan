import Foundation

public enum Prayer: String, Codable, CaseIterable, Sendable {
    case fajr
    case dhuhr
    case asr
    case maghrib
    case isha

    public var displayNameEnglish: String {
        switch self {
        case .fajr:
            "Fajr"
        case .dhuhr:
            "Dhuhr"
        case .asr:
            "Asr"
        case .maghrib:
            "Maghrib"
        case .isha:
            "Isha"
        }
    }

    public var displayNameArabic: String {
        switch self {
        case .fajr:
            "الفجر"
        case .dhuhr:
            "الظهر"
        case .asr:
            "العصر"
        case .maghrib:
            "المغرب"
        case .isha:
            "العشاء"
        }
    }

    /// The short small-caps form for a legend gutter, where five names
    /// have to stack in one narrow column without setting the column's
    /// width by the longest of them. Only Maghrib is actually clipped;
    /// the rest are their whole names.
    public var inscriptionAbbreviation: String {
        switch self {
        case .fajr:
            "FAJR"
        case .dhuhr:
            "DHUHR"
        case .asr:
            "ASR"
        case .maghrib:
            "MAGH"
        case .isha:
            "ISHA"
        }
    }

    public var defaultRakatCount: Int {
        switch self {
        case .fajr:
            2
        case .dhuhr, .asr, .isha:
            4
        case .maghrib:
            3
        }
    }
}
