import IhsanCore
import SwiftUI

/// A single prayer time marker on the celestial scene.
///
/// Visual hierarchy:
///
/// - `.future` (above horizon): outlined four-pointed star, brass.
/// - `.past` (above horizon): filled four-pointed star, brass.
/// - `.current` (above horizon): an eight-pointed iridescent star with
///   a soft halo — the brightest element on the scene besides the
///   sun / moon ornament itself.
/// - Below horizon: a muted four-pointed star regardless of state.
///   The subterranean region is where the user's eye finds prayers
///   whose sun is currently below the horizon (Fajr before sunrise,
///   Maghrib and Isha after sunset). These markers don't carry a
///   past/future distinction visually; the alpha reduction signals
///   "below horizon" as a uniform treatment.
///
/// The marker positions itself in the celestial scene at the **sun's
/// position at the prayer's scheduled time** — that's the
/// CelestialScene's job, not PrayerMarker's. This view renders the
/// marker glyph + small-caps prayer label as a vertical group; the
/// caller positions the group via `.position(_)`.
public struct PrayerMarker: View {

    /// Marker state — drives the glyph variant for above-horizon
    /// markers. Below-horizon markers ignore state and always render
    /// as a muted four-pointed star.
    public enum State: Sendable, Equatable {
        /// Prayer scheduled time is in the future.
        case future
        /// Prayer scheduled time is in the past.
        case past
        /// Prayer is the next upcoming or currently in its window.
        case current
    }

    /// Prayer name as a localised, capitalised label ("FAJR",
    /// "DHUHR"). Stored as a String rather than a `Prayer` so the
    /// caller chooses the casing / abbreviation form.
    public let label: String

    /// Current visual state of the marker.
    public let state: State

    /// Whether the prayer's sun position is above the horizon line at
    /// the moment the scene is rendered. When `false`, the marker
    /// renders with muted opacity and uses the four-pointed-star shape
    /// regardless of state — the subterranean region's uniform
    /// "below horizon" treatment.
    public let aboveHorizon: Bool

    @Environment(\.timeOfDayOverride) private var override
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(label: String, state: State, aboveHorizon: Bool = true) {
        self.label = label
        self.state = state
        self.aboveHorizon = aboveHorizon
    }

    public var body: some View {
        let date = override ?? .now
        let palette = IhsanCelestialPalette.current(at: date)
        let labelOpacity = aboveHorizon ? 0.70 : 0.50

        VStack(spacing: 6) {
            marker(palette: palette)
            Text(label)
                .font(.system(size: 9, weight: .semibold).smallCaps())
                .tracking(0.5)
                .foregroundStyle(palette.accent.opacity(labelOpacity))
                .fixedSize()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        if !aboveHorizon {
            return "\(label), below horizon"
        }
        switch state {
        case .future:
            return "\(label), upcoming"
        case .past:
            return "\(label), past"
        case .current:
            return "\(label), next prayer"
        }
    }

    @ViewBuilder
    private func marker(palette: IhsanCelestialPalette) -> some View {
        if !aboveHorizon {
            // Below horizon: muted four-pointed star, regardless of
            // state. Both stroke and fill drop to 50% opacity so the
            // marker reads as quieter than even a future above-horizon
            // marker (60% stroke) and a past above-horizon marker (80%
            // fill).
            FourPointedStar()
                .fill(palette.accent.opacity(0.50))
                .frame(width: 12, height: 12)
        } else {
            switch state {
            case .future:
                FourPointedStar()
                    .stroke(palette.accent.opacity(0.60), lineWidth: 0.6)
                    .frame(width: 12, height: 12)
            case .past:
                FourPointedStar()
                    .fill(palette.accent.opacity(0.80))
                    .frame(width: 12, height: 12)
            case .current:
                currentMarker(palette: palette)
            }
        }
    }

    /// Active prayer marker — an iridescent eight-pointed star with
    /// a soft halo. The angular-gradient fill rotates over a 4-second
    /// cycle (static under Reduce Motion), echoing the sun ornament's
    /// motion so the two read as the same material across the scene.
    @ViewBuilder
    private func currentMarker(palette: IhsanCelestialPalette) -> some View {
        ZStack {
            // Soft halo behind the star — ~30pt radius at 10% peak
            // opacity, exactly as the spec describes.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            palette.accentBright.opacity(0.18),
                            palette.accentBright.opacity(0.06),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 30
                    )
                )
                .frame(width: 60, height: 60)
                .blendMode(.plusLighter)
                .allowsHitTesting(false)

            iridescentStar(palette: palette)
        }
    }

    @ViewBuilder
    private func iridescentStar(palette: IhsanCelestialPalette) -> some View {
        if reduceMotion {
            staticStar(palette: palette, angle: .zero)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let elapsed = context.date.timeIntervalSinceReferenceDate
                let degrees = (elapsed * 90.0).truncatingRemainder(dividingBy: 360.0)
                staticStar(palette: palette, angle: .degrees(degrees))
            }
        }
    }

    @ViewBuilder
    private func staticStar(palette: IhsanCelestialPalette, angle: Angle) -> some View {
        EightPointedStar()
            .fill(IhsanIridescence.brassStroke(angle: angle))
            .overlay {
                EightPointedStar()
                    .fill(palette.accentBright.opacity(0.45))
                    .blendMode(.plusLighter)
            }
            .overlay {
                EightPointedStar()
                    .stroke(palette.accent.opacity(0.75), lineWidth: 0.6)
            }
            .frame(width: 18, height: 18)
            .shadow(
                color: palette.accentBright.opacity(0.50),
                radius: 3,
                x: 0,
                y: 0
            )
    }
}

// MARK: - Convenience: deriving state from a prayer time relative to now

public extension PrayerMarker.State {
    /// Derive a marker state from the prayer's scheduled time and
    /// the index of the next upcoming prayer in the day's list.
    ///
    /// - Parameters:
    ///   - scheduledTime: The prayer's actual scheduled time.
    ///   - isNextUpcoming: True if this prayer is the next prayer the
    ///     user hasn't reached yet (or the prayer whose window is
    ///     currently open).
    ///   - now: The current moment (defaults to `Date.now`).
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

// MARK: - Convenience: label from Prayer

public extension PrayerMarker {
    /// Convenience initializer that derives the small-caps label from
    /// a `Prayer`'s English display name.
    init(prayer: Prayer, state: State, aboveHorizon: Bool = true) {
        self.init(
            label: prayer.displayNameEnglish.uppercased(),
            state: state,
            aboveHorizon: aboveHorizon
        )
    }
}

#Preview("Prayer markers — above and below horizon") {
    VStack(spacing: 32) {
        HStack(spacing: 32) {
            PrayerMarker(label: "FAJR", state: .past)
            PrayerMarker(label: "DHUHR", state: .past)
            PrayerMarker(label: "ASR", state: .current)
            PrayerMarker(label: "MAGHRIB", state: .future)
            PrayerMarker(label: "ISHA", state: .future)
        }
        Divider()
        HStack(spacing: 32) {
            PrayerMarker(label: "FAJR", state: .future, aboveHorizon: false)
            PrayerMarker(label: "MAGHRIB", state: .past, aboveHorizon: false)
            PrayerMarker(label: "ISHA", state: .future, aboveHorizon: false)
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
