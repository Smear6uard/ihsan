import XCTest

/// The screenshot harness.
///
/// Every phase gate in the ship pass owes a picture. Rather than
/// driving the simulator by hand, each frame is one launch with the
/// debug arguments that put the app in the state being shown, followed
/// by one full-screen capture written to the simulator's tmp directory
/// — which the host reads at
/// `~/Library/Developer/CoreSimulator/Devices/<udid>/data/tmp/ihsan-gallery`.
///
/// The frames double as the App Store screenshot set (Phase 8): they
/// come from the real app on real data, never a mockup.
final class GalleryCaptureUITests: XCTestCase {

    /// One frame: a name, the launch arguments that stage it, and an
    /// optional settle time for surfaces that animate in.
    private struct Frame {
        let name: String
        let arguments: [String]
        var settle: TimeInterval = 2.5
        /// Some surfaces are taller than the screen; this scrolls to
        /// the end before the shutter so the frame shows the rest.
        var scrollsToBottom: Bool = false
    }

    private static let chicagoNight = "2026-07-30T21:40:00"
    private static let chicagoDawn = "2026-07-31T04:35:00"
    private static let chicagoAfternoon = "2026-07-30T15:10:00"

    private static let baseArguments = [
        "-IhsanDebugCompletedOnboarding",
        "-IhsanDebugResetStore"
    ]

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: - Frames

    @MainActor
    func testCaptureGallery() throws {
        let frames: [Frame] = [
            Frame(name: "01-today-night", arguments: [
                "-IhsanNowOverride", Self.chicagoNight
            ]),
            Frame(name: "02-today-dawn", arguments: [
                "-IhsanNowOverride", Self.chicagoDawn
            ]),
            Frame(name: "03-today-afternoon", arguments: [
                "-IhsanNowOverride", Self.chicagoAfternoon
            ]),
            Frame(name: "04-log-sheet", arguments: [
                "-IhsanNowOverride", Self.chicagoAfternoon,
                "-IhsanDebugPresentLogSheet"
            ], settle: 3.0),
            Frame(name: "05-path", arguments: [
                "-IhsanNowOverride", Self.chicagoNight,
                "-IhsanDebugTab", "trajectory",
                "-IhsanDebugLogPrayer", "fajr:onTime"
            ]),
            Frame(name: "06-qibla", arguments: [
                "-IhsanNowOverride", Self.chicagoNight,
                "-IhsanDebugPresentQibla"
            ], settle: 3.0),
            Frame(name: "07-repair", arguments: [
                "-IhsanNowOverride", Self.chicagoNight,
                "-IhsanDebugTab", "trajectory",
                "-IhsanDebugPresentRepair"
            ], settle: 3.0),
            Frame(name: "08-set", arguments: [
                "-IhsanNowOverride", Self.chicagoNight,
                "-IhsanDebugTab", "settings"
            ]),
            Frame(name: "09-calculation-method", arguments: [
                "-IhsanNowOverride", Self.chicagoNight,
                "-IhsanDebugTab", "settings",
                "-IhsanDebugSettingsRoute", "calculationMethod"
            ], settle: 3.0),
            Frame(name: "09b-adhan", arguments: [
                "-IhsanNowOverride", Self.chicagoNight,
                "-IhsanDebugTab", "settings",
                "-IhsanDebugSettingsRoute", "adhanSound"
            ], settle: 3.0),
            Frame(name: "10-reflect", arguments: [
                "-IhsanNowOverride", Self.chicagoNight,
                "-IhsanDebugTab", "reflection",
                "-IhsanDebugSeedReflections"
            ]),
            Frame(name: "12-widget-faces-night", arguments: [
                "-IhsanNowOverride", Self.chicagoNight,
                "-IhsanDebugWidgetGallery"
            ], settle: 3.0),
            Frame(name: "13-widget-faces-night-lower", arguments: [
                "-IhsanNowOverride", Self.chicagoNight,
                "-IhsanDebugWidgetGallery"
            ], settle: 3.0, scrollsToBottom: true),
            Frame(name: "14-widget-faces-dawn", arguments: [
                "-IhsanNowOverride", Self.chicagoDawn,
                "-IhsanDebugWidgetGallery"
            ], settle: 3.0),
            Frame(name: "11-dhikr", arguments: [
                "-IhsanNowOverride", Self.chicagoNight,
                "-IhsanDebugPresentDhikr"
            ], settle: 3.0)
        ]

        for frame in frames {
            capture(frame)
        }
    }

    /// The same surfaces at the largest accessibility text size, which
    /// is where truncation of meaning shows up.
    @MainActor
    func testCaptureAccessibilityTypeGallery() throws {
        let sizes = ["UICTContentSizeCategoryAccessibilityXXXL"]
        let surfaces: [Frame] = [
            Frame(name: "a5-today", arguments: ["-IhsanNowOverride", Self.chicagoNight]),
            Frame(name: "a5-log-sheet", arguments: [
                "-IhsanNowOverride", Self.chicagoAfternoon,
                "-IhsanDebugPresentLogSheet"
            ], settle: 3.0),
            Frame(name: "a5-set", arguments: [
                "-IhsanNowOverride", Self.chicagoNight,
                "-IhsanDebugTab", "settings"
            ]),
            Frame(name: "a5-calculation-method", arguments: [
                "-IhsanNowOverride", Self.chicagoNight,
                "-IhsanDebugTab", "settings",
                "-IhsanDebugSettingsRoute", "calculationMethod"
            ], settle: 3.0),
            Frame(name: "a5-reflect", arguments: [
                "-IhsanNowOverride", Self.chicagoNight,
                "-IhsanDebugTab", "reflection",
                "-IhsanDebugSeedReflections"
            ]),
            Frame(name: "a5-path", arguments: [
                "-IhsanNowOverride", Self.chicagoNight,
                "-IhsanDebugTab", "trajectory",
                "-IhsanDebugLogPrayer", "fajr:onTime"
            ])
        ]

        for size in sizes {
            for surface in surfaces {
                var frame = surface
                frame = Frame(
                    name: surface.name,
                    arguments: surface.arguments + ["-UIPreferredContentSizeCategoryName", size],
                    settle: surface.settle,
                    scrollsToBottom: surface.scrollsToBottom
                )
                capture(frame)
            }
        }
    }

    // MARK: - Capture

    @MainActor
    private func capture(_ frame: Frame) {
        let app = XCUIApplication()
        app.launchArguments = Self.baseArguments + frame.arguments
        app.launch()

        grantLocationIfAsked()

        // The tab bar is the app's "ready" signal on every tab.
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 20)
        Thread.sleep(forTimeInterval: frame.settle)

        if frame.scrollsToBottom {
            for _ in 0..<4 {
                app.swipeUp(velocity: .fast)
                Thread.sleep(forTimeInterval: 0.4)
            }
            Thread.sleep(forTimeInterval: 1.0)
        }

        write(XCUIScreen.main.screenshot(), named: frame.name)
        app.terminate()
    }

    @MainActor
    private func grantLocationIfAsked() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow While Using App"]
        if allow.waitForExistence(timeout: 5) { allow.tap() }
        let allowOnce = springboard.buttons["Allow Once"]
        if allowOnce.exists { allowOnce.tap() }
    }

    private func write(_ screenshot: XCUIScreenshot, named name: String) {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ihsan-gallery", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true
        )
        let url = directory.appendingPathComponent("\(name).png")
        do {
            try screenshot.pngRepresentation.write(to: url)
        } catch {
            XCTFail("Could not write \(name): \(error)")
        }

        // Also attach, so a failed run still carries its evidence.
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
