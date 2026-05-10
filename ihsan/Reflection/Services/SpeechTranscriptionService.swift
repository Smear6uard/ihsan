import Foundation
import Speech

/// Wraps `SFSpeechRecognizer` for one-shot, on-device transcription of a
/// finished audio file. The privacy contract is enforced by setting
/// `requiresOnDeviceRecognition = true` — Apple's Speech framework will
/// then refuse to fall back to a cloud transcription path.
///
/// Permission is requested lazily on the first transcription. If the user
/// declines, the caller receives `.permissionDenied` and surfaces the
/// recording as voice-only without a transcript — the audio file is still
/// saved.
///
/// Marked `nonisolated` so a default-MainActor caller can construct one
/// inside a property initializer without hopping to the main actor first.
nonisolated struct SpeechTranscriptionService {
    enum TranscriptionError: Error, LocalizedError {
        case permissionDenied
        case localeUnsupported
        case recognizerUnavailable
        case onDeviceUnavailable
        case recognitionFailed(String)

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Speech recognition permission was not granted."
            case .localeUnsupported:
                return "Speech recognition isn't available for this device's language."
            case .recognizerUnavailable:
                return "The speech recognizer is temporarily unavailable."
            case .onDeviceUnavailable:
                return "On-device speech recognition isn't available on this device."
            case .recognitionFailed(let detail):
                return "Transcription failed: \(detail)"
            }
        }
    }

    /// Best-effort on-device transcription of an audio file. The result is
    /// trimmed of leading/trailing whitespace; an empty transcript is
    /// returned as nil so the caller can show the audio pill alone.
    func transcribe(fileURL: URL) async throws -> String? {
        try await ensureAuthorization()

        guard let recognizer = SFSpeechRecognizer(locale: .current)
                ?? SFSpeechRecognizer(locale: Locale(identifier: "en_US")),
              recognizer.isAvailable
        else {
            throw TranscriptionError.recognizerUnavailable
        }
        guard recognizer.supportsOnDeviceRecognition else {
            throw TranscriptionError.onDeviceUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false

        return try await withCheckedThrowingContinuation { continuation in
            // The recognizer task delivers a series of partial results; we
            // wait for the final one and resume exactly once.
            var hasResumed = false
            let task = recognizer.recognitionTask(with: request) { result, error in
                if hasResumed { return }
                if let error {
                    hasResumed = true
                    continuation.resume(
                        throwing: TranscriptionError.recognitionFailed(
                            error.localizedDescription
                        )
                    )
                    return
                }
                guard let result, result.isFinal else { return }
                hasResumed = true
                let trimmed = result.bestTranscription.formattedString
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: trimmed.isEmpty ? nil : trimmed)
            }
            // The reference is held by the framework while the task runs;
            // we don't need to retain it ourselves.
            _ = task
        }
    }

    private func ensureAuthorization() async throws {
        let status = SFSpeechRecognizer.authorizationStatus()
        switch status {
        case .authorized:
            return
        case .denied, .restricted:
            throw TranscriptionError.permissionDenied
        case .notDetermined:
            let granted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
            if !granted {
                throw TranscriptionError.permissionDenied
            }
        @unknown default:
            throw TranscriptionError.permissionDenied
        }
    }
}
