import CoreGraphics
import Testing
@testable import ihsan

/// Part-B item 8: plate, ground, and focused card read as one page —
/// no dead zone taller than the focused card itself.
@Suite("Today composition metrics")
struct TodayCompositionMetricsTests {

    private func metrics(
        size: CGSize,
        top: CGFloat,
        bottom: CGFloat,
        duha: Bool = false
    ) -> TodayCompositionMetrics {
        TodayCompositionMetrics(
            size: size,
            safeAreaTop: top,
            safeAreaBottom: bottom,
            cardHeight: 140,
            hasDuhaCard: duha
        )
    }

    @Test
    func chordToCardGapNeverExceedsTheCardHeight() {
        // iPhone 17 Pro-class, iPhone Air-class, and a compact device.
        let devices: [(CGSize, CGFloat, CGFloat)] = [
            (CGSize(width: 402, height: 874), 62, 34),
            (CGSize(width: 420, height: 912), 62, 34),
            (CGSize(width: 375, height: 667), 20, 0)
        ]
        for (size, top, bottom) in devices {
            for duha in [false, true] {
                let m = metrics(size: size, top: top, bottom: bottom, duha: duha)
                #expect(
                    m.chordToCardGap <= m.cardHeight,
                    "dead zone \(m.chordToCardGap) exceeds card \(m.cardHeight) at \(size)"
                )
                #expect(m.chordToCardGap > 0, "chord must sit above the card at \(size)")
            }
        }
    }

    @Test
    func plateKeepsItsMinimumHeight() {
        let m = metrics(size: CGSize(width: 375, height: 667), top: 20, bottom: 0, duha: true)
        #expect(m.plateHeight >= 160)
    }

    @Test
    func headerZoneIsRespected() {
        let m = metrics(size: CGSize(width: 402, height: 874), top: 62, bottom: 34)
        #expect(m.plateTopInset == 62 + TodayCompositionMetrics.headerZoneHeight)
    }
}
