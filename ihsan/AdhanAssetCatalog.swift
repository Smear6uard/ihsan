import Foundation
import IhsanCore

public enum AdhanSoundChoice: Equatable, Sendable {
    case standardLong
    case standardShort
    case fajrLong
    case fajrShort
    case systemDefault

    public var fileName: String? {
        switch self {
        case .standardLong:
            "adhan-standard-long.caf"
        case .standardShort:
            "adhan-standard-short.caf"
        case .fajrLong:
            "adhan-fajr-long.caf"
        case .fajrShort:
            "adhan-fajr-short.caf"
        case .systemDefault:
            nil
        }
    }

    public static func resolvedSound(
        for prayer: Prayer,
        choice: UserSettings.AdhanSoundOption,
        fajrAware: Bool
    ) -> AdhanSoundChoice {
        switch choice {
        case .systemDefault:
            .systemDefault
        case .standardLong:
            fajrAware && prayer == .fajr ? .fajrLong : .standardLong
        case .standardShort:
            fajrAware && prayer == .fajr ? .fajrShort : .standardShort
        case .fajrAwareLong:
            prayer == .fajr ? .fajrLong : .standardLong
        case .fajrAwareShort:
            prayer == .fajr ? .fajrShort : .standardShort
        }
    }

    public static func bundledSoundName(
        for choice: AdhanSoundChoice,
        bundle: Bundle = .main
    ) -> String? {
        guard let fileName = choice.fileName else {
            return nil
        }

        let url = URL(fileURLWithPath: fileName)
        let resourceName = url.deletingPathExtension().lastPathComponent
        let fileExtension = url.pathExtension

        guard bundle.url(forResource: resourceName, withExtension: fileExtension) != nil else {
            return nil
        }

        return fileName
    }

    public func bundledSoundName(bundle: Bundle = .main) -> String? {
        Self.bundledSoundName(for: self, bundle: bundle)
    }
}

public extension UserSettings {
    enum AdhanSoundOption: String, CaseIterable, Codable, Sendable {
        case systemDefault = "default"
        case standardLong = "standard-long"
        case standardShort = "standard-short"
        case fajrAwareLong = "fajr-aware-long"
        case fajrAwareShort = "fajr-aware-short"

        public init(rawSetting: String) {
            let normalized = rawSetting
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
    }
}
