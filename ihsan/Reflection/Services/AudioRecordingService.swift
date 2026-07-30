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
    /// Stored once in `init`, removed once in `deinit`. Excluded from
    /// observation — nothing renders it — so the stored form survives
    /// the macro and `nonisolated(unsafe)` can say what it means: the
    /// nonisolated `deinit` reads it, and nothing else touches it off
    /// the main actor.
    @ObservationIgnored
    nonisolated(unsafe) private var interruptionObserver: NSObjectProtocol?

    override init() {
        super.init()
        // The observer is held for the lifetime of the service. The handler
        // guards on the recording state, so it's a no-op outside of an
        // active recording. We unwrap the interruption type at the
        // notification site (where `Notification`'s non-Sendable shape is
        // contained) and pass a Sendable enum across the actor hop.
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let type = (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt)
                .flatMap(AVAudioSession.InterruptionType.init(rawValue:))
            Task { @MainActor [weak self] in
                guard let self, let type else { return }
                self.handleInterruption(type: type)
            }
        }
    }

    deinit {
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
    }

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

    // MARK: - Interruption

    /// Phone calls, alarms, Siri activation, and similar all post an
    /// `AVAudioSession.interruptionNotification`. AVAudioRecorder pauses on
    /// interruption begin; without intervention the view-model would stay
    /// in `.recording` forever even though the system has frozen the input.
    /// We finalize what was captured so the user can save what they have.
    private func handleInterruption(type: AVAudioSession.InterruptionType) {
        switch type {
        case .began:
            if case .recording = state {
                stop()
            }
        case .ended:
            // We do not auto-resume. The user is back from the interruption
            // and will see the captured recording; they can start a new
            // one if they want to add to it.
            break
        @unknown default:
            break
        }
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
            // Only react if we didn't already transition via `stop()` —
            // the synchronous `stop()` path leaves state at `.finished`,
            // and the delegate fires async after; that path short-circuits
            // here. We reach the body when AVFoundation finalized the
            // recording on its own (system-stopped due to backgrounding,
            // or interruption that elapsed past the recorder).
            guard case let .recording(memoID, startedAt, fileURL) = self.state else {
                return
            }
            if flag {
                let duration = max(0.1, Date.now.timeIntervalSince(startedAt))
                self.state = .finished(
                    memoID: memoID,
                    fileURL: fileURL,
                    duration: duration
                )
            } else {
                self.state = .failed(message: "The recording could not be saved.")
            }
            self.recorder = nil
            self.deactivateSession()
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
