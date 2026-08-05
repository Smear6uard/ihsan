import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import Testing
import UniformTypeIdentifiers
@testable import IhsanDesignSystem

/// Image pinning for widget-facing components: a face is rendered at
/// its exact widget geometry and compared against a committed
/// reference PNG, so a layout, clipping, or palette regression fails
/// here instead of reaching a lock screen.
///
/// Recording: run with `IHSAN_RECORD_SNAPSHOTS=1` in the environment
/// to (re)write the references under `__Snapshots__/`, then commit
/// them. A recording run fails deliberately so it can never pass in
/// CI. As widget faces move into the design system, each new face
/// adds its pins here — every widget size in a canonical state.
@MainActor
struct WidgetFaceSnapshotTests {

    // MARK: - Harness

    private var snapshotsDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("__Snapshots__", isDirectory: true)
    }

    private var isRecording: Bool {
        ProcessInfo.processInfo.environment["IHSAN_RECORD_SNAPSHOTS"] == "1"
    }

    /// Renders at 2× and compares against `<name>.png`. Tolerance: a
    /// pixel matches within 2/255 per channel; at most 0.1% of pixels
    /// may exceed it (sub-pixel text antialiasing drift).
    private func pin(
        _ view: some View,
        size: CGSize,
        named name: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = 2
        renderer.proposedSize = ProposedViewSize(size)
        let image = try #require(renderer.cgImage, "\(name) failed to render")

        let url = snapshotsDirectory.appendingPathComponent("\(name).png")

        if isRecording {
            try FileManager.default.createDirectory(
                at: snapshotsDirectory, withIntermediateDirectories: true
            )
            let destination = try #require(CGImageDestinationCreateWithURL(
                url as CFURL, UTType.png.identifier as CFString, 1, nil
            ))
            CGImageDestinationAddImage(destination, image, nil)
            #expect(CGImageDestinationFinalize(destination))
            Issue.record(
                "Recorded \(name).png — commit it and re-run without IHSAN_RECORD_SNAPSHOTS.",
                sourceLocation: sourceLocation
            )
            return
        }

        let reference = try #require(
            CGImageSourceCreateWithURL(url as CFURL, nil).flatMap {
                CGImageSourceCreateImageAtIndex($0, 0, nil)
            },
            "Missing reference \(name).png — record with IHSAN_RECORD_SNAPSHOTS=1.",
            sourceLocation: sourceLocation
        )

        #expect(
            reference.width == image.width && reference.height == image.height,
            "\(name): size changed — was \(reference.width)×\(reference.height), now \(image.width)×\(image.height)",
            sourceLocation: sourceLocation
        )
        guard reference.width == image.width, reference.height == image.height else { return }

        let current = try rgba(of: image)
        let recorded = try rgba(of: reference)
        var differing = 0
        for index in stride(from: 0, to: current.count, by: 4) {
            for channel in 0..<3 where
                abs(Int(current[index + channel]) - Int(recorded[index + channel])) > 2 {
                differing += 1
                break
            }
        }
        let total = current.count / 4
        let budget = max(1, total / 1000)
        #expect(
            differing <= budget,
            "\(name): \(differing) of \(total) pixels moved (budget \(budget)) — if intentional, re-record and commit.",
            sourceLocation: sourceLocation
        )
    }

    private func rgba(of image: CGImage) throws -> [UInt8] {
        let width = image.width, height = image.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        let context = try #require(CGContext(
            data: &data, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return data
    }

    // MARK: - Canonical day

    /// The canonical gallery day's marks at mid-afternoon: two logged,
    /// Asr current, two ahead — every ornament state the arc renders.
    private func afternoonModel() -> CompactPlate.Model {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        let day = calendar.date(from: DateComponents(year: 2026, month: 7, day: 30))!
        func at(_ hour: Int, _ minute: Int) -> Date {
            calendar.date(byAdding: DateComponents(hour: hour, minute: minute), to: day)!
        }
        return CompactPlate.Model(
            marks: [
                .init(prayer: .fajr, time: at(4, 10), state: .logged),
                .init(prayer: .dhuhr, time: at(12, 58), state: .logged),
                .init(prayer: .asr, time: at(16, 53), state: .current),
                .init(prayer: .maghrib, time: at(20, 11), state: .upcoming),
                .init(prayer: .isha, time: at(21, 43), state: .upcoming),
            ],
            sunrise: at(5, 42)
        )
    }

    // MARK: - Pins

    @Test
    func compactPlateMediumAfternoon() throws {
        try pin(
            CompactPlate(model: afternoonModel(), tokens: .afternoon, ornamentSize: 22),
            size: CGSize(width: 306, height: 74),
            named: "compact-plate-medium-afternoon"
        )
    }

    @Test
    func compactPlateLargeAfternoon() throws {
        try pin(
            CompactPlate(model: afternoonModel(), tokens: .afternoon, ornamentSize: 20),
            size: CGSize(width: 306, height: 54),
            named: "compact-plate-large-afternoon"
        )
    }

    /// The nightstand strip — the frame whose peak ornament used to
    /// clip; the pin holds the containment fix in place.
    @Test
    func compactPlateStandByNight() throws {
        try pin(
            CompactPlate(model: afternoonModel(), tokens: .night, ornamentSize: 17),
            size: CGSize(width: 141, height: 34),
            named: "compact-plate-standby-night"
        )
    }

    @Test
    func compactPlateMediumNight() throws {
        try pin(
            CompactPlate(model: afternoonModel(), tokens: .night, ornamentSize: 22),
            size: CGSize(width: 306, height: 74),
            named: "compact-plate-medium-night"
        )
    }
}
