import Foundation
import IhsanCore

// The one place calculation methods are described in words and numbers.
//
// Every angle here is read off the parameters the solar math will
// actually be handed — never typed by hand — so a settings row can be
// checked against a masjid's printed timetable and trusted. A person
// who cannot verify a number has to take the app's word for it, and
// this app does not ask for that.

public extension CalculationMethodAngles {
    /// `15°`, `18.5°`.
    var fajrDescription: String { Self.degrees(fajrAngle) }

    /// `15°`, or `90 min` when the method defines Isha as a fixed
    /// interval after Maghrib.
    var ishaDescription: String {
        if let ishaIntervalMinutes {
            return "\(ishaIntervalMinutes) min"
        }
        if let ishaAngle {
            return Self.degrees(ishaAngle)
        }
        return "—"
    }

    /// `15° / 15°`, `18.5° / 90 min`.
    var inlineDescription: String {
        "\(fajrDescription) / \(ishaDescription)"
    }

    /// Spoken form, so VoiceOver reads "fifteen degrees" rather than
    /// "fifteen degree slash fifteen degree".
    var spokenDescription: String {
        let fajr = "Fajr \(Self.spokenDegrees(fajrAngle))"
        if let ishaIntervalMinutes {
            return "\(fajr), Isha \(ishaIntervalMinutes) minutes after Maghrib"
        }
        if let ishaAngle {
            return "\(fajr), Isha \(Self.spokenDegrees(ishaAngle))"
        }
        return fajr
    }

    private static func degrees(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return "\(Int(rounded))°"
        }
        return String(format: "%.1f°", rounded)
    }

    private static func spokenDegrees(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return "\(Int(rounded)) degrees"
        }
        return String(format: "%.1f", rounded) + " degrees"
    }
}

public extension CalculationMethodChoice {
    /// The name a person would say out loud — what the row is titled.
    var shortName: String {
        switch self {
        case .muslimWorldLeague: "MWL"
        case .isna: "ISNA"
        case .egyptian: "Egyptian"
        case .ummAlQura: "Umm al-Qura"
        case .karachi: "Karachi"
        case .dubai: "Dubai"
        case .qatar: "Qatar"
        case .kuwait: "Kuwait"
        case .singapore: "Singapore"
        case .tehran: "Tehran"
        case .jafari: "Jafari"
        case .moonsightingCommittee: "Moonsighting Committee"
        case .northAmerica: "North America"
        case .turkey: "Turkey"
        case .other: "Custom"
        }
    }

    /// Who publishes the method. One line, stated and nothing more —
    /// the app says what each method *is*, never which to keep. Where
    /// a method is commonly used is the region row's job, not a
    /// sentence appended to every row.
    var provenance: String {
        switch self {
        case .muslimWorldLeague: "Muslim World League"
        case .isna: "Islamic Society of North America"
        case .egyptian: "Egyptian General Authority of Survey"
        case .ummAlQura: "Umm al-Qura University, Makkah"
        case .karachi: "University of Islamic Sciences, Karachi"
        case .dubai: "Dubai"
        case .qatar: "Qatar"
        case .kuwait: "Kuwait"
        case .singapore: "MUIS, Singapore"
        case .tehran: "Institute of Geophysics, Tehran"
        case .jafari: "Shia Ithna Ashari"
        case .moonsightingCommittee: "Moonsighting Committee"
        case .northAmerica: "North America"
        case .turkey: "Diyanet İşleri Başkanlığı"
        case .other: "Angles you set yourself"
        }
    }

    /// A note that belongs to one method only: where its published
    /// behaviour departs from the two angles shown beside it.
    var caveat: String? {
        switch self {
        case .moonsightingCommittee:
            "Above 55° latitude this method uses a seasonal table instead of the angle."
        default:
            nil
        }
    }

    /// `ISNA · 15° / 15°` — the label that lets a person check the app
    /// against their masjid's timetable without decoding an acronym.
    var titleWithAngles: String {
        guard let angles else { return shortName }
        return "\(shortName) · \(angles.inlineDescription)"
    }
}

/// The name and angles of the calculation as it is *currently
/// configured*, which is not always a published method.
public struct CalculationDescription: Sendable, Equatable {
    /// `ISNA`, or `Custom` once an angle has been changed.
    public let name: String
    public let angles: CalculationMethodAngles?
    /// True once the angles no longer match any published method, so no
    /// surface can call the result by a standard method's name.
    public let isCustom: Bool

    public init(name: String, angles: CalculationMethodAngles?, isCustom: Bool) {
        self.name = name
        self.angles = angles
        self.isCustom = isCustom
    }

    public static func resolve(
        method: CalculationMethodChoice,
        tuning: CalculationTuning
    ) -> CalculationDescription {
        CalculationDescription(
            name: tuning.overridesAngles ? "Custom" : method.shortName,
            angles: CalculationMethodAngles.effective(method: method, tuning: tuning),
            isCustom: tuning.overridesAngles
        )
    }

    /// `ISNA · 15° / 15°` or `Custom · 16° / 90 min`.
    public var title: String {
        guard let angles else { return name }
        return "\(name) · \(angles.inlineDescription)"
    }

    public var spokenTitle: String {
        guard let angles else { return name }
        return "\(name). \(angles.spokenDescription)"
    }
}

public extension CalculationMethodChoice {
    /// The method a region's timetables commonly use. A starting point
    /// offered once, never a recommendation the app repeats.
    static func commonMethod(forCountryCode code: String?) -> CalculationMethodChoice {
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
        case "SG", "MY", "BN", "ID":
            return .singapore
        case "IR":
            return .tehran
        case "TR":
            return .turkey
        case "PK", "BD", "IN", "AF", "LK":
            return .karachi
        case "EG", "SD", "LY", "DZ", "TN", "MA":
            return .egyptian
        case "SA", "YE", "BH", "OM":
            return .ummAlQura
        default:
            return .muslimWorldLeague
        }
    }

    /// Every method a person may choose. `.other` is excluded: it has no
    /// angles of its own, and the Advanced section is how someone
    /// reaches custom angles.
    static var selectable: [CalculationMethodChoice] {
        allCases.filter { $0 != .other }
    }
}
