import IhsanCore
import IhsanDesignSystem
import SwiftUI

/// The Today screen's instrument: palette-v2 atmosphere, the engraved
/// day arc, the five prayer ornaments, and the sun and moon at their
/// real positions — composed into one live scene.
///
/// This view owns no astronomy and no positioning math. Every point it
/// draws comes from `PlateGeometry`; every colour comes from the
/// resolved `SkyPaletteTokens`; the sun and moon come from
/// `SolarPosition` / `LunarPosition`. What it owns is the composition:
/// which layer sits over which, how big each ornament is, and where a
/// label hangs off its marker.
///
/// Two horizontal conventions live on the plate, deliberately:
///
/// - **Markers** are placed by time — `markerPosition(for:)` maps the
///   day's Fajr…Isha domain onto the arc's inset angular span, so the
///   arc reads as the day's engraved scale and no marker can reach the
///   frame.
/// - **Bodies** are placed by sky position — real altitude, and a
///   horizontal parameter derived from the local hour angle (see
///   `azimuthUnit(hourAngle:)`). The sun and the moon therefore share
///   one continuous scale and sit correctly relative to each other.
///
/// The view keeps no state. It is a pure function of the data handed
/// to it plus the moment, so it renders identically in the app, in a
/// preview, and in an offline snapshot harness.
struct CelestialPlateScene: View {

    /// One prayer on the plate: which ornament, when, and what
    /// lifecycle state it is in.
    struct Marker: Identifiable, Equatable {
        let prayer: Prayer
        let time: Date
        let state: PrayerMarkerState

        var id: Prayer { prayer }

        init(prayer: Prayer, time: Date, state: PrayerMarkerState) {
            self.prayer = prayer
            self.time = time
            self.state = state
        }
    }

    /// The day's five fardh markers, in chronological order.
    let markers: [Marker]
    /// The solar events that anchor the palette phase. Supplied by the
    /// caller from the day's real prayer schedule — the design system
    /// never computes prayer times.
    let solarEvents: SolarDayEvents
    let latitude: Double
    let longitude: Double
    /// Timezone the marker labels are formatted in. Prayer times are
    /// absolute instants; the plate is the UI layer that localises them.
    let timeZone: TimeZone

    /// Room reserved at the top of the frame for the header, and at the
    /// bottom for the focused card. The atmosphere still fills the whole
    /// frame — only the arc, the markers, and the horizon respect these.
    var topInset: CGFloat = 0
    var bottomInset: CGFloat = 0

    /// Fixed instant, for previews and snapshot renders. `nil` drives
    /// the scene from the clock.
    var timeOverride: Date?
    /// Marker tap — the Today screen swaps the focused card to this
    /// prayer. `nil` makes the plate non-interactive.
    var onMarkerTap: ((Prayer) -> Void)?
    /// Optional render-loop instrumentation.
    var probe: FrameTimeProbe?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Composition constants
    //
    // Sizes only. Every *position* comes from PlateGeometry.

    /// The plate's chord sits at 62% of the instrument zone — high
    /// enough that the arc carries the composition, low enough that the
    /// ground plane reads as ground rather than as a border.
    private static let horizonFraction: CGFloat = 0.62
    private static let markerSize: CGFloat = 24
    /// The prayer happening now is drawn larger as well as luminous;
    /// size and light together make it the focal point at arm's length.
    private static let currentMarkerSize: CGFloat = 34
    /// Half-extent PlateGeometry reserves around every marker position.
    /// Comfortably clears the 34 pt ornament; the decorative glow halo
    /// is allowed to bleed past it.
    private static let markerClearance: CGFloat = 32
    /// Vertical room reserved below markers for their time labels.
    private static let labelClearance: CGFloat = 56
    private static let sunDiameter: CGFloat = 56
    private static let moonDiameter: CGFloat = 44

    // MARK: - Body

