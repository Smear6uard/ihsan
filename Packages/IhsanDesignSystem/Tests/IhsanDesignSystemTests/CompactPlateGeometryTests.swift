import CoreGraphics
import Foundation
import Testing
@testable import IhsanDesignSystem

/// The arc's containment contract: every ornament center the geometry
/// produces keeps the full ornament inside the frame it was given.
/// The StandBy plate hands this arc a 34-point strip; the widget
/// diagnosis found the peak ornament's top edge computing *above* the
/// frame there — drawn into the neighbouring text or cut by the
/// container. The rise must yield before the frame does.
struct CompactPlateGeometryTests {

    /// (frame, ornament) pairs from every live call site: the medium
    /// widget's flexible band, the large widget's 54-pt strip, and
    /// the StandBy plate's 34-pt strip.
    private static let sites: [(size: CGSize, ornament: CGFloat)] = [
        (CGSize(width: 306, height: 74), 22),
        (CGSize(width: 306, height: 54), 20),
        (CGSize(width: 141, height: 34), 17),
        (CGSize(width: 120, height: 28), 14),
    ]

    @Test(arguments: sites.indices)
    func peakOrnamentStaysInsideTheFrame(siteIndex: Int) {
        let site = Self.sites[siteIndex]
        let arc = ArcGeometry(size: site.size, ornamentSize: site.ornament)

        // The arc's peak is at t = 0.5; the lowest points are its ends.
        let peak = arc.point(at: 0.5)
        let end = arc.point(at: 0)

        #expect(
            peak.y - site.ornament / 2 >= 0,
            "peak ornament top \(peak.y - site.ornament / 2) clipped above a \(site.size) frame"
        )
        #expect(
            end.y + site.ornament / 2 <= site.size.height,
            "end ornament bottom \(end.y + site.ornament / 2) clipped below a \(site.size) frame"
        )
        #expect(peak.y < end.y, "the arc must still rise")
    }
}
