import Foundation

/// Editable draft for the in-progress reflection. The view-model owns one
/// of these and resets it after a successful save.
///
/// Three shapes:
///   - text-only: typed text, no audio
///   - voice-only: a recorded audio file with a transcript that the user
///     can edit before saving (the transcript becomes `typedText`-or-
///     `transcript` on the saved record per the model's split)
///   - mixed: both typed text and an attached recording
///
/// The draft never carries the raw `Reflection` — that's only constructed
/// at save time. This keeps the view-model from accidentally retaining a
/// SwiftData object across the save boundary.
struct ReflectionInputDraft: Equatable {
    var typedText: String = ""
    var attachedAudio: AttachedAudio?

    struct AttachedAudio: Equatable {
        let memoID: UUID
        let fileURL: URL
        let duration: TimeInterval
        var transcript: String?
    }

    /// True when there's something worth saving — either typed content or
    /// an attached recording.
    var canSave: Bool {
        let trimmedText = typedText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedText.isEmpty || attachedAudio != nil
    }

    var hasAudio: Bool { attachedAudio != nil }

    /// Resets the draft to empty after a successful save.
    mutating func clear() {
        typedText = ""
        attachedAudio = nil
    }
}