    var body: some View {
        if let timeOverride {
            scene(at: timeOverride)
        } else if reduceMotion {
            // Reduce Motion takes a single evaluation: the scene is a
            // snapshot of the sky at the moment the screen opened, with
            // no drift of any kind.
            scene(at: .now)
        } else {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                scene(at: context.date)
            }
        }
    }

    @ViewBuilder
    private func scene(at date: Date) -> some View {
        let phase = SkyPhase.resolve(at: date, events: solarEvents)
        let tokens = PaletteState.resolved(for: phase)
        let sun = SolarPosition.compute(at: date, latitude: latitude, longitude: longitude)
        let moon = LunarPosition.compute(at: date, latitude: latitude, longitude: longitude)

        GeometryReader { geometry in
            let plate = plateGeometry(in: geometry.size)

            ZStack {
                CelestialSkyView(
                    phase: phase,
                    sunAltitudeDegrees: sun.altitude,
                    horizonY: plate.horizonY,
                    probe: probe
                )

                dayArc(plate: plate, tokens: tokens)
                bodies(plate: plate, tokens: tokens, sun: sun, moon: moon)
                markerLayer(plate: plate, tokens: tokens)
            }
        }
    }

    /// The instrument zone: full width, inset from the header above and
    /// the card below. Positions come back in the parent's coordinate
    /// space, so the atmosphere (which fills the whole frame) and the
    /// markers agree on where the horizon is.
    private func plateGeometry(in size: CGSize) -> PlateGeometry {
        let height = max(160, size.height - topInset - bottomInset)
        return PlateGeometry(
            rect: CGRect(x: 0, y: topInset, width: size.width, height: height),
            eventTimes: markers.map(\.time),
            horizonFraction: Self.horizonFraction,
            markerClearance: Self.markerClearance,
            labelClearance: Self.labelClearance
        )
    }

    // MARK: - The engraved arc

    /// The day's scale, drawn as a fine dotted engraving. It is the one
    /// line that tells the eye the five ornaments belong to a single
    /// path rather than floating independently.
    private func dayArc(plate: PlateGeometry, tokens: SkyPaletteTokens) -> some View {
        Path(plate.arcPath())
            .stroke(
                tokens.metal.opacity(0.22),
                style: StrokeStyle(lineWidth: 0.8, lineCap: .round, dash: [1, 5])
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    // MARK: - Sun and moon

    @ViewBuilder
    private func bodies(
        plate: PlateGeometry,
        tokens: SkyPaletteTokens,
        sun: SolarPosition,
        moon: LunarPosition
    ) -> some View {
        // The moon is drawn first so the sun's halo passes over it
        // during the daytime conjunctions rather than under it.
        LuminousBody(
            kind: .moon(
                illuminatedFraction: moon.illuminatedFraction,
                isWaxing: moon.isWaxing
            ),
            diameter: Self.moonDiameter,
            tokens: tokens
        )
        .opacity(
            submergedPresence(altitudeDegrees: moon.altitude)
                * lunarDaylightPresence(sunAltitudeDegrees: sun.altitude)
        )
        .position(
            plate.bodyPosition(
                altitudeDegrees: moon.altitude,
                azimuthUnit: azimuthUnit(hourAngle: moon.hourAngle)
            )
        )

        LuminousBody(kind: .sun, diameter: Self.sunDiameter, tokens: tokens)
            .opacity(submergedPresence(altitudeDegrees: sun.altitude))
            .position(
                plate.bodyPosition(
                    altitudeDegrees: sun.altitude,
                    azimuthUnit: azimuthUnit(hourAngle: sun.hourAngle)
                )
            )
    }

    /// The plate's horizontal parameter for a body, from its local hour
    /// angle: −180° (lower transit) at the left edge, 0° (upper
    /// transit) at the centre, +180° at the right edge.
    ///
    /// One scale for both bodies means the moon sits correctly relative
    /// to the sun, and neither ever clamps against the plate's edge —
    /// the whole 24-hour circuit fits.
    private func azimuthUnit(hourAngle: Double) -> Double {
        0.5 + hourAngle / 360.0
    }

    /// A body below the chord is engraved into the ground plane rather
    /// than hidden — its presence falls away with depth and reaches its
    /// floor at astronomical twilight, which is exactly where
    /// `PlateGeometry` bottoms out its below-horizon mapping.
    ///
    /// The curve is deliberately steep. A body a degree or two under
    /// the chord still belongs to the scene — that is the whole drama
    /// of maghrib — but by deep night the sun should be a trace in the
    /// ground, not a dimmed disc floating in it.
    private func submergedPresence(altitudeDegrees: Double) -> Double {
        guard altitudeDegrees < 0 else { return 1 }
        let depth = min(18.0, -altitudeDegrees) / 18.0
        return 0.08 + 0.92 * pow(1.0 - depth, 2.5)
    }

    /// The moon is a quieter light than the sun: barely there against a
    /// high daytime sky, full strength once the sun is well down.
    private func lunarDaylightPresence(sunAltitudeDegrees: Double) -> Double {
        let t = max(0.0, min(1.0, (6.0 - sunAltitudeDegrees) / 24.0))
        return 0.28 + 0.72 * t
    }

    // MARK: - Markers

    @ViewBuilder
    private func markerLayer(plate: PlateGeometry, tokens: SkyPaletteTokens) -> some View {
        ForEach(markers) { marker in
            let position = plate.markerPosition(for: marker.time)
            let size = marker.state == .current ? Self.currentMarkerSize : Self.markerSize

            ornamentButton(marker: marker, size: size, tokens: tokens)
                .position(position)

            markerLabel(marker: marker, tokens: tokens)
                .position(x: position.x, y: position.y + labelOffset(forMarkerSize: size))
        }
    }

    @ViewBuilder
    private func ornamentButton(
        marker: Marker,
        size: CGFloat,
        tokens: SkyPaletteTokens
    ) -> some View {
        let ornament = PrayerMarkerOrnament(
            prayer: marker.prayer,
            size: size,
            state: marker.state,
            tokens: tokens
        )
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())

        if let onMarkerTap {
            Button {
                Haptics.impact(.light)
                onMarkerTap(marker.prayer)
            } label: {
                ornament
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel(for: marker))
            .accessibilityHint("Shows this prayer in the card below.")
        } else {
            ornament
                .accessibilityLabel(accessibilityLabel(for: marker))
        }
    }

    /// The engraved time under each marker. The prayer happening now
    /// is identified by its light and its size, and named in serif on
    /// the card directly below — engraving the name here as well would
    /// be the one accessory to take off before leaving the house.
    private func markerLabel(marker: Marker, tokens: SkyPaletteTokens) -> some View {
        Text(Self.timeString(marker.time, in: timeZone))
            .font(Self.labelFont)
            .tracking(0.9)
            .foregroundStyle(marker.state == .current ? tokens.ink : tokens.inkSecondary)
            .shadow(color: tokens.inkHalo, radius: 2)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// The label hangs off the bottom of the ornament's box with a
    /// constant optical gap, inside the `labelClearance` the plate
    /// reserves below every marker position.
    private func labelOffset(forMarkerSize size: CGFloat) -> CGFloat {
        size / 2 + 11
    }

    private func accessibilityLabel(for marker: Marker) -> String {
        let time = Self.timeString(marker.time, in: timeZone)
        let state: String
        switch marker.state {
        case .current: state = "happening now"
        case .logged: state = "logged"
        case .upcoming: state = "upcoming"
        case .passedUnlogged: state = "passed, not logged"
        }
        return "\(marker.prayer.displayNameEnglish) at \(time), \(state)"
    }

    // MARK: - Label typography
    //
    // `IhsanFont` bottoms out at 13 pt (`.inscription`), which is too
    // large for five labels on a phone-width arc. These match the sizes
    // the design-v2 gallery uses for the same job; a `plateLabel` token
    // belongs in IhsanFont, but adding it is out of scope for this
    // prompt (see the phase report).

    private static let labelFont: Font = .system(
        size: 10, weight: .semibold
    ).smallCaps().monospacedDigit()

    private static func timeString(_ date: Date, in timeZone: TimeZone) -> String {
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.timeZone = timeZone
        return date.formatted(style)
    }
}
