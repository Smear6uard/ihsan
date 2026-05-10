import SwiftUI
import IhsanCore
import IhsanDesignSystem

/// Expanded view of a single past reflection — shown in a sheet when the
/// user taps a feed card. Read-only for v1; an "Edit" affordance is the
/// natural next addition (deferred to v1.1 per the spec).
struct ReflectionDetailSheet: View {
    let reflection: Reflection
    let isPlaybackActive: Bool
    let isPlaybackPlaying: Bool
    let playbackCurrentTime: TimeInterval
    let onTogglePlayback: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var closeButtonDismissed = false

    var body: some View {
        ZStack {
            IhsanColor.ground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: IhsanSpacing.lg) {
                    metadataHeader
                    promptBlock

                    if let title = reflection.aiSummaryTitle?
                        .trimmingCharacters(in: .whitespacesAndNewlines),
                       !title.isEmpty {
                        Text(title)
                            .font(IhsanFont.subtitle)
                            .italic()
                            .foregroundStyle(IhsanColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let memoID = reflection.voiceMemoID,
                       let url = ReflectionAudioPaths.existingFileURL(for: memoID) {
                        ReflectionAudioPill(
                            isActive: isPlaybackActive,
                            isPlaying: isPlaybackPlaying,
                            currentTime: playbackCurrentTime,
                            duration: AudioFileDurationCache.shared.duration(for: url),
                            onToggle: onTogglePlayback
                        )
                    }

                    bodyText

                    Spacer(minLength: IhsanSpacing.xl)
                }
                .padding(IhsanSpacing.lg)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(IhsanColor.ground)
        .onDisappear {
            if !closeButtonDismissed {
                Haptics.impact(.light)
            }
        }
    }

    private var metadataHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(gregorianLabel)
                    .font(IhsanFont.title)
                    .foregroundStyle(IhsanColor.textPrimary)
                Text(hijriLabel)
                    .font(IhsanFont.smallCaps)
                    .tracking(0.8)
                    .foregroundStyle(IhsanColor.textMuted)
            }
            Spacer()
            Button("Done") {
                closeButtonDismissed = true
                Haptics.impact(.light)
                dismiss()
            }
                .font(IhsanFont.bodyEnglishBold)
                .foregroundStyle(IhsanColor.textSecondary)
        }
    }

    @ViewBuilder
    private var promptBlock: some View {
        if let prompt = reflection.promptText?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !prompt.isEmpty {
            VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
                Text("PROMPT")
                    .font(IhsanFont.smallCaps)
                    .tracking(1.2)
                    .foregroundStyle(IhsanColor.textMuted)
                Text(prompt)
                    .font(IhsanFont.bodyEnglish)
                    .italic()
                    .foregroundStyle(IhsanColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let citation = reflection.promptCitation?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                   !citation.isEmpty {
                    Text(citation)
                        .font(IhsanFont.citation)
                        .foregroundStyle(IhsanColor.textMuted)
                }
            }
            .padding(IhsanSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(
                    cornerRadius: IhsanSpacing.smallCardRadius,
                    style: .continuous
                )
                .fill(IhsanColor.atmospheric.opacity(0.5))
            }
        }
    }

    @ViewBuilder
    private var bodyText: some View {
        let typed = reflection.typedText?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let transcript = reflection.transcript?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !typed.isEmpty {
            Text(typed)
                .font(IhsanFont.bodyEnglish)
                .foregroundStyle(IhsanColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        if !transcript.isEmpty, transcript != typed {
            VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
                Text("TRANSCRIPT")
                    .font(IhsanFont.smallCaps)
                    .tracking(1.2)
                    .foregroundStyle(IhsanColor.textMuted)
                Text(transcript)
                    .font(IhsanFont.bodyEnglish)
                    .foregroundStyle(IhsanColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var gregorianLabel: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: reflection.createdAt)
    }

    private var hijriLabel: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .islamicUmmAlQura)
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: reflection.createdAt) + " AH"
    }
}
