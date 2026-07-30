import SwiftUI
import IhsanCore
import IhsanDesignSystem

/// Expanded view of a single past reflection — shown in a sheet when the
/// user taps a feed card. Reads as one open manuscript page: gregorian
/// date in refined serif at top-left, Hijri date inscription at
/// top-right, the prompt nested in an illuminated panel, then the body
/// text rendered in comfortable sans below.
///
/// Sheet container uses the system's Liquid Glass via
/// `.presentationBackground(.thinMaterial)`; content sits on top as
/// page-level typography and illuminated panels — the same hybrid
/// hierarchy used by the prayer log sheet and the day popover.
struct ReflectionDetailSheet: View {
    let tokens: SkyPaletteTokens
    let reflection: Reflection
    let isPlaybackActive: Bool
    let isPlaybackPlaying: Bool
    let playbackCurrentTime: TimeInterval
    let onTogglePlayback: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var closeButtonDismissed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: IhsanSpacing.lg) {
                metadataHeader

                OrnamentalDivider(tint: tokens.metal, opacity: 0.5)
                    .padding(.bottom, IhsanSpacing.xs)

                promptBlock

                if let title = reflection.aiSummaryTitle?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                   !title.isEmpty {
                    Text(title)
                        .font(.system(size: 22, weight: .medium, design: .serif).italic())
                        .foregroundStyle(tokens.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let memoID = reflection.voiceMemoID,
                   let url = ReflectionAudioPaths.existingFileURL(for: memoID) {
                    ReflectionAudioPill(
                        tokens: tokens,
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
            .padding(.top, IhsanSpacing.md)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.thinMaterial)
        .onDisappear {
            if !closeButtonDismissed {
                Haptics.impact(.light)
            }
        }
    }

    private var metadataHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(gregorianLabel)
                    .font(.system(.title2, weight: .medium))
                    .foregroundStyle(tokens.ink)
                Text(hijriLabel)
                    .font(IhsanFont.inscription)
                    .tracking(1.8)
                    .foregroundStyle(tokens.inkSecondary)
            }
            Spacer()
            Button {
                closeButtonDismissed = true
                Haptics.impact(.light)
                dismiss()
            } label: {
                Text("DONE")
                    .font(IhsanFont.inscription)
                    .tracking(1.8)
                    .foregroundStyle(tokens.inkSecondary)
                    .padding(.horizontal, IhsanSpacing.sm)
                    .padding(.vertical, IhsanSpacing.xs)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var promptBlock: some View {
        if let prompt = reflection.promptText?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !prompt.isEmpty {
            VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
                Text("PROMPT")
                    .font(IhsanFont.inscription)
                    .tracking(1.8)
                    .foregroundStyle(tokens.inkSecondary)
                Text("— \(prompt)")
                    .font(.system(size: 17, weight: .regular, design: .serif).italic())
                    .foregroundStyle(tokens.ink.opacity(0.9))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                if let citation = reflection.promptCitation?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                   !citation.isEmpty {
                    Text(citation)
                        .font(IhsanFont.citation)
                        .foregroundStyle(tokens.inkSecondary.opacity(0.9))
                }
            }
            .padding(IhsanSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .ihsanIlluminatedPanel(intensity: .regular)
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
                .foregroundStyle(tokens.ink)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        if !transcript.isEmpty, transcript != typed {
            VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
                Text("TRANSCRIPT")
                    .font(IhsanFont.inscription)
                    .tracking(1.8)
                    .foregroundStyle(tokens.inkSecondary)
                Text(transcript)
                    .font(IhsanFont.bodyEnglish)
                    .foregroundStyle(tokens.inkSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var gregorianLabel: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: reflection.createdAt)
    }

    private var hijriLabel: String {
        HijriDateFormatter.string(from: reflection.createdAt).uppercased()
    }
}
