import SwiftUI
import IhsanDesignSystem
import IhsanPrayerTimes

/// Photographic ground that fades in within ±15 min of sunrise and ±10 min of
/// maghrib. Outside those windows the view contributes nothing visually so the
/// dark `IhsanColor.ground` shows through.
struct DaylightWallpaper: View {
    let dayTimes: DayPrayerTimes

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Reduce Motion suppresses the cross-fade BETWEEN ticks but still
        // re-evaluates the wallpaper opacity every 30 s — otherwise the
        // wallpaper would freeze at the first-render time and miss the
        // sunrise/maghrib window entirely if Reduce Motion was on at
        // launch. The visible motion saved is the 1.0 s easeInOut fade,
        // not the act of updating itself.
        TimelineView(.periodic(from: .now, by: 30)) { context in
            wallpaper(at: context.date)
                .animation(reduceMotion ? nil : .easeInOut(duration: 1.0),
                           value: context.date)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func wallpaper(at date: Date) -> some View {
        ZStack {
            if let opacity = sunriseOpacity(at: date) {
                Image("daylight-sunrise")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .opacity(opacity)
            }
            if let opacity = maghribOpacity(at: date) {
                Image("daylight-maghrib")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .opacity(opacity)
            }
        }
    }

    private func sunriseOpacity(at date: Date) -> Double? {
        triangularOpacity(at: date, center: dayTimes.sunrise, halfWidthSeconds: 15 * 60)
    }

    private func maghribOpacity(at date: Date) -> Double? {
        triangularOpacity(at: date, center: dayTimes.maghrib.scheduledTime, halfWidthSeconds: 10 * 60)
    }

    /// Linear ramp 0→1→0 across `[center − halfWidth, center + halfWidth]`.
    /// Returns `nil` outside the window so the layer can be skipped entirely.
    private func triangularOpacity(at date: Date, center: Date, halfWidthSeconds: TimeInterval) -> Double? {
        let delta = abs(date.timeIntervalSince(center))
        guard delta < halfWidthSeconds else { return nil }
        return max(0, min(1, 1 - delta / halfWidthSeconds))
    }
}
