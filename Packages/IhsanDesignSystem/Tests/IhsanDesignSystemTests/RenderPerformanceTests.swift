import SwiftUI
import Testing
@testable import IhsanDesignSystem

/// Host-side render-loop smoke measurement. The real budget —
/// ≤4 ms/frame on iPhone 15 Pro-class hardware — is verified on
/// device via the gallery's live `FrameTimeReadout`; this test drives
/// the same probe through `ImageRenderer` on the build host so a
/// regression that makes the draw loop an order of magnitude slower
/// fails before it ever reaches a device.
@MainActor
struct RenderPerformanceTests {

    @Test
    func celestialDrawLoopStaysWithinHostBudget() {
        let probe = FrameTimeProbe()
        for pass in 0..<20 {
            let phase = SkyPhase(unit: Double(pass) / 20.0)
            let renderer = ImageRenderer(
                content: CelestialSkyView(
                    phase: phase,
                    sunAltitudeDegrees: 55 * sin(2 * .pi * (phase.unit - 0.125)),
                    probe: probe
                )
                .frame(width: 393, height: 420)
            )
            renderer.scale = 3
            _ = renderer.cgImage
        }

        #expect(probe.sampleCount >= 10, "probe never saw the draw closure run")
        let average = probe.averageMilliseconds
        let worst = probe.maximumMilliseconds
        print(String(
            format: "🎞 celestial draw closure: avg %.3f ms, max %.3f ms over %d host frames",
            average, worst, probe.sampleCount
        ))
        // Generous host bound — the device budget is 4 ms; anything
        // near this ceiling on an M-series Mac is a broken loop.
        #expect(average < 8.0, "draw closure averaged \(average) ms on host")
    }
}
