import CoreGraphics
import Foundation
import Testing
@testable import IhsanDesignSystem

/// Property test for the plate's central guarantee: for any location,
/// date, and resulting event schedule — including high-latitude
/// summers where Fajr and Isha crowd the ends of the day — no marker
/// bounding box (at maximum ornament size plus label) may intersect
/// the scene edge.
struct PlateGeometryTests {

    /// Deterministic RNG so the "random" locations are reproducible.
    private struct SplitMix64 {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
        mutating func double(in range: ClosedRange<Double>) -> Double {
            let unit = Double(next() >> 11) / Double(1 << 53)
            return range.lowerBound + unit * (range.upperBound - range.lowerBound)
        }
    }

    private let markerSize: CGFloat = 32   // half-extent at max ornament size
    private let labelDrop: CGFloat = 44    // label zone below the marker

    private func markerBox(around p: CGPoint) -> CGRect {
        CGRect(
            x: p.x - markerSize,
            y: p.y - markerSize,
            width: markerSize * 2,
            height: markerSize + labelDrop
        )
    }

    /// Derive a day's five prayer instants for a location by scanning
    /// real solar altitude. Where a crossing doesn't exist (polar
    /// summer/winter), fall back to the most extreme legal schedule —
    /// events crammed against the ends of the civil day — which is
    /// exactly the input that used to clip.
    private func eventTimes(
        latitude: Double,
        longitude: Double,
        dayStart: Date
    ) -> [Date] {
        let step: TimeInterval = 300
        var samples: [(Date, Double)] = []
        for i in 0...(288) {
            let t = dayStart.addingTimeInterval(Double(i) * step)
            let position = SolarPosition.compute(at: t, latitude: latitude, longitude: longitude)
            samples.append((t, position.altitude))
        }

        func crossing(_ threshold: Double, rising: Bool) -> Date? {
            for i in 1..<samples.count {
                let (t0, a0) = samples[i - 1]
                let (_, a1) = samples[i]
                if rising && a0 < threshold && a1 >= threshold { return t0 }
                if !rising && a0 >= threshold && a1 < threshold { return t0 }
            }
            return nil
        }

        let noon = samples.max { $0.1 < $1.1 }?.0 ?? dayStart.addingTimeInterval(43_200)
        let fajr = crossing(-15, rising: true) ?? dayStart.addingTimeInterval(40 * 60)
        let sunset = crossing(-0.833, rising: false) ?? dayStart.addingTimeInterval(23 * 3600)
        let isha = crossing(-15, rising: false) ?? dayStart.addingTimeInterval(23.8 * 3600)
        let asr = noon.addingTimeInterval(sunset.timeIntervalSince(noon) * 0.55)
        return [fajr, noon, asr, sunset, isha]
    }

