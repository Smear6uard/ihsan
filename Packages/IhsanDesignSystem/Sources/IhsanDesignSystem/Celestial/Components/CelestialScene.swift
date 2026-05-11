import IhsanCore
import SwiftUI

/// The celestial Today screen's middle zone — the visual heart of the
/// app, rendered as a single composed view.
///
/// Phase 3 establishes the foundation: a time-adaptive sky gradient
/// with a night star field overlaid. Phase 4 adds the sun and moon
/// ornaments at their real altitudes; Phase 5 adds the five prayer
/// markers positioned at the sun's altitude / hour angle at each
/// prayer's scheduled time. Phase 6 adds the horizon line and glow
/// halo for dawn / dusk transitions.
///
/// The view re-renders on a 60 s cadence so the sky drifts visibly
/// through dawn and dusk without ever animating fast enough for the
/// motion itself to read as movement. Reduce-motion users get a
/// single static evaluation on first render; their experience is a
/// snapshot of the celestial scene at the moment they opened it.
///
/// The accessibility label aggregates the scene's state into one
/// spoken phrase ("Daytime sky", "Night sky with stars") so VoiceOver
/// doesn't read out each individual star as a separate element.
public struct CelestialScene: View {

    /// Observer latitude in degrees. Positive north, negative south.
    /// Drives the astronomical position math for the sun, moon, and
    /// prayer markers.
    public let latitude: Double

    /// Observer longitude in degrees. Positive east, negative west.
    public let longitude: Double

    /// The day's prayer times. Each entry positions a `PrayerMarker`
    /// on the scene at the sun's altitude / hour angle at that prayer's
    /// scheduled time. Empty by default so previews and early-phase
    /// integration paths don't need to thread prayer data.
    public let prayerMarkers: [PrayerMarkerData]

