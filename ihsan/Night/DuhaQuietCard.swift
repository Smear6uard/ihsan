import IhsanCore
import IhsanDesignSystem
import IhsanPrayerTimes
import SwiftUI

/// The duha invitation: a small quiet card beneath the focused card,
/// present only while the forenoon window is open. It names the window
/// and takes one tap — no countdown, no urgency, nothing owed.
struct DuhaQuietCard: View {
    let window: DuhaWindow
    let isLogged: Bool
    let timeZone: TimeZone
    let onToggle: () -> Void

    var body: some View {
        Button {
            Haptics.impact(.soft)
            onToggle()
        } label: {
            HStack(spacing: IhsanSpacing.sm) {
                ZStack {
                    if isLogged {
                        PrayerOrnamentShape(prayer: .dhuhr, mode: .filled)
                            .fill(
                                IhsanCelestialPalette.current().accent,
                                style: FillStyle(eoFill: true)
                            )
                    } else {
                        PrayerOrnamentShape(prayer: .dhuhr, mode: .outline)
                            .stroke(
                                IhsanCelestialPalette.current().accent.opacity(0.55),
                                lineWidth: 0.9
                            )
                    }
                }
                .frame(width: 16, height: 16)

                Text("Duha")
                    .font(IhsanFont.bodyEnglish)
                    .foregroundStyle(IhsanCelestialPalette.current().text)

                Spacer(minLength: 0)

                Text(windowText)
                    .font(IhsanFont.inscription)
                    .tracking(1.2)
                    .foregroundStyle(IhsanCelestialPalette.current().accent.opacity(0.65))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .celestialPanel(cornerRadius: 16, isActive: false)
        .padding(.horizontal, IhsanSpacing.md)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Duha, window \(windowText)")
        .accessibilityValue(isLogged ? "recorded" : "not recorded")
        .accessibilityHint("Double-tap to \(isLogged ? "remove" : "record").")
    }

    private var windowText: String {
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.timeZone = timeZone
        return "\(window.start.formatted(style)) – \(window.end.formatted(style))"
    }
}
