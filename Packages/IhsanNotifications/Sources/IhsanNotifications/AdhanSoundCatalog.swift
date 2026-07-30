import Foundation
import IhsanCore

// MARK: - The swap points
//
// Every audio file the app can play is named here and nowhere else.
// When a recording lands, drop the file into `ihsan/Resources/Adhans/`
// and change one line below — no call site refers to a file name.
//
// Two families, because iOS treats them differently:
//
//   * Notification tones must be bundled `.caf` no longer than 30
//     seconds. iOS plays them; the app is not running.
//   * The in-app recording has no length limit and is played by the
//     app through AVAudioPlayer, which is the only way to hear a full
//     adhan.
//
// Nothing here is a real recording yet. `ihsan-chime*.caf` are
// synthesised from sine partials (see `generate-placeholders.py` beside
// the assets) so there is no license question, and the full-adhan file
// is a placeholder of the same material. `takbirat` deliberately names
// a file that does not exist: the catalog checks the bundle, so the
// option describes itself honestly until the muezzin's recording
// arrives.

public enum AdhanAsset {
    // MARK: Notification tones (bundled .caf, ≤ 30s)

    /// The chime: one struck bowl with a softer echo. Warm, low, and
    /// slow to fade.
    public static let chime = "ihsan-chime.caf"

    /// The dawn variant: the same bowl struck four times, rising in
    /// pitch and volume across twenty-four seconds. Nothing startles.
    public static let chimeDawn = "ihsan-chime-dawn.caf"

    /// The muezzin's opening takbīrāt. **Not yet recorded** — drop the
    /// file in and this option starts working, with no other change.
    public static let takbirat = "ihsan-takbirat.caf"

    // MARK: In-app playback (any length)

    /// The full call to prayer, played by the app on request. Currently
    /// a placeholder built from the same synthesised material; replace
    /// with the recording and rename here.
    public static let fullAdhan = "ihsan-adhan-full-placeholder.m4a"

    /// The gentle wake plays the chime. One tone, one constant — the
    /// wake and the notification can never drift apart.
    public static var nightWake: String { chime }
}

// MARK: - What a person chooses

/// The sound one prayer makes.
///
/// Three choices, plus a dawn variant offered only where it belongs.
/// There is no "system default": a notification from this app either
/// speaks in the app's own voice or stays silent.
public enum AdhanSoundCatalog: String, CaseIterable, Codable, Sendable {
    /// Banner only. The notification arrives; the room does not change.
    case silent

    /// The chime.
    case chime

    /// The chime's rising dawn variant. Offered for Fajr only — the
    /// prayer that has to wake someone rather than interrupt them.
    case chimeDawn = "chime-dawn"

    /// The muezzin's takbīrāt.
    case takbirat

    /// Read a stored choice, including the vocabulary earlier builds
    /// wrote. Anything unrecognised becomes the chime rather than
    /// silence: a person who asked to be called should be called.
    public init(userChoice: String) {
        let normalized = userChoice
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
            .replacingOccurrences(of: ".caf", with: "")
            .replacingOccurrences(of: "adhan-", with: "")

        switch normalized {
        case "silent", "none", "banner":
            self = .silent
        case "chime-dawn", "fajr-aware-long", "fajr-aware-short", "fajr-long", "fajr-short":
            self = .chimeDawn
        case "takbirat", "standard-short", "short":
            self = .takbirat
        default:
            // "default", "standard-long", and anything unknown.
            self = .chime
        }
    }

    /// The choices offered for a given prayer. The dawn variant is
    /// Fajr's alone; offering a rising wake to someone already awake
    /// would be offering them nothing.
    public static func options(for prayer: Prayer) -> [AdhanSoundCatalog] {
        prayer == .fajr
            ? [.chime, .chimeDawn, .takbirat, .silent]
            : [.chime, .takbirat, .silent]
    }

    /// The file this choice wants, or `nil` when it wants none.
    public var preferredFileName: String? {
        switch self {
        case .silent: nil
        case .chime: AdhanAsset.chime
        case .chimeDawn: AdhanAsset.chimeDawn
        case .takbirat: AdhanAsset.takbirat
        }
    }

    /// What actually plays, given which files are present.
    ///
    /// A choice whose recording has not landed falls back to the chime
    /// rather than to silence or to the system tone — and the settings
    /// row says so, so the fallback is never a surprise.
    public func resolvedFileName(using resolver: AdhanSoundFileResolver) -> String? {
        guard let preferred = preferredFileName else { return nil }
        if resolver.fileExists(preferred) { return preferred }
        guard resolver.fileExists(AdhanAsset.chime) else { return nil }
        return AdhanAsset.chime
    }

    /// True when this option's own recording is missing and it is
    /// standing in with the chime.
    public func awaitsRecording(using resolver: AdhanSoundFileResolver) -> Bool {
        guard let preferred = preferredFileName else { return false }
        return !resolver.fileExists(preferred)
    }
}

/// Whether a bundled audio file is actually present. Injected so tests
/// can describe a device where a recording has or has not landed.
public struct AdhanSoundFileResolver: Sendable {
    public let fileExists: @Sendable (String) -> Bool

    public init(fileExists: @escaping @Sendable (String) -> Bool) {
        self.fileExists = fileExists
    }

    public static let mainBundle = AdhanSoundFileResolver { fileName in
        let url = URL(fileURLWithPath: fileName)
        return Bundle.main.url(
            forResource: url.deletingPathExtension().lastPathComponent,
            withExtension: url.pathExtension
        ) != nil
    }

    /// Every file present — the shape of the world once the recordings
    /// land.
    public static let allPresent = AdhanSoundFileResolver { _ in true }
}
