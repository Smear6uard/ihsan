import SwiftUI

/// Per-prayer adhan-sound toggle. When the speaker is filled the
/// scheduled notification plays the configured adhan recording; when
/// slashed it falls back to the system default tone. This is the
/// "mute the call to prayer for this prayer" control — not a global
/// notifications switch.
///
/// Sized to match `JamaahToggle` so the row balances visually with two
/// adjacent square chips.
public struct AdhanMuteToggle: View {
    @Binding public var adhanEnabled: Bool
    public var onToggle: (() -> Void)?
    public var accessibilityPrayerName: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        adhanEnabled: Binding<Bool>,
        accessibilityPrayerName: String,
        onToggle: (() -> Void)? = nil
    ) {
        self._adhanEnabled = adhanEnabled
        self.accessibilityPrayerName = accessibilityPrayerName
        self.onToggle = onToggle
    }

    public var body: some View {
        Button {
            if !reduceMotion {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                    adhanEnabled.toggle()
                }
            } else {
                adhanEnabled.toggle()
            }
            onToggle?()
        } label: {
            Image(systemName: adhanEnabled
                  ? "speaker.wave.2.fill"
                  : "speaker.slash.fill")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(
                    adhanEnabled ? IhsanColor.textSecondary : IhsanColor.textMuted
                )
                .frame(width: 32, height: 32)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(adhanEnabled ? 1.0 : 0.4)
                }
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(adhanEnabled
                            ? "\(accessibilityPrayerName) adhan on"
                            : "\(accessibilityPrayerName) adhan muted")
        .accessibilityValue(adhanEnabled ? "On" : "Muted")
        .accessibilityHint("Toggles whether the call to prayer recording plays for \(accessibilityPrayerName)")
        .accessibilityAddTraits(.isButton)
    }
}

private struct AdhanMuteTogglePreviewWrapper: View {
    @State private var enabled = true

    var body: some View {
        VStack(spacing: IhsanSpacing.lg) {
            AdhanMuteToggle(
                adhanEnabled: $enabled,
                accessibilityPrayerName: "Fajr"
            )
            Text(enabled ? "Adhan plays" : "Default tone")
                .font(IhsanFont.smallCaps)
                .foregroundStyle(IhsanColor.textMuted)
        }
    }
}

#Preview("Adhan mute toggle") {
    AdhanMuteTogglePreviewWrapper()
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ihsanBackground()
}
