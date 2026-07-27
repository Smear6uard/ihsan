import CoreGraphics
import IhsanCore
import SwiftUI
import Testing
@testable import IhsanDesignSystem

/// Geometry contracts for the five-ornament marker library: every
/// ornament stays inside its frame at marker sizes, produces real
/// geometry in both render modes, and — the acceptance criterion —
/// no two ornaments share a silhouette at 16 pt.
struct OrnamentGeometryTests {

    private let sizes: [CGFloat] = [16, 24, 44]

    @Test(arguments: Prayer.allCases)
    func filledSilhouetteStaysInsideFrame(prayer: Prayer) {
        for size in sizes {
            let rect = CGRect(x: 0, y: 0, width: size, height: size)
            let path = PrayerOrnamentShape(prayer: prayer, mode: .filled).path(in: rect)
            #expect(!path.isEmpty, "\(prayer) filled path is empty at \(size)pt")
            let bounds = path.boundingRect
            #expect(
                rect.insetBy(dx: -0.01, dy: -0.01).contains(bounds),
                "\(prayer) filled bounds \(bounds) escape \(size)pt frame"
            )
        }
    }

    @Test(arguments: Prayer.allCases)
    func outlineConstructionStaysInsideFrame(prayer: Prayer) {
        for size in sizes {
            let rect = CGRect(x: 0, y: 0, width: size, height: size)
            let path = PrayerOrnamentShape(prayer: prayer, mode: .outline).path(in: rect)
            #expect(!path.isEmpty, "\(prayer) outline path is empty at \(size)pt")
            let bounds = path.boundingRect
            #expect(
                rect.insetBy(dx: -0.01, dy: -0.01).contains(bounds),
                "\(prayer) outline bounds \(bounds) escape \(size)pt frame"
            )
        }
    }

    /// The silhouette test, made mathematical: rasterize each filled
    /// ornament onto a 16×16 occupancy grid (even-odd, matching how
    /// the component fills) and require every pair of ornaments to
    /// disagree on a meaningful share of cells. Five forms that pass
    /// this cannot collapse into "five identical star markers."
    @Test
    func allFiveSilhouettesAreDistinctAt16pt() {
        let cells = 16
        let rect = CGRect(x: 0, y: 0, width: 16, height: 16)

        func occupancy(_ prayer: Prayer) -> [Bool] {
            let path = PrayerOrnamentShape(prayer: prayer, mode: .filled).path(in: rect)
            var grid: [Bool] = []
            for row in 0..<cells {
                for column in 0..<cells {
                    let probe = CGPoint(
                        x: (CGFloat(column) + 0.5) * rect.width / CGFloat(cells),
                        y: (CGFloat(row) + 0.5) * rect.height / CGFloat(cells)
                    )
                    grid.append(path.contains(probe, eoFill: true))
                }
            }
            return grid
        }

        let grids = Prayer.allCases.map { ($0, occupancy($0)) }
        for i in 0..<grids.count {
            for j in (i + 1)..<grids.count {
                let disagreement = zip(grids[i].1, grids[j].1).count { $0 != $1 }
                let fraction = Double(disagreement) / Double(cells * cells)
                #expect(
                    fraction >= 0.10,
                    "\(grids[i].0) and \(grids[j].0) silhouettes differ on only \(Int(fraction * 100))% of cells at 16pt"
                )
            }
        }
    }

    /// Every ornament must put actual ink on the plate at 16 pt — a
    /// silhouette so sparse it verges on invisible would trivially
    /// "differ" from everything.
    @Test(arguments: Prayer.allCases)
    func silhouetteHasSubstanceAt16pt(prayer: Prayer) {
        let cells = 16
        let rect = CGRect(x: 0, y: 0, width: 16, height: 16)
        let path = PrayerOrnamentShape(prayer: prayer, mode: .filled).path(in: rect)
        var filled = 0
        for row in 0..<cells {
            for column in 0..<cells {
                let probe = CGPoint(
                    x: (CGFloat(column) + 0.5) * rect.width / CGFloat(cells),
                    y: (CGFloat(row) + 0.5) * rect.height / CGFloat(cells)
                )
                if path.contains(probe, eoFill: true) { filled += 1 }
            }
        }
        let fraction = Double(filled) / Double(cells * cells)
        #expect(fraction >= 0.08, "\(prayer) fills only \(Int(fraction * 100))% of its 16pt frame")
        #expect(fraction <= 0.85, "\(prayer) fills \(Int(fraction * 100))% — reads as a blob, not linework")
    }
}
