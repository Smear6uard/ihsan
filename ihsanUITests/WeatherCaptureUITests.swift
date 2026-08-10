import XCTest

/// Captures the weather dua line in each of its four trigger states,
/// and the reader it opens — the verification frames for the weather
/// layer. Same conventions as `GalleryCaptureUITests`: one launch per
/// frame, full-screen PNG written to the simulator tmp directory
/// (`~/Library/Developer/CoreSimulator/Devices/<udid>/data/tmp/`
/// `ihsan-gallery` on the host) and attached to the result bundle.
///
/// The sky is staged with `-IhsanDebugSkyConditions`, so no network,
/// no WeatherKit provisioning, and no real rain is involved.
final class WeatherCaptureUITests: XCTestCase {

    private struct Frame {
        let name: String
        let arguments: [String]
        var settle: TimeInterval = 2.5
        /// An accessibility-label fragment that must arrive before
        /// capture — here, the dua line itself.
        var waitLabelFragment: String? = nil
        /// A labelled control to open after the wait — the line,
        /// when the frame is of the reader it opens.
        var tapLabel: String? = nil
        /// A fragment that must arrive after the tap.
        var waitAfterTapFragment: String? = nil
    }

    private static let chicagoAfternoon = "2026-07-30T15:10:00"
    private static let chicagoNight = "2026-07-30T21:40:00"

    private static let baseArguments = [
        "-IhsanDebugCompletedOnboarding",
        "-IhsanDebugResetStore",
        "-IhsanDebugEnableAdhkar"
    ]

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testCaptureWeatherDuaLines() throws {
        let frames: [Frame] = [
            Frame(
                name: "weather-line-rain",
                arguments: [
                    "-IhsanNowOverride", Self.chicagoAfternoon,
                    "-IhsanDebugSkyConditions", "rain"
                ],
                waitLabelFragment: "dua of rain"
            ),
            Frame(
                name: "weather-line-after-rain",
                arguments: [
                    "-IhsanNowOverride", Self.chicagoAfternoon,
                    "-IhsanDebugSkyConditions", "afterRain"
                ],
                waitLabelFragment: "rain has passed"
            ),
            Frame(
                name: "weather-line-wind",
                arguments: [
                    "-IhsanNowOverride", Self.chicagoAfternoon,
                    "-IhsanDebugSkyConditions", "windy.strong"
                ],
                waitLabelFragment: "wind is strong"
            ),
            Frame(
                name: "weather-line-thunder",
                arguments: [
                    "-IhsanNowOverride", Self.chicagoNight,
                    "-IhsanDebugSkyConditions", "thunderstorms"
                ],
                waitLabelFragment: "Thunder"
            ),
            Frame(
                name: "weather-reader-rain",
                arguments: [
                    "-IhsanNowOverride", Self.chicagoAfternoon,
                    "-IhsanDebugSkyConditions", "rain"
                ],
                waitLabelFragment: "dua of rain",
                tapLabel: "It is raining. The dua of rain.",
                waitAfterTapFragment: "beneficial downpour"
            ),
        ]
        for frame in frames {
            capture(frame)
        }
    }

    // MARK: - Capture

    @MainActor
    private func capture(_ frame: Frame) {
        let app = XCUIApplication()
        app.launchArguments = Self.baseArguments + frame.arguments
        app.launch()

        grantLocationIfAsked()

        _ = app.tabBars.firstMatch.waitForExistence(timeout: 20)
        let loading = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] 'Loading prayer times'"))
            .firstMatch
        let deadline = Date().addingTimeInterval(25)
        while loading.exists && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.5)
        }

        if let fragment = frame.waitLabelFragment {
            let match = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS[c] %@", fragment))
                .firstMatch
            XCTAssertTrue(
                match.waitForExistence(timeout: 20),
                "No element arrived with label containing \(fragment)"
            )
        }

        if let tapLabel = frame.tapLabel {
            let control = app.buttons[tapLabel]
            XCTAssertTrue(
                control.waitForExistence(timeout: 10),
                "Missing control labelled \(tapLabel)"
            )
            control.tap()
            if let after = frame.waitAfterTapFragment {
                let match = app.descendants(matching: .any)
                    .matching(NSPredicate(format: "label CONTAINS[c] %@", after))
                    .firstMatch
                XCTAssertTrue(
                    match.waitForExistence(timeout: 10),
                    "The reader did not open with \(after)"
                )
            }
        }

        Thread.sleep(forTimeInterval: frame.settle)
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

        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
