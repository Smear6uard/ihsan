import AVFoundation
import SwiftUI
import IhsanCore
import IhsanDesignSystem

/// A glass card representing one past reflection in the feed.
///
/// Shape rules:
///   - Text-only: shows `typedText` truncated to 3 lines.
///   - Voice-only: shows the audio pill above the transcript snippet.
///   - Mixed: text on top, audio pill below.
/// An optional `aiSummaryTitle` (italic) sits above the body when present.
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

                if let title = reflection.aiSummaryTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !title.isEmpty {
                    Text(title)
                        .font(IhsanFont.bodyEnglishBold)
                        .italic()
                        .foregroundStyle(IhsanColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                body(for: shape)

                if let promptText = reflection.promptText?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                   !promptText.isEmpty {
                    promptCaption(promptText)
                }
            }
            .padding(IhsanSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .ihsanGlass(intensity: .regular)
        }
        .buttonStyle(.plain)
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
                .foregroundStyle(IhsanColor.textPrimary)
                .lineLimit(3)
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
                        .foregroundStyle(IhsanColor.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

        case let .mixed(text, audio, _):
            VStack(alignment: .leading, spacing: IhsanSpacing.md) {
                Text(text)
                    .font(IhsanFont.bodyEnglish)
                    .foregroundStyle(IhsanColor.textPrimary)
                    .lineLimit(3)
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
                        .foregroundStyle(IhsanColor.textPrimary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("VOICE MEMO UNAVAILABLE ON THIS DEVICE")
                    .font(IhsanFont.smallCaps)
                    .tracking(0.8)
                    .foregroundStyle(IhsanColor.textMuted)
            }

        case .unknown:
            Text("(empty reflection)")
                .font(IhsanFont.bodyEnglish)
                .foregroundStyle(IhsanColor.textMuted)
        }
    }

    // MARK: - Metadata

    private var metadata: some View {
        HStack(spacing: IhsanSpacing.sm) {
            Text(gregorianLabel)
                .font(IhsanFont.smallCaps)
                .tracking(1.0)
                .foregroundStyle(IhsanColor.textSecondary)
            Text("·")
                .font(IhsanFont.smallCaps)
                .foregroundStyle(IhsanColor.textMuted)
            Text(hijriLabel)
                .font(IhsanFont.smallCaps)
                .tracking(1.0)
                .foregroundStyle(IhsanColor.textMuted)
        }
        .accessibilityElement(children: .combine)
    }

    private var gregorianLabel: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMM d"
        return formatter.string(from: reflection.createdAt).uppercased()
    }

    private var hijriLabel: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .islamicUmmAlQura)
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "d MMM yyyy"
        return "\(formatter.string(from: reflection.createdAt)) AH".uppercased()
    }

    // MARK: - Prompt caption

    private func promptCaption(_ promptText: String) -> some View {
        Text(promptText)
            .font(IhsanFont.smallCaps)
            .tracking(0.8)
            .foregroundStyle(IhsanColor.textMuted)
            .lineLimit(2)
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
