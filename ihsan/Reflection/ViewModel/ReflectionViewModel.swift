import Foundation
import Observation
import SwiftData
import IhsanCore
import IhsanFiqhConfig

/// Drives the Reflection screen. Owns the input draft, the recorder, the
/// playback service, and the prompt. The screen passes in `@Query` results
/// for past reflections; the view-model groups them into date sections
/// and exposes a composite `ReflectionState`.
///
/// **Why writes go through the view-model, not an App Intent.**
/// Reflections are larger structured writes than the atomic intents are
/// designed for. The view-model owns a `ReflectionWriter` that performs
/// `ModelContext` inserts directly. See `ReflectionWriter.swift` for the
/// full rationale.
@MainActor
@Observable
final class ReflectionViewModel {
    var state: ReflectionState = .loading
    var draft = ReflectionInputDraft()

    /// Set to true when the screen should focus the text editor — driven
    /// by the `OpenReflectionIntent` deeplink and reset by the screen
    /// once focus is applied.
    var requestsInputFocus: Bool = false

    /// Inline error surfaced near the input area. Distinct from
    /// `ReflectionState.error` (which is for catastrophic load failures);
    /// this is used for routine transcription/recording problems that
    /// shouldn't blow away the prompt and feed.
    var inputErrorMessage: String?

    /// True while a transcription is in flight after a recording stops.
    var isTranscribing: Bool = false

    let recorder: AudioRecordingService
    let playback: AudioPlaybackService

    private let transcription: SpeechTranscriptionService
    private let configService: FiqhConfigService
    private let writer: ReflectionWriter
    private var cachedReflections: [Reflection] = []
    private var didBootstrap = false

    init(
        modelContext: ModelContext,
        configService: FiqhConfigService = .shared,
        recorder: AudioRecordingService? = nil,
        playback: AudioPlaybackService? = nil,
        transcription: SpeechTranscriptionService = SpeechTranscriptionService()
    ) {
        self.configService = configService
        self.recorder = recorder ?? AudioRecordingService()
        self.playback = playback ?? AudioPlaybackService()
        self.transcription = transcription
        self.writer = ReflectionWriter(modelContext: modelContext)
    }