    @Environment(\.timeOfDayOverride) private var override
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        latitude: Double,
        longitude: Double,
        prayerMarkers: [PrayerMarkerData] = []
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.prayerMarkers = prayerMarkers
    }

    public var body: some View {
        if let override {
            scene(at: override)
        } else if reduceMotion {
            scene(at: .now)
        } else {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                scene(at: context.date)
            }
        }
    }

    @ViewBuilder
    private func scene(at date: Date) -> some View {
        let state = SkyState.current(at: date)
        let solar = SolarPosition.compute(at: date, latitude: latitude, longitude: longitude)
        let lunar = LunarPosition.compute(at: date, latitude: latitude, longitude: longitude)
        let currentIndex = currentMarkerIndex(at: date)

        GeometryReader { geometry in
            ZStack {
                SkyGradient()

                // Star field — visible at night, faded around dawn /
                // dusk. The view itself reads the time-of-day via its
                // own override; we modulate its visibility here with
                // opacity so the per-minute redraw in CelestialScene
                // doesn't have to reshuffle the star positions.
                if state.starOpacity > 0.01 {
                    StarField()
                        .opacity(state.starOpacity)
                }

                // Horizon line — a thin brass rule with warm glow
                // above and rose-gold glow below, visible only when
                // the sun is within ±10° of the horizon (the Fajr-to-
                // sunrise and Maghrib-to-Isha windows). Drawn beneath
                // the sun / moon ornaments so those cross over it.
                let horizonOpacity = HorizonLine.opacity(
                    forSunAltitude: solar.altitude
                )
                if horizonOpacity > 0.01 {
                    HorizonLine(opacity: horizonOpacity)
                        .frame(width: geometry.size.width)
                        .position(
                            x: geometry.size.width / 2,
                            y: horizonY(in: geometry.size)
                        )
                }

                // Sun ornament — visible whenever the sun's altitude
                // is above the descent-animation margin (~-10° below
                // horizon). Hidden at deep night when the sun is far
                // below the user's local horizon.
                if shouldShowSun(solar: solar, sky: state) {
                    SunOrnament(altitude: solar.altitude)
                        .position(
                            CelestialMapping.screenPosition(
                                for: solar,
                                in: geometry.size
                            )
                        )
                }

                // Moon ornament — visible whenever the moon is above
                // the horizon AND the sky is at least somewhat dark.
                // Overlap with the sun during dawn / dusk is fine; the
                // two are at different positions, and at twilight both
                // are visible in real life.
                if shouldShowMoon(lunar: lunar, sky: state) {
                    MoonOrnament(position: lunar)
                        .position(
                            CelestialMapping.screenPosition(
                                for: lunar,
                                in: geometry.size
                            )
                        )
                }

                // Prayer markers — five small ornamental glyphs placed
                // at the sun's position at each prayer's scheduled
                // time. State variants (future / past / current)
                // communicate where the user is in the day's schedule.
                ForEach(prayerMarkers.indices, id: \.self) { i in
                    let marker = prayerMarkers[i]
                    let position = markerScreenPosition(
                        for: marker,
                        in: geometry.size
                    )
                    let state = markerState(
                        markerIndex: i,
                        currentIndex: currentIndex,
                        scheduledTime: marker.scheduledTime,
                        now: date
                    )
                    PrayerMarker(prayer: marker.prayer, state: state)
                        .position(position)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: state, solar: solar, lunar: lunar))
    }

    private func shouldShowSun(solar: SolarPosition, sky: SkyState) -> Bool {
        // Always show the sun if it's reasonably above the horizon, or
        // briefly during descent. Hide once it's deeply below.
        solar.altitude > -10.0 && sky.starOpacity < 0.90
    }

    /// The y-coordinate of the horizon (altitude 0°) in the celestial
    /// scene. Used to place the horizon line band so that the brass
    /// rule sits exactly where the sun crosses zero altitude as it
    /// rises and sets.
    private func horizonY(in size: CGSize) -> CGFloat {
        CelestialMapping.screenPosition(
            hourAngle: 0,
            altitude: 0,
            in: size
        ).y
    }

    private func shouldShowMoon(lunar: LunarPosition, sky: SkyState) -> Bool {
        // Moon only renders when above horizon and the sky is at least
        // somewhat dark so it has contrast against the parchment day.
        lunar.altitude > 0.0 && sky.starOpacity > 0.10
    }

    /// Compute the screen position for a prayer marker by evaluating
    /// the sun's position at the marker's scheduled time.
    private func markerScreenPosition(
        for marker: PrayerMarkerData,
        in size: CGSize
    ) -> CGPoint {
        let solarAtPrayer = SolarPosition.compute(
            at: marker.scheduledTime,
            latitude: latitude,
            longitude: longitude
        )
        return CelestialMapping.screenPosition(
            for: solarAtPrayer,
            in: size
        )
    }

    /// Index of the prayer marker that should render in the `.current`
    /// state — defined as the first prayer whose scheduled time is in
    /// the future (or `nil` if all prayers' times have passed). The
    /// markers preceding it are `.past`; the markers after it are
    /// `.future`.
    private func currentMarkerIndex(at date: Date) -> Int? {
        prayerMarkers.firstIndex { $0.scheduledTime > date }
    }

    private func markerState(
        markerIndex: Int,
        currentIndex: Int?,
        scheduledTime: Date,
        now: Date
    ) -> PrayerMarker.State {
        if markerIndex == currentIndex {
            return .current
        }
        return scheduledTime <= now ? .past : .future
    }

    private func accessibilityLabel(
        for state: SkyState,
        solar: SolarPosition,
        lunar: LunarPosition
    ) -> String {
        let base: String
        if state.starOpacity > 0.85 {
            base = "Night sky with stars"
        } else if state.starOpacity > 0.30 {
            base = "Twilight sky"
        } else {
            base = "Daytime sky"
        }

        var parts: [String] = [base]

        if solar.altitude > -10.0 && state.starOpacity < 0.90 {
            let altitude = Int(solar.altitude.rounded())
            parts.append("sun at \(altitude) degrees above horizon")
        }

        if lunar.altitude > 0.0 && state.starOpacity > 0.10 {
            let f = lunar.illuminatedFraction
            let phase: String
            if f < 0.05 {
                phase = "new moon"
            } else if f < 0.30 {
                phase = lunar.isWaxing ? "waxing crescent" : "waning crescent"
            } else if f < 0.55 {
                phase = lunar.isWaxing ? "first quarter" : "last quarter"
            } else if f < 0.95 {
                phase = lunar.isWaxing ? "waxing gibbous" : "waning gibbous"
            } else {
                phase = "full moon"
            }
            parts.append("\(phase) visible")
        }

        if !prayerMarkers.isEmpty {
            parts.append("\(prayerMarkers.count) prayer times marked across the day")
        }

        return parts.joined(separator: ". ") + "."
    }
}

/// One prayer time for the celestial scene to position a marker at.
public struct PrayerMarkerData: Sendable, Equatable {
    public let prayer: Prayer
    public let scheduledTime: Date

    public init(prayer: Prayer, scheduledTime: Date) {
        self.prayer = prayer
        self.scheduledTime = scheduledTime
    }
}

#Preview("Celestial scene — across the day") {
    let coordinates = (lat: 41.78, lng: -88.15)
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    func time(_ h: Int, _ m: Int) -> Date {
        calendar.date(byAdding: .second, value: h * 3600 + m * 60, to: today) ?? today
    }
    let markers: [PrayerMarkerData] = [
        .init(prayer: .fajr, scheduledTime: time(5, 15)),
        .init(prayer: .dhuhr, scheduledTime: time(12, 50)),
        .init(prayer: .asr, scheduledTime: time(16, 40)),
        .init(prayer: .maghrib, scheduledTime: time(20, 5)),
        .init(prayer: .isha, scheduledTime: time(21, 40))
    ]
    return ScrollView(.horizontal) {
        HStack(spacing: 0) {
            ForEach([6, 9, 12, 16, 19, 22], id: \.self) { hour in
                VStack {
                    Text("\(hour):00")
                        .font(.system(size: 11, weight: .semibold).smallCaps())
                        .tracking(1.1)
                        .foregroundStyle(.white.opacity(0.7))
                    CelestialScene(
                        latitude: coordinates.lat,
                        longitude: coordinates.lng,
                        prayerMarkers: markers
                    )
                    .environment(\.timeOfDayOverride, time(hour, 0))
                    .frame(width: 260, height: 380)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(8)
            }
        }
    }
    .background(.black)
    .ignoresSafeArea()
}
