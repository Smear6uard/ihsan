import SwiftUI
import IhsanDesignSystem

/// The mic affordance. Two visual states:
///
/// - **Idle**: a small mic glyph inside an `.ultraThinMaterial` capsule.
///   Tapping starts recording.
/// - **Recording**: the same capsule with a pulsing muted-gold halo and
///   the elapsed wall-clock time in tabular figures. Tapping stops.
///
/// The pulse is `IhsanColor.recordingPulse` (60% muted gold) — the
/// design system's defined never-red color for recording. Reduce-motion
/// disables the pulse animation but keeps the static halo.
struct ReflectionRecorderControl: View {
    let isRecording: Bool
    let elapsed: TimeInterval
    let onStart: () -> Void
    let onStop: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse: Bool = false

    var body: some View {
        Button(action: { isRecording ? onStop() : onStart() }) {
            HStack(spacing: IhsanSpacing.sm) {
                ZStack {
                    if isRecording {
                        Circle()
                            .fill(IhsanColor.recordingPulse)
                            .frame(width: 32, height: 32)
                            .scaleEffect(reduceMotion ? 1.0 : (pulse ? 1.18 : 0.92))
                            .opacity(reduceMotion ? 0.85 : (pulse ? 1.0 : 0.5))
                            .animation(
                                reduceMotion
                                    ? nil
                                    : .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                                value: pulse
                            )
                    }

                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(IhsanColor.inkDeep)
                        .contentTransition(.symbolEffect(.replace))
                }
                .frame(width: 32, height: 32)

                if isRecording {
                    Text(elapsedLabel)
                        .font(IhsanFont.tabular)
                        .foregroundStyle(IhsanColor.inkDeep)
                        .monospacedDigit()
                        .transition(.opacity)
                } else {
                    Text("RECORD")
                        .font(IhsanFont.inscription)
                        .tracking(1.6)
                        .foregroundStyle(IhsanColor.brassDark)
                }
            }
            .padding(.horizontal, IhsanSpacing.md)
            .padding(.vertical, IhsanSpacing.sm)
            .background {
                Capsule(style: .continuous)
                    .fill(IhsanColor.inkDeep.opacity(0.06))
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(
                                isRecording
                                    ? IhsanColor.recordingPulse
                                    : IhsanColor.brass.opacity(0.40),
                                lineWidth: isRecording ? 1.0 : 0.5
                            )
                    }
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            if isRecording, !reduceMotion {
                pulse = true
            }
        }
        .onChange(of: isRecording) { _, newValue in
            if newValue, !reduceMotion {
                pulse = true
            } else {
                pulse = false
            }
            // Announce the state change so VoiceOver users know the
            // recorder started/stopped — the visual swap of mic→stop
            // alone isn't audible.
            let message = newValue
                ? "Recording started"
                : "Recording stopped"
            AccessibilityNotification.Announcement(message).post()
        }
        .accessibilityLabel(isRecording ? "Stop recording" : "Start voice recording")
        .accessibilityValue(isRecording ? elapsedLabel : "")
        .accessibilityAddTraits(.isButton)
    }

    private var elapsedLabel: String {
        let total = Int(elapsed.rounded())
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview("Recorder control") {
    VStack(spacing: IhsanSpacing.md) {
        ReflectionRecorderControl(
            isRecording: false,
            elapsed: 0,
            onStart: {},
            onStop: {}
        )
        ReflectionRecorderControl(
            isRecording: true,
            elapsed: 14,
            onStart: {},
            onStop: {}
        )
    }
    .padding()
    .ihsanIlluminatedPanel(intensity: .regular)
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .ihsanManuscriptPage()
}