    /// Idempotent bootstrap. Safe to call from `.task`.
    func bootstrap(reflections: [Reflection]) async {
        cachedReflections = reflections
        if didBootstrap {
            // Just refresh the snapshot if the prompt is already loaded.
            recomputeReadyState()
            return
        }

        didBootstrap = true
        let now = Date.now
        let promptAnchor = Calendar.current.startOfDay(for: now)
        let bucket = ReflectionTimeOfDay.bucket(for: now)

        do {
            let prompt = try await configService.prompt(
                for: promptAnchor,
                timeOfDay: bucket
            )
            let framing = try await configService.currentConfig().framing
            let sections = ReflectionDateGrouping.sections(
                from: cachedReflections,
                now: now
            )
            state = .ready(.init(
                prompt: prompt,
                promptDate: promptAnchor,
                framing: framing,
                sections: sections
            ))
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    /// Re-aggregates the feed sections from the latest `@Query` results.
    /// Called by the screen on `onChange(of: reflections.count)`.
    func refresh(reflections: [Reflection]) {
        cachedReflections = reflections
        recomputeReadyState()
    }

    private func recomputeReadyState() {
        guard case let .ready(snapshot) = state else { return }
        let sections = ReflectionDateGrouping.sections(
            from: cachedReflections,
            now: .now
        )
        state = .ready(.init(
            prompt: snapshot.prompt,
            promptDate: snapshot.promptDate,
            framing: snapshot.framing,
            sections: sections
        ))
    }

    // MARK: - Recording flow

    /// Begins recording. Surface error states inline.
    func beginRecording() async {
        inputErrorMessage = nil
        await recorder.start()
        if case .permissionDenied = recorder.state {
            inputErrorMessage = "Microphone access is needed to record. You can enable it in Settings."
        } else if case let .failed(message) = recorder.state {
            inputErrorMessage = message
        }
    }

    /// Stops recording and runs an on-device transcription. The audio is
    /// attached to the draft regardless of whether transcription succeeds.
    func endRecording() async {
        recorder.stop()
        guard case let .finished(memoID, fileURL, duration) = recorder.state else {
            return
        }

        // Attach the audio immediately so the user can save even if
        // transcription is slow or fails.
        draft.attachedAudio = .init(
            memoID: memoID,
            fileURL: fileURL,
            duration: duration,
            transcript: nil
        )

        isTranscribing = true
        defer {
            isTranscribing = false
            recorder.reset()
        }

        do {
            let transcript = try await transcription.transcribe(fileURL: fileURL)
            draft.attachedAudio?.transcript = transcript
            // Surface the auto-transcript in the editor when the user
            // hasn't typed anything yet — they can edit before saving.
            // The original transcript is preserved separately on the
            // saved record so the auto-generated version stays as
            // ground truth alongside the user's curated edit.
            let typedTrimmed = draft.typedText
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if typedTrimmed.isEmpty, let transcript, !transcript.isEmpty {
                draft.typedText = transcript
            }
        } catch SpeechTranscriptionService.TranscriptionError.permissionDenied {
            inputErrorMessage = "Speech recognition wasn't authorized — your audio is saved without a transcript."
        } catch {
            inputErrorMessage = "Couldn't transcribe automatically — your audio is saved. You can type a note instead."
        }
    }

    /// User tapped cancel during recording.
    func cancelRecording() {
        recorder.cancel()
    }

    /// User tapped trash to remove an attached recording from the draft
    /// before saving.
    func discardAttachedAudio() {
        if let memoID = draft.attachedAudio?.memoID {
            // Best-effort cleanup of the orphan file; not fatal if it fails.
            if let url = try? ReflectionAudioPaths.fileURL(for: memoID) {
                try? FileManager.default.removeItem(at: url)
            }
            if playback.activeMemoID == memoID {
                playback.stop()
            }
        }
        draft.attachedAudio = nil
    }

    // MARK: - Save

    /// Saves the current draft. Returns true on success.
    @discardableResult
    func save() -> Bool {
        guard case let .ready(snapshot) = state, draft.canSave else {
            return false
        }
        do {
            try writer.save(
                draft: draft,
                prompt: snapshot.prompt,
                promptDate: snapshot.promptDate
            )
            draft.clear()
            inputErrorMessage = nil
            return true
        } catch {
            inputErrorMessage = "Couldn't save your reflection — please try again."
            return false
        }
    }

    // MARK: - Playback

    func togglePlayback(for reflection: Reflection) {
        guard let memoID = reflection.voiceMemoID,
              let url = ReflectionAudioPaths.existingFileURL(for: memoID)
        else { return }

        if playback.activeMemoID == memoID {
            switch playback.state {
            case .playing: playback.pause()
            case .paused:  playback.resume()
            default:       playback.play(memoID: memoID, url: url)
            }
        } else {
            playback.play(memoID: memoID, url: url)
        }
    }

    func togglePlaybackForDraft() {
        guard let attached = draft.attachedAudio else { return }
        if playback.activeMemoID == attached.memoID {
            switch playback.state {
            case .playing: playback.pause()
            case .paused:  playback.resume()
            default:       playback.play(memoID: attached.memoID, url: attached.fileURL)
            }
        } else {
            playback.play(memoID: attached.memoID, url: attached.fileURL)
        }
    }

    // MARK: - Deeplink

    /// Reads the deeplink flag and, if fresh, requests input focus. Called
    /// by the screen on `.task` and on scene-phase active.
    func consumeDeeplinkIfNeeded() {
        guard ReflectionDeeplink.isFresh() else { return }
        requestsInputFocus = true
        ReflectionDeeplink.clear()
    }
}
