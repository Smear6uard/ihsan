import SwiftUI

/// The celestial Today screen's middle zone — the visual heart of the
/// app, rendered as a single composed view.
///
/// Phase 3 establishes the foundation: a time-adaptive sky gradient
/// with a night star field overlaid. Subsequent phases layer the sun
/// / moon ornaments (Phase 4), the prayer markers (Phase 5), and the
/// horizon line / glow halo (Phase 6) on top of this base.
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

    /// Observer latitude and longitude. Drives the astronomical math
    /// in Phase 4+ (sun and moon ornament positions). Phase 3 doesn't
    /// consume the coordinates directly — they're carried in the view
    /// model so call sites are stable across phases.
    public let latitude: Double
    public let longitude: Double

    @Environment(\.timeOfDayOverride) private var override
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
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

        ZStack {
            SkyGradient()

            // Star field — visible at night, faded around dawn / dusk.
            // The view itself reads the time-of-day via its own
            // override; we modulate its visibility here with opacity
            // so the per-minute redraw in CelestialScene doesn't have
            // to reshuffle the star positions.
            if state.starOpacity > 0.01 {
                StarField()
                    .opacity(state.starOpacity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: state))
    }

    private func accessibilityLabel(for state: SkyState) -> String {
        if state.starOpacity > 0.85 {
            return "Night sky with stars."
        } else if state.starOpacity > 0.30 {
            return "Twilight sky."
        } else {
            return "Daytime sky."
        }
    }
}

#Preview("Celestial scene — across the day") {
    let coordinates = (lat: 41.78, lng: -88.15)
    return ScrollView(.horizontal) {
        HStack(spacing: 0) {
            ForEach([3, 6, 7, 12, 17, 18, 19, 22], id: \.self) { hour in
                VStack {
                    Text("\(hour):00")
                        .font(.system(size: 11, weight: .semibold).smallCaps())
                        .tracking(1.1)
                        .foregroundStyle(.white.opacity(0.7))
                    CelestialScene(latitude: coordinates.lat, longitude: coordinates.lng)
                        .environment(\.timeOfDayOverride, dateAt(hour: hour, minute: 0))
                        .frame(width: 240, height: 360)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(8)
            }
        }
    }
    .background(.black)
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
