import SwiftUI
import IhsanDesignSystem

struct SuhoorIftarBanner: View {
    let suhoorEnd: Date

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, suhoorEnd.timeIntervalSince(context.date))

            if remaining > 0 {
                let now = context.date
                let foreground = IhsanColor.cardForegroundPrimary(at: now)
                let foregroundSecondary = IhsanColor.cardForegroundSecondary(at: now)
                let accent = IhsanColor.accentWarm(at: now)

                HStack(spacing: IhsanSpacing.md) {
                    VStack(alignment: .leading, spacing: IhsanSpacing.xs) {
                        Text("Suhoor ends in")
                            .font(IhsanFont.smallCaps)
                            .foregroundStyle(foregroundSecondary)

                        Text(formatted(seconds: remaining))
                            .font(.system(size: 30, weight: .light, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(foreground)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .contentTransition(.numericText())
                            .animation(reduceMotion ? nil : .snappy(duration: 0.25),
                                       value: remaining)
                    }

                    Spacer(minLength: IhsanSpacing.md)

                    Text("Fajr")
                        .font(IhsanFont.smallCaps)
                        .foregroundStyle(foreground.opacity(0.88))
                        .padding(.horizontal, IhsanSpacing.sm + 2)
                        .padding(.vertical, IhsanSpacing.xs + 2)
                        .background {
                            Capsule()
                                .fill(accent.opacity(0.18))
                                .overlay {
                                    Capsule()
                                        .strokeBorder(accent.opacity(0.55), lineWidth: 0.6)
                                }
                        }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, IhsanSpacing.md)
                .padding(.horizontal, IhsanSpacing.md)
                .ihsanWarmCardHero()
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(spokenCountdown(seconds: remaining)) until suhoor ends at Fajr")
            }
        }
    }

    private func formatted(seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "−%02d:%02d:%02d", h, m, s)
    }

    /// Human-readable form for VoiceOver — "−02:34:15" otherwise reads
    /// as "minus zero two colon..."
    private func spokenCountdown(seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        var parts: [String] = []
        if h > 0 { parts.append("\(h) hour\(h == 1 ? "" : "s")") }
        if m > 0 { parts.append("\(m) minute\(m == 1 ? "" : "s")") }
        if h == 0 { parts.append("\(s) second\(s == 1 ? "" : "s")") }
        return parts.isEmpty ? "0 seconds" : parts.joined(separator: ", ")
    }
}
