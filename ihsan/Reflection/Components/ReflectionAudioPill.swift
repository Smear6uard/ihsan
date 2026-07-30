import SwiftUI
import IhsanDesignSystem

/// Glass-styled play/pause control with a thin progress bar and tabular
/// duration. Compact by design — the text content of a reflection is the
/// primary content; the pill is an enhancement.
struct ReflectionAudioPill: View {
    let tokens: SkyPaletteTokens
    let isActive: Bool
    let isPlaying: Bool
    let currentTime: TimeInterval
    let duration: TimeInterval
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: IhsanSpacing.sm) {
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 22, height: 22)
                    .foregroundStyle(tokens.ink)
                    .contentTransition(.symbolEffect(.replace))

                ProgressTrack(progress: progress, tokens: tokens)
                    .frame(height: 2)
                    .frame(minWidth: 80)

                Text(displayedTimeLabel)
                    .font(IhsanFont.tabular)
                    .foregroundStyle(tokens.inkSecondary)
                    .frame(minWidth: 36, alignment: .trailing)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, IhsanSpacing.md)
            .padding(.vertical, IhsanSpacing.sm)
            .background {
                Capsule(style: .continuous)
                    .fill(tokens.ink.opacity(0.06))
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(tokens.panelStroke.opacity(0.8), lineWidth: 0.5)
                    }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(.isButton)
    }

    private var iconName: String {
        isActive && isPlaying ? "pause.fill" : "play.fill"
    }

    private var progress: Double {
        guard duration > 0 else { return 0 }
        let clamped = max(0, min(currentTime, duration))
        return clamped / duration
    }

    private var displayedTimeLabel: String {
        if isActive {
            return formatted(currentTime)
        } else {
            return formatted(duration)
        }
    }

    private func formatted(_ time: TimeInterval) -> String {
        let total = Int(time.rounded())
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var accessibilityLabel: String {
        isActive && isPlaying ? "Pause voice memo" : "Play voice memo"
    }

    /// VoiceOver value: while playing, expose the current position so
    /// users can scrub mentally; otherwise just the duration.
    private var accessibilityValue: String {
        if isActive && duration > 0 {
            return "\(formatted(currentTime)) of \(formatted(duration))"
        }
        return "\(formatted(duration)) recording"
    }
}

private struct ProgressTrack: View {
    let progress: Double
    let tokens: SkyPaletteTokens

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(tokens.metal.opacity(0.30))
                Capsule()
                    .fill(tokens.metal)
                    .frame(width: max(0, geo.size.width * progress))
                    .animation(.linear(duration: 0.12), value: progress)
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview("Audio pill") {
    VStack(spacing: IhsanSpacing.md) {
        ReflectionAudioPill(
            tokens: PaletteState.afternoon.tokens,
            isActive: false,
            isPlaying: false,
            currentTime: 0,
            duration: 42,
            onToggle: {}
        )
        ReflectionAudioPill(
            tokens: PaletteState.afternoon.tokens,
            isActive: true,
            isPlaying: true,
            currentTime: 18,
            duration: 42,
            onToggle: {}
        )
    }
    .padding()
    .ihsanIlluminatedPanel(intensity: .regular)
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .ihsanManuscriptPage()
}
