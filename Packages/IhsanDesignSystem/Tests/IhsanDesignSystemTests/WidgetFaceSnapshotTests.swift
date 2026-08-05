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

// MARK: - Home face fixtures and pins

extension WidgetFaceSnapshotTests {

    /// The canonical day as a face model, mid-afternoon: Asr current,
    /// two logged, two ahead.
    private func afternoonDay(
        paused: Bool = false,
        fasting: WidgetFastingModel? = nil
    ) -> WidgetDayModel {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        let day = calendar.date(from: DateComponents(year: 2026, month: 7, day: 30))!
        func at(_ hour: Int, _ minute: Int) -> Date {
            calendar.date(byAdding: DateComponents(hour: hour, minute: minute), to: day)!
        }
        let date = at(15, 10)
        return WidgetDayModel(
            date: date,
            slots: [
                .init(prayer: .fajr, time: at(4, 10), state: .logged),
                .init(prayer: .dhuhr, time: at(12, 58), state: .logged),
                .init(prayer: .asr, time: at(16, 53), state: .upcoming),
                .init(prayer: .maghrib, time: at(20, 11), state: .upcoming),
                .init(prayer: .isha, time: at(21, 43), state: .upcoming),
            ],
            nextPrayer: .asr,
            nextTime: at(16, 53),
            countdown: date...at(16, 53),
            currentPrayer: .dhuhr,
            currentWindow: at(12, 58)...at(16, 53),
            sunrise: at(5, 42),
            cityName: "Madinah",
            timeZoneIdentifier: "America/Chicago",
            isPaused: paused,
            hijri: WidgetHijriModel(
                day: 13, monthName: "Safar", year: 1448,
                significantLine: "White day · Safar 13", isRamadan: false
            ),
            fasting: fasting,
            night: WidgetNightModel(
                start: at(20, 11), end: at(28, 11),
                nisfAlLayl: at(24, 11), lastThirdStart: at(25, 31)
            )
        )
    }

    /// Late night: Isha current and logged day behind.
    private func nightDay() -> WidgetDayModel {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        let day = calendar.date(from: DateComponents(year: 2026, month: 7, day: 30))!
        func at(_ hour: Int, _ minute: Int) -> Date {
            calendar.date(byAdding: DateComponents(hour: hour, minute: minute), to: day)!
        }
        let date = at(23, 15)
        return WidgetDayModel(
            date: date,
            slots: [
                .init(prayer: .fajr, time: at(4, 10), state: .logged),
                .init(prayer: .dhuhr, time: at(12, 58), state: .logged),
                .init(prayer: .asr, time: at(16, 53), state: .logged),
                .init(prayer: .maghrib, time: at(20, 11), state: .logged),
                .init(prayer: .isha, time: at(21, 43), state: .current),
            ],
            nextPrayer: .fajr,
            nextTime: at(28, 11),
            countdown: date...at(28, 11),
            currentPrayer: .isha,
            currentWindow: at(21, 43)...at(28, 11),
            sunrise: at(5, 42),
            cityName: "Madinah",
            timeZoneIdentifier: "America/Chicago",
            isPaused: false,
            hijri: WidgetHijriModel(
                day: 13, monthName: "Safar", year: 1448,
                significantLine: nil, isRamadan: false
            ),
            fasting: nil,
            night: WidgetNightModel(
                start: at(20, 11), end: at(28, 11),
                nisfAlLayl: at(24, 11), lastThirdStart: at(25, 31)
            )
        )
    }

