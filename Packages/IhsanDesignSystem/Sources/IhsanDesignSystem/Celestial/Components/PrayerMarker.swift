import IhsanCore
import SwiftUI

/// A single prayer time marker on the celestial scene.
///
/// Each of the five fardh prayers gets its own ornament shape — drawn
/// natively in SwiftUI `Path` and routed through `PrayerOrnamentView`:
///
/// - **Fajr** — a half-sun + three rising rays.
/// - **Dhuhr** — an eight-pointed star.
/// - **Asr** — a six-pointed star.
/// - **Maghrib** — a half-sun + three descending rays.
/// - **Isha** — a crescent with a small star in its opening.
///
/// Visual states applied on top of the shape:
///
/// - `.future` (above horizon): outlined ornament at 60% opacity.
/// - `.past` (above horizon): filled ornament at 80% opacity.
/// - `.current` (above horizon): the ornament scaled up to ~24pt and
///   filled with the iridescent brass angular gradient; a soft radial
///   halo underneath pulses gently in a 4-second cycle (static under
///   Reduce Motion). The brightest element on the scene besides the
///   sun / moon ornaments themselves.
/// - Below horizon: filled ornament at 50% opacity regardless of
///   state. The subterranean region is where the user's eye finds
///   prayers whose sun is currently below the horizon (Fajr before
///   sunrise, Maghrib and Isha after sunset).
///
/// The marker positions itself at the **sun's position at the prayer's
/// scheduled time** — that's the CelestialScene's job, not
/// PrayerMarker's. This view renders the ornament + small-caps prayer
/// label as a vertical group; the caller positions the group via
/// `.position(_)`.
public struct PrayerMarker: View {

    public enum State: Sendable, Equatable {
        /// Prayer scheduled time is in the future.
        case future
        /// Prayer scheduled time is in the past.
        case past
        /// Prayer is the next upcoming or currently in its window.
        case current
    }

    public let prayer: Prayer
    public let state: State
    public let aboveHorizon: Bool

    @Environment(\.timeOfDayOverride) private var override
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(prayer: Prayer, state: State, aboveHorizon: Bool = true) {
        self.prayer = prayer
        self.state = state
        self.aboveHorizon = aboveHorizon
    }

    public var body: some View {
        let date = override ?? .now
        let palette = IhsanCelestialPalette.current(at: date)
        let labelOpacity = aboveHorizon ? 0.70 : 0.50

        VStack(spacing: 6) {
            marker(palette: palette)
            Text(prayer.displayNameEnglish.uppercased())
                .font(.system(size: 9, weight: .semibold).smallCaps())
                .tracking(0.5)
                .foregroundStyle(palette.accent.opacity(labelOpacity))
                .fixedSize()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        let name = prayer.displayNameEnglish
        if !aboveHorizon {
            return "\(name), below horizon"
        }
        switch state {
        case .future:  return "\(name), upcoming"
        case .past:    return "\(name), past"
        case .current: return "\(name), next prayer"
        }
    }

    // MARK: - Marker dispatch

    @ViewBuilder
    private func marker(palette: IhsanCelestialPalette) -> some View {
        if !aboveHorizon {
            PrayerOrnamentView(
                prayer: prayer,
                size: 14,
                style: .filled(palette.accent, opacity: 0.50)
            )
        } else {
            switch state {
            case .future:
                PrayerOrnamentView(
                    prayer: prayer,
                    size: 14,
                    style: .stroked(palette.accent, opacity: 0.60, lineWidth: 0.8)
                )
            case .past:
                PrayerOrnamentView(
                    prayer: prayer,
                    size: 14,
                    style: .filled(palette.accent, opacity: 0.80)
                )
            case .current:
                currentMarker(palette: palette)
            }
        }
    }

    // MARK: - Current marker (active prayer)

    /// The active prayer's ornament — scaled up, filled with the
    /// iridescent angular gradient, and sitting on a softly pulsing
    /// halo. Under Reduce Motion the halo is static at the spec's
    /// 50pt radius and the iridescent gradient does not rotate.
    @ViewBuilder
    private func currentMarker(palette: IhsanCelestialPalette) -> some View {
        ZStack {
            halo(palette: palette)
            iridescentOrnament(palette: palette)
        }
    }

    /// Soft radial halo behind the active ornament — 30% peak opacity,
    /// ~50pt radius, with a gentle 4-second pulse between 45pt and 55pt.
    @ViewBuilder
    private func halo(palette: IhsanCelestialPalette) -> some View {
        if reduceMotion {
            haloCircle(palette: palette, radius: 50)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let elapsed = context.date.timeIntervalSinceReferenceDate
                let phase = (elapsed.truncatingRemainder(dividingBy: 4.0)) / 4.0
                let radius = 50.0 + 5.0 * sin(phase * 2.0 * .pi)
                haloCircle(palette: palette, radius: radius)
            }
        }
    }

