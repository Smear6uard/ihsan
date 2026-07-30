import AVFoundation
import Foundation
import IhsanNotifications
import Observation
import OSLog

/// Plays the full call to prayer inside the app.
///
/// A notification tone is capped at thirty seconds by iOS, so the whole
/// adhan can only be heard while the app is running. This is that path:
/// tapping through from a prayer notification, or pressing Play in
/// Set → Adhan.
///
/// The silent switch is honoured by default. `.ambient` is the category
/// that respects it and yields to whatever else is playing; `.playback`
/// overrides both, and the app only ever asks for that when someone has
/// explicitly said the adhan should sound like an alarm. The session is
/// deactivated when playback ends so a podcast or a navigation voice
/// resumes on its own.
@MainActor
@Observable
final class AdhanPlayer: NSObject {
    static let shared = AdhanPlayer()

    private(set) var isPlaying = false
    /// Set when the last attempt could not produce sound, phrased for
    /// the person rather than the log.
    private(set) var lastFailure: String?

    private var player: AVAudioPlayer?
    private let logger = Logger(subsystem: "com.sameerstudios.ihsan", category: "AdhanPlayer")

    override private init() { super.init() }

    /// Whether the full recording is present in the bundle.
    static var isAvailable: Bool {
        assetURL != nil
    }

    static var assetURL: URL? {
        let url = URL(fileURLWithPath: AdhanAsset.fullAdhan)
        return Bundle.main.url(
            forResource: url.deletingPathExtension().lastPathComponent,
            withExtension: url.pathExtension
        )
    }

    /// - Parameter overridesSilentSwitch: the user's
    ///   `adhanPlaysInSilentMode` preference. When false — the default —
    ///   a phone on silent stays silent.
    func play(overridesSilentSwitch: Bool) {
        stop()

        guard let url = Self.assetURL else {
            lastFailure = "The adhan recording is not in this build yet."
            logger.error("Full adhan asset missing: \(AdhanAsset.fullAdhan, privacy: .public)")
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                overridesSilentSwitch ? .playback : .ambient,
                mode: .default,
                options: overridesSilentSwitch ? [] : [.mixWithOthers]
            )
            try session.setActive(true)

            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.prepareToPlay()
            guard player.play() else {
                lastFailure = "The adhan could not start playing."
                return
            }
            self.player = player
            isPlaying = true
            lastFailure = nil
        } catch {
            lastFailure = "The adhan could not start playing."
            logger.error("Adhan playback failed: \(String(describing: error), privacy: .public)")
        }
    }

    func stop() {
        player?.stop()
        player = nil
        guard isPlaying else { return }
        isPlaying = false
        deactivateSession()
    }

    private func deactivateSession() {
        // Yield the session back so whatever was playing before resumes.
        try? AVAudioSession.sharedInstance().setActive(
            false, options: .notifyOthersOnDeactivation
        )
    }
}

extension AdhanPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.player = nil
            self.isPlaying = false
            self.deactivateSession()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        Task { @MainActor in
            self.lastFailure = "The adhan recording could not be read."
            self.player = nil
            self.isPlaying = false
            self.deactivateSession()
        }
    }
}
