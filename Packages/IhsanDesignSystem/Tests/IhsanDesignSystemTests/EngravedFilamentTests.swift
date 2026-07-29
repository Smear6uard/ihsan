import CoreGraphics
import Foundation
import Testing
@testable import IhsanDesignSystem

/// Part-C item 11: the arcs are engraved filaments — continuous,
/// tapered to points at both ends, filled rather than stroked.
struct EngravedFilamentTests {

    private var plate: PlateGeometry {
        let base = Date(timeIntervalSinceReferenceDate: 700_000_000)
        return PlateGeometry(
            rect: CGRect(x: 0, y: 100, width: 402, height: 520),
            eventTimes: (0..<5).map { base.addingTimeInterval(Double($0) * 3 * 3600) }
        )
    }

    @Test
    func arcFilamentIsAClosedRibbonSpanningTheArc(){
        let filament = plate.arcFilamentPath()
        #expect(!filament.isEmpty)
        // Ribbon must span the same horizontal extent as the arc.
        let arcBox = plate.arcPath().boundingBox
        let box = filament.boundingBox
        #expect(abs(box.minX - arcBox.minX) < 1.0)
        #expect(abs(box.maxX - arcBox.maxX) < 1.0)
    }

    @Test
    func ribbonTapersToPointsAtItsEnds() {
        // A straight horizontal ribbon: at the midpoint the ribbon is
        // maxThickness wide; at the ends its two boundary points meet.
        let points = (0...20).map { CGPoint(x: CGFloat($0) * 10, y: 50) }
        let ribbon = PlateGeometry.taperedRibbonPath(along: points, maxThickness: 4)
        #expect(ribbon.contains(CGPoint(x: 100, y: 50)))
        #expect(ribbon.contains(CGPoint(x: 100, y: 51.5)))
        // Just inside the ends the ribbon is already too thin to reach
        // 1.5pt off-axis — the taper is real.
        #expect(!ribbon.contains(CGPoint(x: 4, y: 51.5)))
        #expect(!ribbon.contains(CGPoint(x: 196, y: 51.5)))
    }

    // MARK: - Knockouts (corrective E item 2)

    /// Every point of every kept segment stays clear of every
    /// knockout's expanded bounding form — the linework genuinely
    /// terminates at medallions instead of passing under them.
    @Test
    func arcSegmentsTerminateShortOfKnockouts() {
        let plate = plate
        let apex = plate.arcApex
        let knockout = CGRect(x: apex.x - 15, y: apex.y - 15, width: 30, height: 30)
        let clearance: CGFloat = 7
        let segments = plate.arcFilamentSegments(
            avoiding: [knockout], clearance: clearance
        )

        #expect(segments.count >= 2, "a knockout at the apex must split the arc")
        let zone = knockout.insetBy(dx: -clearance + 0.5, dy: -clearance + 0.5)
        for segment in segments {
            #expect(
                !segment.boundingBox.intersects(zone) || !zoneOverlapsRibbon(segment, zone),
                "segment ribbon enters the knockout zone"
            )
        }
    }

    /// With no knockouts, segmentation returns the whole arc as one
    /// ribbon spanning the same extent as the continuous filament.
    @Test
    func segmentationWithoutKnockoutsIsTheWholeArc() {
        let segments = plate.arcFilamentSegments(avoiding: [])
        #expect(segments.count == 1)
        let whole = plate.arcFilamentPath().boundingBox
        let only = segments[0].boundingBox
        #expect(abs(only.minX - whole.minX) < 4.0)
        #expect(abs(only.maxX - whole.maxX) < 4.0)
    }

    /// Almucantar segments obey the same termination rule.
    @Test
    func almucantarSegmentsAvoidKnockouts() {
        let plate = plate
        // Knock out a box straddling the low almucantar's apex.
        let apexY = plate.almucantarPath(riseFraction: 0.36).boundingBox.minY
        let knockout = CGRect(x: plate.rect.midX - 14, y: apexY - 14, width: 28, height: 28)
        let segments = plate.almucantarFilamentSegments(
            riseFraction: 0.36, avoiding: [knockout]
        )
        #expect(segments.count >= 2)
        let zone = knockout.insetBy(dx: -6.5, dy: -6.5)
        for segment in segments {
            #expect(!zoneOverlapsRibbon(segment, zone))
        }
    }

    /// Sample the zone on a fine grid and ask the ribbon path whether
    /// it covers any sampled point.
    private func zoneOverlapsRibbon(_ ribbon: CGPath, _ zone: CGRect) -> Bool {
        let steps = 24
        for i in 0...steps {
            for j in 0...steps {
                let probe = CGPoint(
                    x: zone.minX + zone.width * CGFloat(i) / CGFloat(steps),
                    y: zone.minY + zone.height * CGFloat(j) / CGFloat(steps)
                )
                if ribbon.contains(probe) { return true }
            }
        }
        return false
    }

    @Test
    func almucantarsNestStrictlyUnderTheDayArc() {
        let low = plate.almucantarPath(riseFraction: 0.36).boundingBox
        let high = plate.almucantarPath(riseFraction: 0.68).boundingBox
        let arc = plate.arcPath().boundingBox
        // Higher rise fraction reaches higher (smaller minY), and both
        // stay below the day arc's apex.
        #expect(high.minY < low.minY)
        #expect(low.minY > arc.minY)
        #expect(high.minY > arc.minY)
        // All linework stays inside the plate.
        #expect(low.minY >= plate.rect.minY)
        #expect(high.minY >= plate.rect.minY)
    }
}