    private func onGround(
        _ face: some View, tokens: SkyPaletteTokens, size: CGSize
    ) -> some View {
        ZStack {
            WidgetSkyGround(tokens: tokens)
            face.padding(14)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    @Test
    func nextPrayerFaceSmallAfternoon() throws {
        let tokens = SkyPaletteTokens.afternoon
        try pin(
            onGround(
                NextPrayerFace(model: afternoonDay(), tokens: tokens),
                tokens: tokens,
                size: CGSize(width: 158, height: 158)
            ),
            size: CGSize(width: 158, height: 158),
            named: "next-prayer-face-afternoon"
        )
    }

    @Test
    func nextPrayerFaceSmallNight() throws {
        let tokens = SkyPaletteTokens.night
        try pin(
            onGround(
                NextPrayerFace(model: nightDay(), tokens: tokens),
                tokens: tokens,
                size: CGSize(width: 158, height: 158)
            ),
            size: CGSize(width: 158, height: 158),
            named: "next-prayer-face-night"
        )
    }

    @Test
    func hijriDayFaceAfternoon() throws {
        let tokens = SkyPaletteTokens.afternoon
        let hijri = WidgetHijriModel(
            day: 13, monthName: "Safar", year: 1448,
            significantLine: "White day · Safar 13", isRamadan: false
        )
        try pin(
            onGround(
                HijriDayFace(hijri: hijri, tokens: tokens),
                tokens: tokens,
                size: CGSize(width: 158, height: 158)
            ),
            size: CGSize(width: 158, height: 158),
            named: "hijri-day-face-afternoon"
        )
    }

    @Test
    func dayStripFaceAfternoon() throws {
        let tokens = SkyPaletteTokens.afternoon
        try pin(
            onGround(
                DayStripFace(model: afternoonDay(), tokens: tokens),
                tokens: tokens,
                size: CGSize(width: 338, height: 158)
            ),
            size: CGSize(width: 338, height: 158),
            named: "day-strip-face-afternoon"
        )
    }

    @Test
    func dayStripFaceFasting() throws {
        let tokens = SkyPaletteTokens.afternoon
        let day = afternoonDay(fasting: WidgetFastingModel(
            suhoorEnds: afternoonDay().sunrise.addingTimeInterval(-5_520),
            iftar: afternoonDay().slots[3].time,
            isRamadan: true
        ))
        try pin(
            onGround(
                DayStripFace(model: day, tokens: tokens),
                tokens: tokens,
                size: CGSize(width: 338, height: 158)
            ),
            size: CGSize(width: 338, height: 158),
            named: "day-strip-face-fasting"
        )
    }

    @Test
    func plateFaceAfternoon() throws {
        let tokens = SkyPaletteTokens.afternoon
        try pin(
            onGround(
                PlateFace(model: afternoonDay(), tokens: tokens),
                tokens: tokens,
                size: CGSize(width: 338, height: 354)
            ),
            size: CGSize(width: 338, height: 354),
            named: "plate-face-afternoon"
        )
    }

    @Test
    func plateFaceNight() throws {
        let tokens = SkyPaletteTokens.night
        try pin(
            onGround(
                PlateFace(model: nightDay(), tokens: tokens),
                tokens: tokens,
                size: CGSize(width: 338, height: 354)
            ),
            size: CGSize(width: 338, height: 354),
            named: "plate-face-night"
        )
    }
}

// MARK: - Accented (tinted/clear) hierarchy pins

extension WidgetFaceSnapshotTests {
    /// Accented faces render on the system's material, not our sky;
    /// the pin stands them on neutral slate so the chosen hierarchy —
    /// ornaments and primary figures forward, secondary text behind,
    /// no painted ground — is what regresses, not a wallpaper.
    private func onSlate(_ face: some View, size: CGSize) -> some View {
        ZStack {
            Color(red: 0.16, green: 0.16, blue: 0.18)
            face.padding(14)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .environment(\.colorScheme, .dark)
    }

    @Test
    func nextPrayerFaceAccented() throws {
        try pin(
            onSlate(
                NextPrayerFace(
                    model: afternoonDay(),
                    tokens: .afternoon,
                    mode: .accented
                ),
                size: CGSize(width: 158, height: 158)
            ),
            size: CGSize(width: 158, height: 158),
            named: "next-prayer-face-accented"
        )
    }

    @Test
    func dayStripFaceAccented() throws {
        try pin(
            onSlate(
                DayStripFace(
                    model: afternoonDay(),
                    tokens: .afternoon,
                    mode: .accented
                ),
                size: CGSize(width: 338, height: 158)
            ),
            size: CGSize(width: 338, height: 158),
            named: "day-strip-face-accented"
        )
    }

    @Test
    func plateFaceAccented() throws {
        try pin(
            onSlate(
                PlateFace(
                    model: afternoonDay(),
                    tokens: .afternoon,
                    mode: .accented
                ),
                size: CGSize(width: 338, height: 354)
            ),
            size: CGSize(width: 338, height: 354),
            named: "plate-face-accented"
        )
    }

    @Test
    func hijriDayFaceAccented() throws {
        let hijri = WidgetHijriModel(
            day: 13, monthName: "Safar", year: 1448,
            significantLine: "White day · Safar 13", isRamadan: false
        )
        try pin(
            onSlate(
                HijriDayFace(hijri: hijri, tokens: .afternoon, mode: .accented),
                size: CGSize(width: 158, height: 158)
            ),
            size: CGSize(width: 158, height: 158),
            named: "hijri-day-face-accented"
        )
    }
}

// MARK: - Remaining gallery states

extension WidgetFaceSnapshotTests {
    @Test
    func dayStripFaceNight() throws {
        let tokens = SkyPaletteTokens.night
        try pin(
            onGround(
                DayStripFace(model: nightDay(), tokens: tokens),
                tokens: tokens,
                size: CGSize(width: 338, height: 158)
            ),
            size: CGSize(width: 338, height: 158),
            named: "day-strip-face-night"
        )
    }

    @Test
    func plateFaceFasting() throws {
        let tokens = SkyPaletteTokens.afternoon
        let base = afternoonDay()
        let day = afternoonDay(fasting: WidgetFastingModel(
            suhoorEnds: base.sunrise.addingTimeInterval(-5_520),
            iftar: base.slots[3].time,
            isRamadan: true
        ))
        try pin(
            onGround(
                PlateFace(model: day, tokens: tokens),
                tokens: tokens,
                size: CGSize(width: 338, height: 354)
            ),
            size: CGSize(width: 338, height: 354),
            named: "plate-face-fasting"
        )
    }

    /// The paused strip: times whole, no status inscriptions, every
    /// mark in the neutral outline it wears ahead of time.
    @Test
    func dayStripFacePaused() throws {
        let tokens = SkyPaletteTokens.afternoon
        let base = afternoonDay(paused: true)
        let neutralized = WidgetDayModel(
            date: base.date,
            slots: base.slots.map {
                WidgetDayModel.Slot(
                    prayer: $0.prayer,
                    time: $0.time,
                    state: $0.state == .passedUnlogged ? .upcoming : $0.state
                )
            },
            nextPrayer: base.nextPrayer,
            nextTime: base.nextTime,
            countdown: base.countdown,
            currentPrayer: base.currentPrayer,
            currentWindow: base.currentWindow,
            sunrise: base.sunrise,
            cityName: base.cityName,
            timeZoneIdentifier: base.timeZoneIdentifier,
            isPaused: true,
            hijri: base.hijri,
            fasting: nil,
            night: base.night
        )
        try pin(
            onGround(
                DayStripFace(model: neutralized, tokens: tokens),
                tokens: tokens,
                size: CGSize(width: 338, height: 158)
            ),
            size: CGSize(width: 338, height: 158),
            named: "day-strip-face-paused"
        )
    }

    /// The no-blank-state guarantee, screenshotted: the invitation on
    /// the day's sky.
    @Test
    func invitationFace() throws {
        let tokens = SkyPaletteTokens.afternoon
        let invitation = VStack(alignment: .leading, spacing: 8) {
            Text("Open Ihsan")
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .foregroundStyle(tokens.ink)
            Text("to refresh today's times")
                .font(IhsanFont.inscription)
                .tracking(0.6)
                .foregroundStyle(tokens.inkSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        try pin(
            onGround(invitation, tokens: tokens, size: CGSize(width: 158, height: 158)),
            size: CGSize(width: 158, height: 158),
            named: "invitation-face"
        )
    }
}
