import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import IhsanDesignSystem

/// Host-side render-cost measurement for the widget faces.
///
/// WidgetKit gives an extension a small memory ceiling and archives
/// each entry's view — a face that is slow or heavy to render burns
/// timeline budget for every entry of every widget. This measures the
/// full ImageRenderer cost of the two heaviest faces on the host and
/// bounds it generously; the printed numbers travel to the PR so the
/// device measurement has a baseline to compare against.
@MainActor
struct WidgetFacePerformanceTests {

    private func day(fasting: Bool = false) -> WidgetDayModel {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        let base = calendar.date(from: DateComponents(year: 2026, month: 7, day: 30))!
        func at(_ hour: Int, _ minute: Int) -> Date {
            calendar.date(byAdding: DateComponents(hour: hour, minute: minute), to: base)!
        }
        let date = at(15, 10)
        return WidgetDayModel(
            date: date,
            slots: [
                .init(prayer: .fajr, time: at(4, 10), state: .logged),
                .init(prayer: .dhuhr, time: at(12, 58), state: .logged),
                .init(prayer: .asr, time: at(16, 53), state: .current),
                .init(prayer: .maghrib, time: at(20, 11), state: .upcoming),
                .init(prayer: .isha, time: at(21, 43), state: .upcoming),
            ],
            nextPrayer: .asr,
            nextTime: at(16, 53),
            countdown: date...at(16, 53),
            currentPrayer: .asr,
            currentWindow: at(16, 53)...at(20, 11),
            sunrise: at(5, 42),
            cityName: "Madinah",
            timeZoneIdentifier: "America/Chicago",
            isPaused: false,
            hijri: WidgetHijriModel(
                day: 13, monthName: "Safar", year: 1448,
                significantLine: nil, isRamadan: false
            ),
            fasting: fasting
                ? WidgetFastingModel(suhoorEnds: at(4, 10), iftar: at(20, 11), isRamadan: true)
                : nil,
            night: WidgetNightModel(
                start: at(20, 11), end: at(28, 11),
                nisfAlLayl: at(24, 11), lastThirdStart: at(25, 31)
            )
        )
    }

    private func measureRender(
        _ view: some View, size: CGSize, name: String
    ) -> (average: Double, worst: Double) {
        // Warm once — SwiftUI's first render pays one-time costs.
        let warm = ImageRenderer(
            content: view.frame(width: size.width, height: size.height)
        )
        warm.scale = 2
        _ = warm.cgImage

        var samples: [Double] = []
        for _ in 0..<12 {
            let start = ContinuousClock.now
            let renderer = ImageRenderer(
                content: view.frame(width: size.width, height: size.height)
            )
            renderer.scale = 2
            _ = renderer.cgImage
            let elapsed = ContinuousClock.now - start
            samples.append(Double(elapsed.components.attoseconds) / 1e15) // ms
        }
        let average = samples.reduce(0, +) / Double(samples.count)
        let worst = samples.max() ?? 0
        print("[WidgetFacePerf] \(name): avg \(String(format: "%.2f", average)) ms, worst \(String(format: "%.2f", worst)) ms over \(samples.count) renders")
        return (average, worst)
    }

    @Test
    func plateFaceRendersInsideItsBudget() {
        let tokens = SkyPaletteTokens.afternoon
        let face = ZStack {
            WidgetSkyGround(tokens: tokens)
            PlateFace(model: day(), tokens: tokens).padding(16)
        }
        let cost = measureRender(
            face, size: CGSize(width: 364, height: 382), name: "PlateFace/large"
        )
        // Generous host bound; on device WidgetKit archives once per
        // entry, so even the worst sample leaves headroom in a
        // multi-second budget.
        #expect(cost.average < 150, "plate render got expensive: \(cost.average) ms")
    }

    @Test
    func dayStripFaceRendersInsideItsBudget() {
        let tokens = SkyPaletteTokens.afternoon
        let face = ZStack {
            WidgetSkyGround(tokens: tokens)
            DayStripFace(model: day(fasting: true), tokens: tokens).padding(16)
        }
        let cost = measureRender(
            face, size: CGSize(width: 364, height: 170), name: "DayStripFace/medium"
        )
        #expect(cost.average < 100, "strip render got expensive: \(cost.average) ms")
    }
}
