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
