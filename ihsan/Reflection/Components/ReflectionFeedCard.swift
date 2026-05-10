import AVFoundation
import SwiftUI
import IhsanCore
import IhsanDesignSystem

/// An illuminated parchment panel representing one past reflection in the
/// feed. The visual hierarchy follows the manuscript-redirect mockup:
///
/// - Top row: gregorian date (refined serif) at left, Hijri date in
///   small caps at right.
/// - Italic prompt (refined serif italic) prefixed with an em-dash —
///   reads as a marginal note.
/// - Body: typed reflection text in system sans for comfortable reading.
/// - If a voice memo is attached, an audio pill sits beneath the body.
///
/// Each card is its own tappable panel that opens the detail sheet.
struct ReflectionFeedCard: View {
    let reflection: Reflection
    let isPlaybackActive: Bool
    let isPlaybackPlaying: Bool
    let playbackCurrentTime: TimeInterval
    let onTogglePlayback: () -> Void
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: IhsanSpacing.md) {
                metadata

                if let prompt = displayPrompt {
                    promptLine(prompt)
                }

                body(for: shape)
            }
            .padding(IhsanSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .ihsanIlluminatedPanel(intensity: .regular)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Tap to read the full reflection")
    }

    // MARK: - Shape

    private enum Shape {
        case textOnly(String)
        case voiceOnly(audio: AudioPresentation, transcript: String?)
        case mixed(text: String, audio: AudioPresentation, transcript: String?)
        case voiceMissing(transcript: String?)
        case unknown
    }

    private struct AudioPresentation {
        let memoID: UUID
        let url: URL
        let duration: TimeInterval
    }

    private var shape: Shape {
        let typedText = reflection.typedText?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let transcript = reflection.transcript?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let memoID = reflection.voiceMemoID {
            if let url = ReflectionAudioPaths.existingFileURL(for: memoID) {
                let audio = AudioPresentation(
                    memoID: memoID,
                    url: url,
                    duration: AudioFileDurationCache.shared.duration(for: url)
                )
                if let typed = typedText, !typed.isEmpty {
                    return .mixed(text: typed, audio: audio, transcript: transcript)
                }
                return .voiceOnly(audio: audio, transcript: transcript)
            } else {
                return .voiceMissing(transcript: transcript)
            }
        }

        if let typed = typedText, !typed.isEmpty {
            return .textOnly(typed)
        }
        if let transcript, !transcript.isEmpty {
            return .textOnly(transcript)
        }
        return .unknown
    }

    @ViewBuilder
    private func body(for shape: Shape) -> some View {
        switch shape {
        case .textOnly(let text):
            Text(text)
                .font(IhsanFont.bodyEnglish)
                .foregroundStyle(IhsanColor.inkDeep)
                .lineSpacing(3)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)

        case let .voiceOnly(audio, transcript):
            VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
                ReflectionAudioPill(
                    isActive: isPlaybackActive,
                    isPlaying: isPlaybackPlaying,
                    currentTime: playbackCurrentTime,
                    duration: audio.duration,
                    onToggle: onTogglePlayback
                )
                if let snippet = transcript, !snippet.isEmpty {
                    Text(snippet)
                        .font(IhsanFont.bodyEnglish)
                        .foregroundStyle(IhsanColor.inkDeep.opacity(0.78))
                        .lineSpacing(3)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

        case let .mixed(text, audio, _):
            VStack(alignment: .leading, spacing: IhsanSpacing.md) {
                Text(text)
                    .font(IhsanFont.bodyEnglish)
                    .foregroundStyle(IhsanColor.inkDeep)
                    .lineSpacing(3)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                ReflectionAudioPill(
                    isActive: isPlaybackActive,
                    isPlaying: isPlaybackPlaying,
                    currentTime: playbackCurrentTime,
                    duration: audio.duration,
                    onToggle: onTogglePlayback
                )
            }

        case .voiceMissing(let transcript):
            VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
                if let transcript, !transcript.isEmpty {
                    Text(transcript)
                        .font(IhsanFont.bodyEnglish)
                        .foregroundStyle(IhsanColor.inkDeep)
                        .lineSpacing(3)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("VOICE MEMO UNAVAILABLE ON THIS DEVICE")
                    .font(IhsanFont.inscription)
                    .tracking(1.4)
                    .foregroundStyle(IhsanColor.brassDark.opacity(0.75))
            }

        case .unknown:
            Text("(empty reflection)")
                .font(IhsanFont.bodyEnglish)
                .foregroundStyle(IhsanColor.inkDeep.opacity(0.55))
        }
    }

    // MARK: - Metadata

    private var metadata: some View {
        HStack(alignment: .firstTextBaseline, spacing: IhsanSpacing.sm) {
            Text(gregorianLabel)
                .font(.system(size: 20, weight: .medium, design: .serif))
                .foregroundStyle(IhsanColor.inkDeep)
            Spacer(minLength: IhsanSpacing.sm)
            Text(hijriLabel)
                .font(IhsanFont.inscription)
                .tracking(1.4)
                .foregroundStyle(IhsanColor.brassDark)
        }
        .accessibilityElement(children: .combine)
    }

    private var gregorianLabel: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: reflection.createdAt)
    }

    private var hijriLabel: String {
        HijriDateFormatter.string(from: reflection.createdAt).uppercased()
    }

    // MARK: - Prompt line

    /// Either the AI-generated summary title (preferred — it's a per-
    /// entry headline) or the raw prompt text, prefixed with an em-dash
    /// so the line reads as a marginal annotation.
    private var displayPrompt: String? {
        if let title = reflection.aiSummaryTitle?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !title.isEmpty {
            return title
        }
        if let prompt = reflection.promptText?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !prompt.isEmpty {
            return prompt
        }
        return nil
    }

    private func promptLine(_ text: String) -> some View {
        Text("— \(text)")
            .font(.system(size: 16, weight: .regular, design: .serif).italic())
            .foregroundStyle(IhsanColor.inkDeep.opacity(0.78))
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        var parts: [String] = []
        parts.append("Reflection from \(gregorianLabel)")
        if let title = reflection.aiSummaryTitle, !title.isEmpty {
            parts.append(title)
        }
        if let typed = reflection.typedText?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !typed.isEmpty {
            parts.append(typed)
        } else if let transcript = reflection.transcript {
            parts.append(transcript)
        }
        if reflection.voiceMemoID != nil {
            parts.append("Includes a voice recording.")
        }
        return parts.joined(separator: ". ")
    }
}

/// Caches durations of audio files so feed cards don't have to construct
/// an `AVAudioPlayer` per render. The duration is read once per file path
/// and held in a small in-memory map. Strict-concurrency safe via
/// `@MainActor` isolation — the cache is only read/written on the main
/// actor where the views render.
@MainActor
final class AudioFileDurationCache {
    static let shared = AudioFileDurationCache()
    private init() {}

    private var cache: [String: TimeInterval] = [:]

    func duration(for url: URL) -> TimeInterval {
        let key = url.path
        if let cached = cache[key] { return cached }
        // AVAudioPlayer.duration reads from the file header synchronously
        // and is not deprecated, unlike AVURLAsset.duration. Files are
        // local and tiny — single-digit milliseconds per first-paint —
        // so a synchronous read here is acceptable. The cache means we
        // pay the cost once per file lifetime.
        let durationSeconds: TimeInterval
        if let probe = try? AVAudioPlayer(contentsOf: url) {
            durationSeconds = probe.duration
        } else {
            durationSeconds = 0
        }
        cache[key] = durationSeconds
        return durationSeconds
    }
}