    private func haloCircle(palette: IhsanCelestialPalette, radius: Double) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        palette.accentBright.opacity(0.30),
                        palette.accentBright.opacity(0.10),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: radius
                )
            )
            .frame(width: radius * 2, height: radius * 2)
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
    }

    /// The active ornament rendered at 24pt with the iridescent brass
    /// angular gradient as its body. The gradient angle rotates over a
    /// 3-second cycle so the gold catches different light around its
    /// perimeter (static under Reduce Motion).
    @ViewBuilder
    private func iridescentOrnament(palette: IhsanCelestialPalette) -> some View {
        if reduceMotion {
            currentBody(angle: .zero, palette: palette)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let elapsed = context.date.timeIntervalSinceReferenceDate
                // 3-second full rotation = 120°/second.
                let degrees = (elapsed * 120.0).truncatingRemainder(dividingBy: 360.0)
                currentBody(angle: .degrees(degrees), palette: palette)
            }
        }
    }

    private func currentBody(angle: Angle, palette: IhsanCelestialPalette) -> some View {
        PrayerOrnamentView(
            prayer: prayer,
            size: 24,
            style: .filledShape(IhsanIridescence.brassStroke(angle: angle))
        )
        .overlay {
            // A faint accent-bright highlight on top of the iridescent
            // body so the active ornament reads brighter than the brass
            // perimeter alone. Matches the soft glow on the sun
            // ornament so the two materials feel related.
            PrayerOrnamentView(
                prayer: prayer,
                size: 24,
                style: .filled(palette.accentBright, opacity: 0.35)
            )
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
        }
        .shadow(
            color: palette.accentBright.opacity(0.40),
            radius: 4,
            x: 0,
            y: 0
        )
    }
}

// MARK: - Convenience: deriving state from a prayer time relative to now

public extension PrayerMarker.State {
    /// Derive a marker state from the prayer's scheduled time and
    /// whether this prayer is the next upcoming (or currently in its
    /// window).
    static func derive(
        scheduledTime: Date,
        isNextUpcoming: Bool,
        now: Date = .now
    ) -> PrayerMarker.State {
        if isNextUpcoming {
            return .current
        }
        return scheduledTime <= now ? .past : .future
    }
}

#Preview("Prayer markers — above and below horizon") {
    VStack(spacing: 32) {
        HStack(spacing: 32) {
            PrayerMarker(prayer: .fajr, state: .past)
            PrayerMarker(prayer: .dhuhr, state: .past)
            PrayerMarker(prayer: .asr, state: .current)
            PrayerMarker(prayer: .maghrib, state: .future)
            PrayerMarker(prayer: .isha, state: .future)
        }
        Divider()
        HStack(spacing: 32) {
            PrayerMarker(prayer: .fajr, state: .future, aboveHorizon: false)
            PrayerMarker(prayer: .maghrib, state: .past, aboveHorizon: false)
            PrayerMarker(prayer: .isha, state: .future, aboveHorizon: false)
        }
    }
    .padding(40)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(
        LinearGradient(
            colors: [IhsanCelestialPalette.day.sky, IhsanCelestialPalette.day.skyDeep],
            startPoint: .top,
            endPoint: .bottom
        )
    )
    .environment(\.timeOfDayOverride, dateAt(hour: 13, minute: 0))
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
