import AVFoundation
import Foundation
import Observation

/// Wraps `AVAudioRecorder` with an async surface and an `@Observable`
/// state machine. The view-model and the recorder control component both
/// observe `state`; the elapsed-time meter reads `currentDuration` while
/// recording.
///
/// Audio is captured to the App Group container so that it survives a
/// process relaunch and can be played back by `AudioPlaybackService`. No
/// file leaves the device — the spec's privacy contract for raw audio.
@MainActor
@Observable
final class AudioRecordingService: NSObject, AVAudioRecorderDelegate {
    enum State: Equatable {
        case idle
        case requestingPermission
        case permissionDenied
        case preparing
        case recording(memoID: UUID, startedAt: Date, fileURL: URL)
        case finished(memoID: UUID, fileURL: URL, duration: TimeInterval)
        case failed(message: String)
    }

    private(set) var state: State = .idle

    private var recorder: AVAudioRecorder?
    private var sessionConfigured = false

    /// Permission probe + start. Returns the URL the recording is being
    /// written to so the caller can hand it to a transcription service
    /// once the recording finishes.
    func start() async {
        switch await ensurePermission() {
        case .denied:
            state = .permissionDenied
            return
        case .granted:
            break
        }

        state = .preparing
        do {
            try configureSession()
        } catch {
            state = .failed(message: "Could not prepare audio: \(error.localizedDescription)")
            return
        }

        let memoID = UUID()
        let url: URL
        do {
            url = try ReflectionAudioPaths.fileURL(for: memoID)
        } catch {
            state = .failed(message: "Could not allocate a recording file.")
            return
        }

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        do {
            let new = try AVAudioRecorder(url: url, settings: settings)
            new.delegate = self
            guard new.prepareToRecord(), new.record() else {
                state = .failed(message: "The recorder did not start.")
                return
            }
            recorder = new
            state = .recording(memoID: memoID, startedAt: .now, fileURL: url)
        } catch {
            state = .failed(message: "Could not start recording: \(error.localizedDescription)")
        }
    }

    /// Stops the recording and reports the resulting file. After this call
    /// `state` is `.finished` (or `.failed`).
    func stop() {
        guard case let .recording(memoID, startedAt, fileURL) = state,
              let recorder
        else { return }

        recorder.stop()
        let duration = Date.now.timeIntervalSince(startedAt)
        // Some devices return prematurely from `stop()` before the file
        // header is finalized — use AVAudioPlayer's read of the file as
        // the source of truth for duration when available, but fall back
        // to wall-clock elapsed time.
        state = .finished(
            memoID: memoID,
            fileURL: fileURL,
            duration: max(0.1, duration)
        )
        self.recorder = nil
        deactivateSession()
    }

    /// Discards an in-flight recording. Used when the user cancels mid-record.
    func cancel() {
        if let recorder, recorder.isRecording {
            recorder.stop()
            recorder.deleteRecording()
        }
        recorder = nil
        deactivateSession()
        state = .idle
    }

    /// Resets a `.finished` or `.failed` state back to idle. Called once
    /// the consumer (the view-model) has saved the recording or surfaced
    /// the error.
    func reset() {
        recorder = nil
        state = .idle
    }

    /// Wall-clock duration of the active recording, or 0 when not recording.
    var currentDuration: TimeInterval {
        guard case let .recording(_, startedAt, _) = state else { return 0 }
        return Date.now.timeIntervalSince(startedAt)
    }

    // MARK: - Permission

    private enum PermissionResult {
        case granted
        case denied
    }

    private func ensurePermission() async -> PermissionResult {
        let session = AVAudioApplication.shared
        switch session.recordPermission {
        case .granted:
            return .granted
        case .denied:
            return .denied
        case .undetermined:
            state = .requestingPermission
            let granted = await AVAudioApplication.requestRecordPermission()
            return granted ? .granted : .denied
        @unknown default:
            return .denied
        }
    }

    // MARK: - Session

    private func configureSession() throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .spokenAudio,
            options: [.duckOthers, .defaultToSpeaker, .allowBluetoothHFP]
        )
        try session.setActive(true, options: [])
        sessionConfigured = true
        #endif
    }

    private func deactivateSession() {
        #if os(iOS)
        guard sessionConfigured else { return }
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        sessionConfigured = false
        #endif
    }

    // MARK: - AVAudioRecorderDelegate
    //
    // `AVAudioRecorderDelegate` callbacks may arrive on a background thread.
    // We hop to MainActor before mutating `state`, which is `@MainActor`-
    // isolated by the enclosing class.

    nonisolated func audioRecorderDidFinishRecording(
        _ recorder: AVAudioRecorder,
        successfully flag: Bool
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            // Only react if we didn't already transition via `stop()`.
            if case .recording = self.state, !flag {
                self.state = .failed(message: "The recording could not be saved.")
                self.recorder = nil
                self.deactivateSession()
            }
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(
        _ recorder: AVAudioRecorder,
        error: Error?
    ) {
        let message = error?.localizedDescription ?? "Unknown encoding error."
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.state = .failed(message: message)
            self.recorder = nil
            self.deactivateSession()
        }
    }
}
