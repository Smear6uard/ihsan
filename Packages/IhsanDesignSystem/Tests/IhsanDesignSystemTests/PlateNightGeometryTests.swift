import CoreGraphics
import Foundation
import Testing
@testable import IhsanDesignSystem

/// Property tests for the plate's night extension: the divided night lives
/// entirely below the horizon chord, inside the plate, and never collides
/// with the day markers or their labels.
struct PlateNightGeometryTests {

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

    private let markerSize: CGFloat = 32
    private let labelDrop: CGFloat = 44

    private func markerBox(around p: CGPoint) -> CGRect {
        CGRect(
            x: p.x - markerSize,
            y: p.y - markerSize,
            width: markerSize * 2,
            height: markerSize + labelDrop
        )
    }

    private func randomWorld(
        _ rng: inout SplitMix64,
        rect: CGRect
    ) -> (plate: PlateGeometry, events: [Date], nightStart: Date, nightEnd: Date) {
        let dayStart = Date(
            timeIntervalSinceReferenceDate: (rng.double(in: 600_000_000...800_000_000) / 86_400).rounded(.down) * 86_400
        )
        // A plausible five-event day: fajr … isha within the civil day.
        let fajr = dayStart.addingTimeInterval(rng.double(in: 0.03...0.25) * 86_400)
        let isha = dayStart.addingTimeInterval(rng.double(in: 0.75...0.99) * 86_400)
        let span = isha.timeIntervalSince(fajr)
        let noon = fajr.addingTimeInterval(span * 0.5)
        let asr = fajr.addingTimeInterval(span * 0.72)
        let maghrib = fajr.addingTimeInterval(span * rng.double(in: 0.80...0.92))
        let events = [fajr, noon, asr, maghrib, isha]

        let plate = PlateGeometry(rect: rect, eventTimes: events)

        // Night: this maghrib to a next-fajr 3–20 hours later (compressed
        // high-latitude nights through long polar ones).
        let nightEnd = maghrib.addingTimeInterval(rng.double(in: 3...20) * 3600)
        return (plate, events, maghrib, nightEnd)
    }

    @Test
    func nightArcStaysInsideThePlateAcross100RandomWorlds() {
        var rng = SplitMix64(state: 0x0117_2233)
        let rects: [CGRect] = [
            CGRect(x: 0, y: 0, width: 393, height: 420),
            CGRect(x: 0, y: 80, width: 393, height: 540),
            CGRect(x: 0, y: 0, width: 820, height: 320),
        ]

        for i in 0..<100 {
            let rect = rects[i % rects.count]
            let world = randomWorld(&rng, rect: rect)
            let plate = world.plate

            for step in 0...40 {
                let t = world.nightStart.addingTimeInterval(
                    world.nightEnd.timeIntervalSince(world.nightStart) * Double(step) / 40
                )
                let p = plate.nightPosition(for: t, nightStart: world.nightStart, nightEnd: world.nightEnd)
                #expect(rect.insetBy(dx: 1, dy: 1).contains(p), "night point escaped plate in world \(i)")
                #expect(p.y >= plate.horizonY - 0.5, "night point rose above the horizon in world \(i)")
            }

            // Out-of-range times clamp, they never escape.
            let before = plate.nightPosition(
                for: world.nightStart.addingTimeInterval(-9000),
                nightStart: world.nightStart,
                nightEnd: world.nightEnd
            )
            let after = plate.nightPosition(
                for: world.nightEnd.addingTimeInterval(9000),
                nightStart: world.nightStart,
                nightEnd: world.nightEnd
            )
            #expect(rect.contains(before) && rect.contains(after))
        }
    }

    @Test
    func nightRunsWestToEastWithMidnightDeepest() {
        let rect = CGRect(x: 0, y: 0, width: 393, height: 420)
        var rng = SplitMix64(state: 0x0918_AB)
        let world = randomWorld(&rng, rect: rect)
        let plate = world.plate
        let span = world.nightEnd.timeIntervalSince(world.nightStart)

        let start = plate.nightPosition(for: world.nightStart, nightStart: world.nightStart, nightEnd: world.nightEnd)
        let mid = plate.nightPosition(
            for: world.nightStart.addingTimeInterval(span / 2),
            nightStart: world.nightStart,
            nightEnd: world.nightEnd
        )
        let end = plate.nightPosition(for: world.nightEnd, nightStart: world.nightStart, nightEnd: world.nightEnd)

        // The sun sets in the west (right) and dawn breaks in the east (left).
        #expect(start.x > end.x)
        // Nisf al-layl is the arc's deepest point.
        #expect(mid.y > start.y && mid.y > end.y)
    }

