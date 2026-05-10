import SwiftUI
import IhsanDesignSystem

/// The composing surface — a multi-line text editor with a recorder
/// control and a save button along its bottom edge.
///
/// The editor is always visible (we don't gate it behind a "Begin"
/// button) — the screen is the writing surface and the prompt sits
/// above as the cue. When a recording is attached, an audio pill +
/// trash control appear above the editor; the editor then holds the
/// editable transcript.
struct ReflectionInputComposer: View {
    @Binding var text: String
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
        VStack(alignment: .leading, spacing: IhsanSpacing.md) {
            if let attached = attachedAudio {
                attachedRow(for: attached)
            }

            editor

            if let inlineErrorMessage {
                Text(inlineErrorMessage)
                    .font(IhsanFont.inscription)
                    .tracking(1.2)
                    .foregroundStyle(IhsanColor.brassDark)
                    .multilineTextAlignment(.leading)
                    .accessibilityLabel(inlineErrorMessage)
            }

            controlsRow
        }
        .onChange(of: isTranscribing) { _, newValue in
            // The recorder fires "Recording stopped" on its own; the
            // transcribe phase starts shortly after, often after
            // VoiceOver focus has moved on. Fire a separate
            // announcement so the user knows the system is doing
            // something with their audio.
            if newValue {
                AccessibilityNotification.Announcement("Transcribing audio").post()
            }
        }
    }

    // MARK: - Editor

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty, !isRecording, attachedAudio == nil {
                Text("Write what comes to mind…")
                    .font(IhsanFont.bodyEnglish)
                    .foregroundStyle(IhsanColor.inkDeep.opacity(0.40))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 8)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $text)
                .font(IhsanFont.bodyEnglish)
                .foregroundStyle(IhsanColor.inkDeep)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .frame(minHeight: 120)
                .focused($isFocused)
                .accessibilityLabel("Reflection text")
                .accessibilityHint("Edit your reflection. Save when ready.")
        }
        .background {
            RoundedRectangle(
                cornerRadius: IhsanSpacing.smallCardRadius,
                style: .continuous
            )
            .fill(IhsanColor.inkDeep.opacity(0.05))
            .overlay {
                RoundedRectangle(
                    cornerRadius: IhsanSpacing.smallCardRadius,
                    style: .continuous
                )
                .strokeBorder(IhsanColor.brass.opacity(0.20), lineWidth: 0.5)
            }
        }
    }

    // MARK: - Attached audio strip

    private func attachedRow(for attached: ReflectionInputDraft.AttachedAudio) -> some View {
        HStack(spacing: IhsanSpacing.sm) {
            ReflectionAudioPill(
                isActive: true,
                isPlaying: isPlayingAttached,
                currentTime: attachedCurrentTime,
                duration: attached.duration,
                onToggle: onTogglePlayback
            )

            Spacer()

            Button(role: .destructive, action: onDiscardAudio) {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .foregroundStyle(IhsanColor.brassDark)
                    .background {
                        Circle()
                            .fill(IhsanColor.panelDay.opacity(0.55))
                            .overlay {
                                Circle()
                                    .strokeBorder(IhsanColor.brass.opacity(0.40), lineWidth: 0.5)
                            }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove voice recording")
        }
    }

    // MARK: - Controls row (mic + transcribing + save)

    @ViewBuilder
    private var controlsRow: some View {
        HStack(alignment: .center, spacing: IhsanSpacing.sm) {
            ReflectionRecorderControl(
                isRecording: isRecording,
                elapsed: recordingElapsed,
                onStart: onStartRecording,
                onStop: onStopRecording
            )

            if isRecording {
                Button(action: onCancelRecording) {
                    Text("CANCEL")
                        .font(IhsanFont.inscription)
                        .tracking(1.6)
                        .foregroundStyle(IhsanColor.brassDark)
                        .padding(.horizontal, IhsanSpacing.md)
                        .padding(.vertical, IhsanSpacing.sm)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cancel recording")
            }

            if isTranscribing {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(IhsanColor.brassDark)
                    Text("TRANSCRIBING")
                        .font(IhsanFont.inscription)
                        .tracking(1.4)
                        .foregroundStyle(IhsanColor.brassDark)
                }
                .accessibilityLabel("Transcribing audio")
            }

            Spacer()

            saveButton
        }
    }

    private var saveButton: some View {
        Button(action: onSave) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .semibold))
                Text("SAVE")
                    .font(IhsanFont.inscription)
                    .tracking(1.8)
            }
            .foregroundStyle(IhsanColor.inkDeep)
            .padding(.horizontal, IhsanSpacing.md + 2)
            .padding(.vertical, IhsanSpacing.sm + 2)
            .background {
                Capsule(style: .continuous)
                    .fill(canSave
                          ? AnyShapeStyle(IhsanIridescence.brassStroke(opacity: 0.95))
                          : AnyShapeStyle(IhsanColor.brass.opacity(0.30)))
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(IhsanColor.brassDark.opacity(canSave ? 0.55 : 0.30), lineWidth: 0.5)
                    }
            }
            .opacity(canSave ? 1.0 : 0.45)
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
        .accessibilityLabel("Save reflection")
        .accessibilityHint(canSave ? "Saves the reflection" : "Write or record something first")
    }
}
