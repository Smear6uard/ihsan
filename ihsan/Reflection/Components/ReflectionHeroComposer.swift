import SwiftUI
import IhsanDesignSystem
import IhsanFiqhConfig

/// The hero card on the Reflection screen. Carries the prompt + citation
/// at the top and the input composer along the bottom of the same card,
/// so the prompt and the writing surface read as one continuous space.
///
/// We compose `ReflectionInputComposer` here rather than extending the
/// design system's `ReflectionPromptCard` — that card is the lighter
/// affordance used on the Today screen (prompt + Begin button), while
/// this hero is the writing surface.
struct ReflectionHeroComposer: View {
    let prompt: ReflectionPrompt
    @Binding var draftText: String
    let isRecording: Bool
    let recordingElapsed: TimeInterval
    let isTranscribing: Bool
    let attachedAudio: ReflectionInputDraft.AttachedAudio?
    let canSave: Bool
    let isPlayingAttached: Bool
    let attachedCurrentTime: TimeInterval
    let inlineErrorMessage: String?
    let onStartRecording: () -> Void
    let onStopRecording: () -> Void
    let onCancelRecording: () -> Void
    let onDiscardAudio: () -> Void
    let onTogglePlayback: () -> Void
    let onSave: () -> Void

    @FocusState.Binding var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.lg) {
            promptHeader

            Rectangle()
                .fill(IhsanColor.atmospheric)
                .frame(height: IhsanSpacing.hairline)
                .accessibilityHidden(true)

            ReflectionInputComposer(
                text: $draftText,
                isRecording: isRecording,
                recordingElapsed: recordingElapsed,
                isTranscribing: isTranscribing,
                attachedAudio: attachedAudio,
                canSave: canSave,
                isPlayingAttached: isPlayingAttached,
                attachedCurrentTime: attachedCurrentTime,
                inlineErrorMessage: inlineErrorMessage,
                onStartRecording: onStartRecording,
                onStopRecording: onStopRecording,
                onCancelRecording: onCancelRecording,
                onDiscardAudio: onDiscardAudio,
                onTogglePlayback: onTogglePlayback,
                onSave: onSave,
                isFocused: $isFocused
            )
        }
        .padding(IhsanSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ihsanGlass(intensity: .hero)
    }

    private var promptHeader: some View {
        HStack(alignment: .top, spacing: IhsanSpacing.md) {
            // Slim brass marginal mark — a Mushaf-style accent that makes
            // the prompt read as a passage from a book rather than a UI string.
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(IhsanColor.statusQada)
                .frame(width: 2)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.vertical, 4)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
                Text("REFLECTION")
                    .font(IhsanFont.smallCaps)
                    .tracking(1.4)
                    .foregroundStyle(IhsanColor.textMuted)

                Text(prompt.promptEn)
                    .font(IhsanFont.subtitle)
                    .italic()
                    .foregroundStyle(IhsanColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(prompt.citationEn)
                    .font(IhsanFont.citation)
                    .foregroundStyle(IhsanColor.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Today's reflection: \(prompt.promptEn). Source: \(prompt.citationEn).")
    }
}
