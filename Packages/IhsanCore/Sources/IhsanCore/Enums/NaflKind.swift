import Foundation

/// A kind of voluntary (nafl) worship the user can record. String-backed via
/// `storageKey` so future kinds (e.g. tarawih) can be added without breaking
/// stored data, and so rawatib can carry which fard they surround.
///
/// Recorded, never scored: nothing in the app counts nafl toward anything.
public enum NaflKind: Hashable, Sendable, Codable {
    case rawatibBefore(Prayer)
    case rawatibAfter(Prayer)
    case duha
    case qiyam
    case witr

    /// The stable string written to storage, e.g. `"rawatibBefore.fajr"`,
    /// `"duha"`, `"witr"`.
    public var storageKey: String {
        switch self {
        case .rawatibBefore(let prayer):
            "rawatibBefore.\(prayer.rawValue)"
        case .rawatibAfter(let prayer):
            "rawatibAfter.\(prayer.rawValue)"
        case .duha:
            "duha"
        case .qiyam:
            "qiyam"
        case .witr:
            "witr"
        }
    }

    /// Fails on unknown keys rather than trapping, so older builds tolerate
    /// data written by newer ones.
    public init?(storageKey: String) {
        switch storageKey {
        case "duha":
            self = .duha
        case "qiyam":
            self = .qiyam
        case "witr":
            self = .witr
        default:
            let parts = storageKey.split(separator: ".", maxSplits: 1)
            guard parts.count == 2, let prayer = Prayer(rawValue: String(parts[1])) else {
                return nil
            }
            switch parts[0] {
            case "rawatibBefore":
                self = .rawatibBefore(prayer)
            case "rawatibAfter":
                self = .rawatibAfter(prayer)
            default:
                return nil
            }
        }
    }

    /// Every kind this build knows: ten rawatib slots plus duha, qiyam, witr.
    public static var allKnownKinds: [NaflKind] {
        Prayer.allCases.map(NaflKind.rawatibBefore)
            + Prayer.allCases.map(NaflKind.rawatibAfter)
            + [.duha, .qiyam, .witr]
    }

    /// The fard prayer a rawatib kind surrounds; nil for the free-standing kinds.
    public var surroundedFard: Prayer? {
        switch self {
        case .rawatibBefore(let prayer), .rawatibAfter(let prayer):
            prayer
        case .duha, .qiyam, .witr:
            nil
        }
    }

    public var displayNameEnglish: String {
        switch self {
        case .rawatibBefore(let prayer):
            "Before \(prayer.displayNameEnglish)"
        case .rawatibAfter(let prayer):
            "After \(prayer.displayNameEnglish)"
        case .duha:
            "Duha"
        case .qiyam:
            "Qiyam"
        case .witr:
            "Witr"
        }
    }

    public var displayNameArabic: String {
        switch self {
        case .rawatibBefore(let prayer):
            "قبل \(prayer.displayNameArabic)"
        case .rawatibAfter(let prayer):
            "بعد \(prayer.displayNameArabic)"
        case .duha:
            "الضحى"
        case .qiyam:
            "القيام"
        case .witr:
            "الوتر"
        }
    }
}