    @Test
    func nightDivisionsSitBelowHorizonInOrderAcross100RandomWorlds() {
        var rng = SplitMix64(state: 0x0501_44EF)
        let rect = CGRect(x: 0, y: 0, width: 393, height: 420)

        for i in 0..<100 {
            let world = randomWorld(&rng, rect: rect)
            let plate = world.plate
            let span = world.nightEnd.timeIntervalSince(world.nightStart)
            let nisf = world.nightStart.addingTimeInterval(span / 2)
            let lastThird = world.nightStart.addingTimeInterval(span * 2 / 3)

            let night = plate.nightGeometry(
                nightStart: world.nightStart,
                nisfAlLayl: nisf,
                lastThirdStart: lastThird,
                nightEnd: world.nightEnd
            )

            for point in [night.midnightPoint, night.lastThirdStartPoint,
                          night.midnightLabelAnchor, night.lastThirdLabelAnchor] {
                #expect(rect.insetBy(dx: 1, dy: 1).contains(point), "division escaped plate in world \(i)")
                #expect(point.y > plate.horizonY + 8, "division not clearly below horizon in world \(i)")
            }

            // The last third lies east of midnight (dawnward).
            #expect(night.lastThirdStartPoint.x < night.midnightPoint.x, "ordering broke in world \(i)")
        }
    }

    @Test
    func nightDivisionsNeverCollideWithDayMarkersOrLabels() {
        var rng = SplitMix64(state: 0x0999_0042)
        let rects: [CGRect] = [
            CGRect(x: 0, y: 0, width: 393, height: 420),
            CGRect(x: 0, y: 80, width: 393, height: 540),
        ]

        for i in 0..<100 {
            let rect = rects[i % rects.count]
            let world = randomWorld(&rng, rect: rect)
            let plate = world.plate
            let span = world.nightEnd.timeIntervalSince(world.nightStart)
            let night = plate.nightGeometry(
                nightStart: world.nightStart,
                nisfAlLayl: world.nightStart.addingTimeInterval(span / 2),
                lastThirdStart: world.nightStart.addingTimeInterval(span * 2 / 3),
                nightEnd: world.nightEnd
            )

            let dayBoxes = world.events.map { markerBox(around: plate.markerPosition(for: $0)) }

            // A generous box around each division mark and its label text.
            let divisionBoxes = [
                CGRect(x: night.midnightPoint.x - 8, y: night.midnightPoint.y - 10, width: 16, height: 20),
                CGRect(x: night.midnightLabelAnchor.x - 36, y: night.midnightLabelAnchor.y - 7, width: 72, height: 14),
                CGRect(x: night.lastThirdLabelAnchor.x - 40, y: night.lastThirdLabelAnchor.y - 7, width: 80, height: 14),
            ]

            for dayBox in dayBoxes {
                for divisionBox in divisionBoxes {
                    #expect(!dayBox.intersects(divisionBox), "division collided with a day marker in world \(i)")
                }
            }
        }
    }

    @Test
    func lastThirdRegionStaysBelowChordAndInsidePlate() {
        var rng = SplitMix64(state: 0x0404_11)
        let rect = CGRect(x: 0, y: 0, width: 393, height: 420)

        for _ in 0..<25 {
            let world = randomWorld(&rng, rect: rect)
            let plate = world.plate
            let span = world.nightEnd.timeIntervalSince(world.nightStart)
            let region = plate.lastThirdRegionPath(
                nightStart: world.nightStart,
                lastThirdStart: world.nightStart.addingTimeInterval(span * 2 / 3),
                nightEnd: world.nightEnd
            )

            let box = region.boundingBox
            #expect(box.minY >= plate.horizonY - 0.5)
            #expect(rect.insetBy(dx: -0.5, dy: -0.5).contains(CGPoint(x: box.minX, y: box.minY)))
            #expect(rect.insetBy(dx: -0.5, dy: -0.5).contains(CGPoint(x: box.maxX, y: box.maxY)))
            #expect(box.width > 10 && box.height > 4, "region degenerated")
        }
    }

    @Test
    func tinyRectsStayBoundedWithoutLabels() {
        // Watch-size scene: geometry must stay inside even when there is no
        // room for the label treatment (the scene omits labels there).
        let rect = CGRect(x: 0, y: 0, width: 184, height: 200)
        let base = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let events = [0.2, 0.5, 0.7, 0.85, 0.95].map { base.addingTimeInterval($0 * 86_400) }
        let plate = PlateGeometry(rect: rect, eventTimes: events, markerClearance: 24, labelClearance: 20)
        let nightStart = events[3]
        let nightEnd = nightStart.addingTimeInterval(8 * 3600)

        let night = plate.nightGeometry(
            nightStart: nightStart,
            nisfAlLayl: nightStart.addingTimeInterval(4 * 3600),
            lastThirdStart: nightStart.addingTimeInterval(16 * 3600 / 3),
            nightEnd: nightEnd
        )

        for point in [night.midnightPoint, night.lastThirdStartPoint] {
            #expect(rect.contains(point))
            #expect(point.y > plate.horizonY)
        }
    }
}