    @Test
    func noMarkerBoxTouchesTheEdgeAcross100RandomWorlds() {
        var rng = SplitMix64(state: 0x1A5F_2026)
        let rects: [CGRect] = [
            CGRect(x: 0, y: 0, width: 393, height: 420),   // iPhone scene
            CGRect(x: 0, y: 0, width: 184, height: 200),   // watch scene
            CGRect(x: 0, y: 0, width: 820, height: 320)    // wide/iPad band
        ]

        for world in 0..<100 {
            let latitude = rng.double(in: -68...68)
            let longitude = rng.double(in: -179...179)
            // Any date in a ±3-year window around a fixed epoch.
            let dayStart = Date(
                timeIntervalSinceReferenceDate: 790_000_000 + rng.double(in: 0...(3 * 365 * 86_400))
            )
            let events = eventTimes(latitude: latitude, longitude: longitude, dayStart: dayStart)
            let rect = rects[world % rects.count]
            let plate = PlateGeometry(
                rect: rect,
                eventTimes: events,
                markerClearance: markerSize,
                labelClearance: labelDrop
            )

            for event in events {
                let box = markerBox(around: plate.markerPosition(for: event))
                #expect(
                    rect.contains(box),
                    "world \(world) (lat \(latitude), lon \(longitude)): marker box \(box) escapes \(rect)"
                )
            }

            // The sun and moon must stay inside the plate at every
            // altitude/azimuth, above or below the horizon.
            for _ in 0..<8 {
                let altitude = rng.double(in: -30...95)
                let azimuth = rng.double(in: -0.3...1.3)
                let p = plate.bodyPosition(altitudeDegrees: altitude, azimuthUnit: azimuth)
                let box = CGRect(x: p.x - 28, y: p.y - 28, width: 56, height: 56)
                #expect(
                    rect.insetBy(dx: -0.01, dy: -0.01).contains(box),
                    "world \(world): body box \(box) escapes \(rect) at alt \(altitude)"
                )
            }
        }
    }

    /// The pathological schedule the corrective exists for: Fajr at
    /// 01:12 and Isha at 23:58 (high-latitude summer). Both must land
    /// at the angular inset, fully inside — never at the frame.
    @Test
    func highLatitudeSummerEndpointsStayInside() {
        let dayStart = Date(timeIntervalSinceReferenceDate: 806_000_000)
        let events = [
            dayStart.addingTimeInterval(72 * 60),           // 01:12
            dayStart.addingTimeInterval(13.1 * 3600),
            dayStart.addingTimeInterval(18.4 * 3600),
            dayStart.addingTimeInterval(23.2 * 3600),
            dayStart.addingTimeInterval(23.96 * 3600)       // 23:58
        ]
        let rect = CGRect(x: 0, y: 0, width: 393, height: 420)
        let plate = PlateGeometry(rect: rect, eventTimes: events)

        let first = plate.markerPosition(for: events[0])
        let last = plate.markerPosition(for: events[4])
        #expect(rect.contains(markerBox(around: first)))
        #expect(rect.contains(markerBox(around: last)))
        // The endpoints sit at the angular inset — visibly inside the
        // arc's ends, not pinned to the plate frame.
        #expect(first.x > rect.minX + plate.markerClearance)
        #expect(last.x < rect.maxX - plate.markerClearance)
        #expect(first.y < plate.horizonY, "arc endpoints sit above the horizon chord")
    }

    /// Degenerate inputs: empty and single-instant event lists must
    /// still produce bounded, finite positions.
    @Test
    func degenerateEventListsAreBounded() {
        let rect = CGRect(x: 0, y: 0, width: 300, height: 300)
        let instant = Date(timeIntervalSinceReferenceDate: 800_000_000)

        let empty = PlateGeometry(rect: rect, eventTimes: [])
        let single = PlateGeometry(rect: rect, eventTimes: [instant])
        for plate in [empty, single] {
            let p = plate.markerPosition(for: instant)
            #expect(p.x.isFinite && p.y.isFinite)
            #expect(rect.contains(p))
        }
    }

    /// Ordering sanity on the arc: earlier events sit left of later
    /// ones, and a midday event sits above both endpoints.
    @Test
    func arcOrderingMatchesTime() {
        let dayStart = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let events = [
            dayStart.addingTimeInterval(5 * 3600),
            dayStart.addingTimeInterval(13 * 3600),
            dayStart.addingTimeInterval(21 * 3600)
        ]
        let plate = PlateGeometry(
            rect: CGRect(x: 0, y: 0, width: 400, height: 400),
            eventTimes: events
        )
        let dawn = plate.markerPosition(for: events[0])
        let noon = plate.markerPosition(for: events[1])
        let dusk = plate.markerPosition(for: events[2])
        #expect(dawn.x < noon.x && noon.x < dusk.x)
        #expect(noon.y < dawn.y && noon.y < dusk.y)
    }

    /// The horizon chord and filament stay inside the plate and taper
    /// (the filament is a closed lens, not an edge-to-edge stroke).
    @Test
    func horizonFilamentIsInsetAndTapered() {
        let plate = PlateGeometry(
            rect: CGRect(x: 0, y: 0, width: 400, height: 400),
            eventTimes: [Date(timeIntervalSinceReferenceDate: 0), Date(timeIntervalSinceReferenceDate: 86_400)]
        )
        let chord = plate.horizonChord
        #expect(chord.start.x > plate.rect.minX)
        #expect(chord.end.x < plate.rect.maxX)

        let filament = plate.filamentPath(thickness: 1.4)
        let bounds = filament.boundingBox
        #expect(bounds.width < plate.rect.width, "filament spans edge-to-edge")
        #expect(bounds.height <= 3.0, "filament reads as a band, not a fine line")
    }
}
