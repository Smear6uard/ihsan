import AVFoundation
import Foundation
import Observation

/// Single shared playback service. Only one memo plays at a time — when a
/// new memo starts, any active playback is replaced. This keeps the feed
/// from devolving into overlapping voices when the user taps several pills.
@MainActor
@Observable
final class AudioPlaybackService: NSObject, AVAudioPlayerDelegate {
    enum State: Equatable {
        case idle
        case playing(memoID: UUID, duration: TimeInterval)
        case paused(memoID: UUID, duration: TimeInterval)
        case failed(message: String)
    }

    private(set) var state: State = .idle
    private(set) var currentTime: TimeInterval = 0

    private var player: AVAudioPlayer?
    private var ticker: Task<Void, Never>?

    /// Begin playback of the memo at `url`. If another memo is playing it
    /// is stopped first.
    func play(memoID: UUID, url: URL) {
        if let player, player.isPlaying {
            player.stop()
        }
        ticker?.cancel()
        ticker = nil

        do {
            try configureSessionForPlayback()
            let new = try AVAudioPlayer(contentsOf: url)
            new.delegate = self
            new.prepareToPlay()
            guard new.play() else {
                state = .failed(message: "The recording could not be played.")
                return
            }
            player = new
            state = .playing(memoID: memoID, duration: new.duration)
            currentTime = 0
            startTicker()
        } catch {
            state = .failed(message: "Could not load the recording.")
        }
    }

    /// Pause an active playback. Resume with `resume()`.
    func pause() {
        guard let player, player.isPlaying,
              case let .playing(memoID, duration) = state
        else { return }
        player.pause()
        ticker?.cancel()
        ticker = nil
        state = .paused(memoID: memoID, duration: duration)
        currentTime = player.currentTime
    }

    /// Resume a previously paused playback.
    func resume() {
        guard let player,
              case let .paused(memoID, duration) = state
        else { return }
        guard player.play() else {
            state = .failed(message: "Playback could not resume.")
            return
        }
        state = .playing(memoID: memoID, duration: duration)
        startTicker()
    }

    /// Stop playback and clear state.
    func stop() {
        ticker?.cancel()
        ticker = nil
        player?.stop()
        player = nil
        state = .idle
        currentTime = 0
    }

    var activeMemoID: UUID? {
        switch state {
        case .playing(let id, _), .paused(let id, _): return id
        case .idle, .failed: return nil
        }
    }

    var isPlaying: Bool {
        if case .playing = state { return true }
        return false
    }

    // MARK: - Internals

    private func configureSessionForPlayback() throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio, options: [])
        try session.setActive(true, options: [])
        #endif
    }

    /// Drives `currentTime` updates so the progress bar moves smoothly.
    private func startTicker() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(120))
                guard let self else { return }
                guard let player = self.player, player.isPlaying else {
                    return
                }
                self.currentTime = player.currentTime
            }
        }
    }

    // MARK: - AVAudioPlayerDelegate

    nonisolated func audioPlayerDidFinishPlaying(
        _ player: AVAudioPlayer,
        successfully flag: Bool
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.ticker?.cancel()
            self.ticker = nil
            self.player = nil
            self.state = .idle
            self.currentTime = 0
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(
        _ player: AVAudioPlayer,
        error: Error?
    ) {
        let message = error?.localizedDescription ?? "Decoding error."
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.state = .failed(message: message)
            self.player = nil
            self.ticker?.cancel()
            self.ticker = nil
        }
    }
}
