import SwiftUI

/// The time-adaptive sky background for the celestial scene.
///
/// Renders a vertical gradient that crossfades between the night palette
/// (`nightSkyDeep` top → `nightSky` bottom) and the day palette
/// (`daySky` top → `daySkyDeep` bottom) across two transition windows
/// centred on sunrise (~06:30) and sunset (~18:30). The transition is
/// smoothed by a cubic Hermite easing curve so the sky drifts through
/// dawn / dusk over ~60 minutes without the eye reading the crossover
/// as a hard cut.
///
/// Phase 3 uses fixed clock-time anchors (06:30 / 18:30); a later phase
/// will wire real sun-altitude resolution so the sky truly tracks the
/// computed solar position. The structural mechanics — crossfade,
/// transition window, star-opacity coupling — are unchanged by that
/// future refinement.
public struct SkyGradient: View {
    @Environment(\.timeOfDayOverride) private var override
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public var body: some View {
        if let override {
            gradient(at: override)
        } else if reduceMotion {
            gradient(at: .now)
        } else {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                gradient(at: context.date)
            }
        }
    }

    @ViewBuilder
    private func gradient(at date: Date) -> some View {
        let state = SkyState.current(at: date)
        LinearGradient(
            colors: [state.topColor, state.bottomColor],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// The visual state of the sky at a given moment — the two gradient
/// stops plus the star-field opacity. `internal` so `StarField` and
/// tests can consult the same computation rather than threading the
/// values across view boundaries.
struct SkyState: Sendable, Equatable {
    let topColor: Color
    let bottomColor: Color
    /// 0.0 at full day, 1.0 at deep night. Drives the star-field
    /// opacity so stars fade in as the sky transitions to night and
    /// fade out as it transitions back to day.
    let starOpacity: Double

    static func current(at date: Date) -> SkyState {
        let fraction = dayFraction(at: date)
        let night = IhsanCelestialPalette.night
        let day = IhsanCelestialPalette.day

        // Top: night.skyDeep at deep night, day.sky at full day.
        // Bottom: night.sky at deep night, day.skyDeep at full day.
        let top = blend(night.skyDeep, day.sky, fraction: fraction)
        let bottom = blend(night.sky, day.skyDeep, fraction: fraction)

        // Stars: opposite to the day fraction. At 50% day (sunrise /
        // sunset moment) the stars are at ~50% opacity, which crossfades
        // them through dawn and dusk rather than snapping them off at a
        // single hour.
        let starOpacity = 1.0 - fraction

        return SkyState(
            topColor: top,
            bottomColor: bottom,
            starOpacity: starOpacity
        )
    }

    /// Phase 3 clock-time crossfade between night and day. Returns `0`
    /// at deep night (e.g. midnight) and `1` at full day (e.g. noon).
    /// The dawn transition is centred on 06:30 and the dusk transition
    /// on 18:30, each spanning 60 minutes total. Outside those windows
    /// the value is exactly `0` or `1` so the night palette and the
    /// day palette stay pure at their respective hours.
    ///
    /// `internal` so tests can pin the crossover points directly.
    static func dayFraction(at date: Date) -> Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        let hour = Double(components.hour ?? 0)
            + Double(components.minute ?? 0) / 60.0
            + Double(components.second ?? 0) / 3600.0

        let sunrise: Double = 6.5
        let sunset: Double = 18.5
        let halfWindow: Double = 0.5 // 30 minutes either side of anchor

        if hour <= sunrise - halfWindow || hour >= sunset + halfWindow {
            return 0.0
        }
        if hour >= sunrise + halfWindow && hour <= sunset - halfWindow {
            return 1.0
        }
        if hour < sunrise + halfWindow {
            // Dawn transition: 06:00–07:00.
            let t = (hour - (sunrise - halfWindow)) / (2 * halfWindow)
            return smoothstep(t)
        }
        // Dusk transition: 18:00–19:00.
        let t = (sunset + halfWindow - hour) / (2 * halfWindow)
        return smoothstep(t)
    }

    /// Cubic Hermite easing — `3t² − 2t³` over `[0, 1]`. Smoothly
    /// rounds the crossover so the sky never reads as having a hard
    /// transition.
    static func smoothstep(_ t: Double) -> Double {
        let clamped = max(0.0, min(1.0, t))
        return clamped * clamped * (3.0 - 2.0 * clamped)
    }

    /// Per-channel linear interpolation between two `Color` values
    /// resolved through their sRGB components.
    ///
    /// SwiftUI's `Color.interpolate` is opaque; sampling resolved
    /// components manually keeps the crossfade deterministic and
    /// testable. The colour space is sRGB — adequate for visual
    /// gradient work; perceptual (Oklab/Lab) blending isn't worth the
    /// complexity at this scale.
    static func blend(_ a: Color, _ b: Color, fraction: Double) -> Color {
        let t = max(0.0, min(1.0, fraction))
        let aResolved = a.resolve(in: .init())
        let bResolved = b.resolve(in: .init())
        let r = Float(1 - t) * aResolved.linearRed   + Float(t) * bResolved.linearRed
        let g = Float(1 - t) * aResolved.linearGreen + Float(t) * bResolved.linearGreen
        let bl = Float(1 - t) * aResolved.linearBlue + Float(t) * bResolved.linearBlue
        return Color(.sRGBLinear, red: Double(r), green: Double(g), blue: Double(bl), opacity: 1)
    }
}

#Preview("Sky gradient — across the day") {
    VStack(spacing: 0) {
        ForEach([2, 6, 7, 9, 12, 15, 18, 19, 22], id: \.self) { hour in
            ZStack {
                SkyGradient()
                    .environment(\.timeOfDayOverride, dateAt(hour: hour, minute: 0))
                Text("\(hour):00")
                    .font(.system(size: 11, weight: .semibold).smallCaps())
                    .tracking(1.1)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(6)
                    .background(.black.opacity(0.3), in: Capsule())
            }
        }
    }
    .ignoresSafeArea()
}

private func dateAt(hour: Int, minute: Int) -> Date {
    var components = DateComponents()
    components.year = 2026
    components.month = 5
    components.day = 15
    components.hour = hour
    components.minute = minute
    return Calendar.current.date(from: components) ?? .now
}
