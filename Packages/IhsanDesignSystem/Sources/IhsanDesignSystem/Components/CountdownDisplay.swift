import SwiftUI
import IhsanCore

/// Hero countdown for the Today screen.
///
/// Driven by `TimelineView(.periodic)` so it ticks once per second without
/// forcing the rest of the view tree to re-render. The remaining seconds
/// formatter shows `−HH:MM:SS` (with a thin minus sign) so the display is
/// counting *down* to the prayer rather than displaying an elapsed time.
public struct CountdownDisplay: View {
    public let targetPrayer: Prayer
    public let targetTime: Date

    public init(targetPrayer: Prayer, targetTime: Date) {
        self.targetPrayer = targetPrayer
        self.targetTime = targetTime
    }

    public var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, targetTime.timeIntervalSince(context.date))
            VStack(spacing: IhsanSpacing.sm) {
                HStack(spacing: IhsanSpacing.sm) {
                    Text(targetPrayer.displayNameEnglish)
                        .font(IhsanFont.subtitle)
                        .foregroundStyle(IhsanColor.textPrimary)
                    Text(targetPrayer.displayNameArabic)
                        .font(IhsanFont.bodyArabic)
                        .foregroundStyle(IhsanColor.textSecondary)
                }

                Text(Self.formatted(seconds: remaining))
                    .font(IhsanFont.heroCountdown)
                    .foregroundStyle(IhsanColor.textPrimary)
                    .contentTransition(.numericText())

                Text("until \(targetPrayer.displayNameEnglish.lowercased())")
                    .font(IhsanFont.smallCaps)
                    .foregroundStyle(IhsanColor.textMuted)
            }
            .padding(.vertical, IhsanSpacing.lg)
            .frame(maxWidth: .infinity)
            .ihsanGlassHero()
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Self.accessibilityLabel(
                prayer: targetPrayer,
                seconds: remaining
            ))
        }
    }

    static func formatted(seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        // U+2212 MINUS SIGN — typographic minus, visually balanced at hero size.
        return String(format: "\u{2212}%02d:%02d:%02d", h, m, s)
    }

    static func accessibilityLabel(prayer: Prayer, seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        var parts: [String] = []
        if h > 0 { parts.append("\(h) hour\(h == 1 ? "" : "s")") }
        if m > 0 { parts.append("\(m) minute\(m == 1 ? "" : "s")") }
        if parts.isEmpty { parts.append("less than a minute") }
        let timeStr = parts.joined(separator: " ")
        return "\(timeStr) until \(prayer.displayNameEnglish)"
    }
}

#Preview("Countdown display") {
    CountdownDisplay(
        targetPrayer: .maghrib,
        targetTime: .now.addingTimeInterval(7_200)
    )
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .ihsanBackground()
}
