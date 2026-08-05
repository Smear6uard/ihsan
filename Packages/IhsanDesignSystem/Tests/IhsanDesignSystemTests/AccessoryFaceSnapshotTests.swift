import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import Testing
import UniformTypeIdentifiers
@testable import IhsanDesignSystem

/// Pins for the lock-screen accessory faces.
///
/// Accessories ship into vibrant material, which strips colour — so
/// every face is pinned as white forms on darkness (the luminance the
/// material keeps), and the two glanceable ones are additionally
/// pinned over a deliberately busy ground: if an ornament survives
/// the busy pin as a readable form, it survives a photo wallpaper.
@MainActor
struct AccessoryFaceSnapshotTests {

    // MARK: - Harness (shared shape with WidgetFaceSnapshotTests)

    private var snapshotsDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("__Snapshots__", isDirectory: true)
    }

    private var isRecording: Bool {
        ProcessInfo.processInfo.environment["IHSAN_RECORD_SNAPSHOTS"] == "1"
    }

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
            "\(name): size changed",
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
            "\(name): \(differing) of \(total) pixels moved (budget \(budget)) — if intentional, re-record.",
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

    // MARK: - Grounds

    /// The vibrant-material stand-in: white forms on near-black.
    private func onVibrant(_ face: some View, size: CGSize) -> some View {
        ZStack {
            Color(white: 0.08)
            face.foregroundStyle(.white).padding(6)
        }
        .frame(width: size.width, height: size.height)
        .environment(\.colorScheme, .dark)
    }

    /// A deliberately busy ground: seeded high-contrast patches, the
    /// photographic-wallpaper worst case.
    private func onBusyGround(_ face: some View, size: CGSize) -> some View {
        var seed: UInt64 = 0x5DEE_CE66_D1CE_5EED
        func next() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double((seed >> 33) & 0xFFFF) / Double(0xFFFF)
        }
        let patches: [(x: Double, y: Double, r: Double, w: Double)] = (0..<40).map { _ in
            (next(), next(), 0.05 + next() * 0.2, next())
        }
        return ZStack {
            Canvas { context, canvasSize in
                context.fill(
                    Path(CGRect(origin: .zero, size: canvasSize)),
                    with: .color(Color(white: 0.35))
                )
                for patch in patches {
                    let rect = CGRect(
                        x: patch.x * canvasSize.width,
                        y: patch.y * canvasSize.height,
                        width: patch.r * canvasSize.width,
                        height: patch.r * canvasSize.width
                    )
                    context.fill(Path(ellipseIn: rect), with: .color(Color(white: patch.w)))
                }
            }
            // The material's own dimming layer, approximated.
            Color.black.opacity(0.35)
            face.foregroundStyle(.white).padding(6)
        }
        .frame(width: size.width, height: size.height)
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Fixtures

    private func chicago(_ hour: Int, _ minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        let day = calendar.date(from: DateComponents(year: 2026, month: 7, day: 30))!
        return calendar.date(byAdding: DateComponents(hour: hour, minute: minute), to: day)!
    }

    private var daySlots: [WidgetDayModel.Slot] {
        [
            .init(prayer: .fajr, time: chicago(4, 10), state: .logged),
            .init(prayer: .dhuhr, time: chicago(12, 58), state: .logged),
            .init(prayer: .asr, time: chicago(16, 53), state: .current),
            .init(prayer: .maghrib, time: chicago(20, 11), state: .upcoming),
            .init(prayer: .isha, time: chicago(21, 43), state: .upcoming),
        ]
    }

    private var night: WidgetNightModel {
        WidgetNightModel(
            start: chicago(20, 11),
            end: chicago(28, 11),
            nisfAlLayl: chicago(24, 11),
            lastThirdStart: chicago(25, 31)
        )
    }

    private var fasting: WidgetFastingModel {
        WidgetFastingModel(
            suhoorEnds: chicago(4, 10), iftar: chicago(20, 11), isRamadan: true
        )
    }

    private let circular = CGSize(width: 60, height: 60)
    private let rectangular = CGSize(width: 172, height: 76)

    // MARK: - Pins

    @Test
    func nextPrayerCircular() throws {
        try pin(
            onVibrant(
                AccessoryNextPrayerFace(
                    prayer: .isha, time: chicago(21, 43),
                    timeZoneIdentifier: "America/Chicago", isCurrent: false
                ),
                size: circular
            ),
            size: circular,
            named: "accessory-next-prayer-circular"
        )
    }

    @Test
    func nextPrayerCircularOnBusyGround() throws {
        try pin(
            onBusyGround(
                AccessoryNextPrayerFace(
                    prayer: .isha, time: chicago(21, 43),
                    timeZoneIdentifier: "America/Chicago", isCurrent: false
                ),
                size: circular
            ),
            size: circular,
            named: "accessory-next-prayer-circular-busy"
        )
    }

    @Test
    func windowGaugeInGap() throws {
        try pin(
            onVibrant(
                AccessoryWindowGaugeFace(prayer: .dhuhr, window: nil, isCurrent: false),
                size: circular
            ),
            size: circular,
            named: "accessory-window-gauge-gap"
        )
    }

    @Test
    func nowNextRectangular() throws {
        try pin(
            onVibrant(
                AccessoryNowNextFace(
                    current: .asr, next: .maghrib, nextTime: chicago(20, 11),
                    timeZoneIdentifier: "America/Chicago"
                ),
                size: rectangular
            ),
            size: rectangular,
            named: "accessory-now-next"
        )
    }

    @Test
    func dayRowRectangular() throws {
        try pin(
            onVibrant(
                AccessoryDayRowFace(slots: daySlots, timeZoneIdentifier: "America/Chicago"),
                size: rectangular
            ),
            size: rectangular,
            named: "accessory-day-row"
        )
    }

    @Test
    func dayRowOnBusyGround() throws {
        try pin(
            onBusyGround(
                AccessoryDayRowFace(slots: daySlots, timeZoneIdentifier: "America/Chicago"),
                size: rectangular
            ),
            size: rectangular,
            named: "accessory-day-row-busy"
        )
    }

    @Test
    func nightFaceInLastThird() throws {
        try pin(
            onVibrant(
                AccessoryNightFace(
                    night: night, date: chicago(26, 0),
                    timeZoneIdentifier: "America/Chicago"
                ),
                size: rectangular
            ),
            size: rectangular,
            named: "accessory-night-last-third"
        )
    }

    @Test
    func nightFaceBeforeNisf() throws {
        try pin(
            onVibrant(
                AccessoryNightFace(
                    night: night, date: chicago(22, 30),
                    timeZoneIdentifier: "America/Chicago"
                ),
                size: rectangular
            ),
            size: rectangular,
            named: "accessory-night-early"
        )
    }

    @Test
    func nightFaceDayPreview() throws {
        try pin(
            onVibrant(
                AccessoryNightFace(
                    night: night, date: chicago(15, 0),
                    timeZoneIdentifier: "America/Chicago"
                ),
                size: rectangular
            ),
            size: rectangular,
            named: "accessory-night-day-preview"
        )
    }

    @Test
    func fastingRectangular() throws {
        try pin(
            onVibrant(
                AccessoryFastingRectFace(
                    fasting: fasting, date: chicago(15, 0),
                    timeZoneIdentifier: "America/Chicago"
                ),
                size: rectangular
            ),
            size: rectangular,
            named: "accessory-fasting-rect"
        )
    }
}
