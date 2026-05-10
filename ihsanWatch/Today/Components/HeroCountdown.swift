import SwiftUI
import IhsanCore
import IhsanDesignSystem

/// Watch-tuned hero countdown. Reuses the iOS layout vocabulary —
/// prayer name above, monospaced tabular figures, lowercase smallcaps
/// caption — but at watchOS-appropriate sizes (~32pt countdown vs
/// 64pt on iOS). Minute-granularity ticks: a 1Hz timeline drains the
/// watch battery, and the user reads `Asr 1h 23m`, not seconds.
struct HeroCountdown: View {
    let targetPrayer: Prayer
    let targetTime: Date

    var body: some View {
        TimelineView(.everyMinute) { context in
            let remaining = max(0, targetTime.timeIntervalSince(context.date))
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Text(targetPrayer.displayNameEnglish)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(IhsanColor.textPrimary)
                    Text(targetPrayer.displayNameArabic)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(IhsanColor.textSecondary)
                }

                Text(Self.formatted(seconds: remaining))
                    .font(.system(size: 32, weight: .thin, design: .rounded).monospacedDigit())
                    .foregroundStyle(IhsanColor.textPrimary)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Self.accessibilityLabel(prayer: targetPrayer, seconds: remaining))
        }
    }

    static func formatted(seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        // Round minutes UP so "57s remaining" reads as "1m" rather
        // than "0m" — at minute granularity, the user still expects
        // the display to confirm there's a moment left.
        let m = max(0, (total - h * 3600 + 59) / 60)
        if h > 0 {
            return String(format: "%dh %02dm", h, m)
        }
        if total > 0 {
            return String(format: "%dm", max(1, m))
        }
        return "now"
    }

    static func accessibilityLabel(prayer: Prayer, seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        var parts: [String] = []
        if h > 0 { parts.append("\(h) hour\(h == 1 ? "" : "s")") }
        if m > 0 { parts.append("\(m) minute\(m == 1 ? "" : "s")") }
        if parts.isEmpty { parts.append("less than a minute") }
        return "\(parts.joined(separator: " ")) until \(prayer.displayNameEnglish)"
    }
}
