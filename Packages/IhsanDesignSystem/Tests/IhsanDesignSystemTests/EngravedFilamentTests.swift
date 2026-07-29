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
