import Foundation
import IhsanCore

/// Maps an ISO-3166 alpha-2 country code to a sensible default
/// calculation method. Used to prefill the method step after the
/// location grant — the user can always override.
///
/// The mappings reflect the dominant convention in each region rather
/// than any normative preference. Anything unmapped falls through to
/// Muslim World League, which is the most globally portable default.
enum CalculationMethodSuggester {
    static func method(forCountryCode code: String?) -> CalculationMethodChoice {
        guard let code = code?.uppercased(), !code.isEmpty else {
            return .muslimWorldLeague
        }

        switch code {
        case "US", "CA":
            return .isna
        case "AE":
            return .dubai
        case "QA":
            return .qatar
        case "KW":
            return .kuwait
        case "SG", "MY", "BN":
            return .singapore
        case "IR":
            return .tehran
        case "TR":
            return .turkey
        case "PK", "BD", "IN", "AF":
            return .karachi
        case "EG", "SD", "LY", "DZ", "TN", "MA":
            return .egyptian
        case "SA", "YE":
            return .ummAlQura
        default:
            return .muslimWorldLeague
        }
    }

    /// Region used when the user skipped the location grant. Prefers
    /// the device locale; iOS exposes this without any permission.
    static func suggestedFromLocale(_ locale: Locale = .current) -> CalculationMethodChoice {
        method(forCountryCode: locale.region?.identifier)
    }
}

extension CalculationMethodChoice {
    /// Human-readable name shown in the picker and the method card.
    var displayName: String {
        switch self {
        case .muslimWorldLeague: return "Muslim World League"
        case .isna: return "ISNA"
        case .egyptian: return "Egyptian General Authority"
        case .ummAlQura: return "Umm al-Qura, Makkah"
        case .karachi: return "University of Islamic Sciences, Karachi"
        case .dubai: return "Dubai"
        case .qatar: return "Qatar"
        case .kuwait: return "Kuwait"
        case .singapore: return "Singapore (MUIS)"
        case .tehran: return "Institute of Geophysics, Tehran"
        case .jafari: return "Shia Ithna Ashari (Jafari)"
        case .moonsightingCommittee: return "Moonsighting Committee"
        case .northAmerica: return "North America"
        case .turkey: return "Diyanet, Turkey"
        case .other: return "Custom"
        }
    }

    /// Short subtitle shown beneath the method name in the picker.
    var regionHint: String {
        switch self {
        case .muslimWorldLeague: return "Global default · 18° / 17°"
        case .isna: return "United States, Canada · 15° / 15°"
        case .egyptian: return "Egypt, North Africa · 19.5° / 17.5°"
        case .ummAlQura: return "Saudi Arabia · 18.5° / 90 min after Maghrib"
        case .karachi: return "South Asia · 18° / 18°"
        case .dubai: return "United Arab Emirates · 18.2° / 18.2°"
        case .qatar: return "Qatar · 18° / 90 min"
        case .kuwait: return "Kuwait · 18° / 17.5°"
        case .singapore: return "Singapore, Malaysia · 20° / 18°"
        case .tehran: return "Iran · 17.7° / 14°"
        case .jafari: return "Shia · 16° / 14°"
        case .moonsightingCommittee: return "Shawwal Moonsighting · seasonal"
        case .northAmerica: return "North America (alt.) · 15° / 15°"
        case .turkey: return "Türkiye · 18° / 17°"
        case .other: return "Manual angles"
        }
    }
}
