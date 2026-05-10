import Foundation
import IhsanCore
import IhsanFiqhConfig
import SwiftData

/// Persists reflections via direct `ModelContext` writes.
///
/// This bypasses the App Intents pattern used elsewhere in Ihsan
/// (`LogPrayerWithStatusIntent`, `ToggleJamaahIntent`) deliberately.
/// Reflections are heavier, more structured writes than those atomic
/// intents are designed for: a single save bundles typed text, a
/// transcript, an associated audio file's UUID, the prompt that was
/// active, and the prompt's citation. Wrapping that in an intent would
/// stretch the intent surface beyond its intent (small, replayable,
/// sharable actions). The writer instead lives where the input does — on
/// the view-model — and the model context does the work directly.
///
/// If the schema ever needs to surface reflection writes through Siri or
/// Shortcuts, that's an additional intent on top of this writer, not a
/// replacement for it.
@MainActor
struct ReflectionWriter {
    let modelContext: ModelContext

    /// Saves a new reflection from a draft. The draft's transcript becomes
    /// the saved record's `transcript`; the typed text becomes
    /// `typedText`. When both are present they are stored side-by-side so
    /// the feed card can render the mixed shape without having to
    /// disambiguate after the fact.
    func save(
        draft: ReflectionInputDraft,
        prompt: ReflectionPrompt,
        promptDate: Date
    ) throws {
        let trimmedTyped = draft.typedText
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let reflection = Reflection(
            kind: .daily,
            forDate: Calendar.current.startOfDay(for: promptDate),
            loggedTimeZoneIdentifier: TimeZone.current.identifier,
            promptText: prompt.promptEn,
            promptCitation: prompt.citationEn,
            typedText: trimmedTyped.isEmpty ? nil : trimmedTyped,
            transcript: draft.attachedAudio?.transcript,
            voiceMemoID: draft.attachedAudio?.memoID
        )
        modelContext.insert(reflection)
        try modelContext.save()
    }
}
