import Foundation
import IhsanCore

public enum AdhanSoundCatalog: String, CaseIterable, Codable, Sendable {
    case systemDefault = "default"
    case standardLong = "standard-long"
    case standardShort = "standard-short"
    case fajrAwareLong = "fajr-aware-long"
    case fajrAwareShort = "fajr-aware-short"

    public init(userChoice: String) {
        let normalized = userChoice
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
            .replacingOccurrences(of: ".caf", with: "")
            .replacingOccurrences(of: "adhan-", with: "")

        switch normalized {
        case "standard-long", "long":
            self = .standardLong
        case "standard-short", "short":
            self = .standardShort
        case "fajr-aware-long", "fajr-long", "fajraware-long":
            self = .fajrAwareLong
        case "fajr-aware-short", "fajr-short", "fajraware-short":
            self = .fajrAwareShort
        default:
            self = .systemDefault
        }
    }

    public func fileName(for prayer: Prayer) -> String? {
        switch self {
        case .systemDefault:
            nil
        case .standardLong:
            "adhan-standard-long.caf"
        case .standardShort:
            "adhan-standard-short.caf"
        case .fajrAwareLong:
            prayer == .fajr ? "adhan-fajr-long.caf" : "adhan-standard-long.caf"
        case .fajrAwareShort:
            prayer == .fajr ? "adhan-fajr-short.caf" : "adhan-standard-short.caf"
        }
    }
}
