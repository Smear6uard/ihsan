import XCTest

/// Real-system capture gate for the Live Activity. The fixture is
/// requested by the debug app through ActivityKit; these screenshots
/// therefore include SpringBoard's true lock-screen and Dynamic Island
/// layout, not an in-app imitation.
final class LiveActivityCaptureUITests: XCTestCase {
    private let app = XCUIApplication()
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCapturePrimarySystemPresentations() throws {
        launchFixture(mode: "active")
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 1.5)
        write(XCUIScreen.main.screenshot(), named: "live-activity-compact")

        let island = springboard.coordinate(
            withNormalizedOffset: CGVector(dx: 0.5, dy: 0.04)
        )
        island.press(forDuration: 1.1)
        Thread.sleep(forTimeInterval: 1.0)
        write(XCUIScreen.main.screenshot(), named: "live-activity-expanded")

        // Collapse, then pull down Notification Center — the simulator's
        // lock-screen presentation surface.
        springboard.coordinate(
            withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)
        ).tap()
        let pullStart = springboard.coordinate(
            withNormalizedOffset: CGVector(dx: 0.08, dy: 0.01)
        )
        let pullEnd = springboard.coordinate(
            withNormalizedOffset: CGVector(dx: 0.08, dy: 0.76)
        )
        pullStart.press(forDuration: 0.1, thenDragTo: pullEnd)
        Thread.sleep(forTimeInterval: 1.0)

        // iOS asks once, on the activity surface itself. Accept before
        // recording the lock-screen artifact so the permission UI never
        // obscures or falsely constrains the presentation under test.
        let allowLiveActivities = springboard.buttons["Allow"]
        if allowLiveActivities.waitForExistence(timeout: 1.0) {
            allowLiveActivities.tap()
            Thread.sleep(forTimeInterval: 1.0)
        }
        write(XCUIScreen.main.screenshot(), named: "live-activity-lock-screen")

    }

    @MainActor
    private func launchFixture(mode: String) {
        app.terminate()
        app.launchArguments = [
            "-IhsanDebugCompletedOnboarding",
            "-IhsanDebugLiveActivity", mode
        ]
        app.launch()
        Thread.sleep(forTimeInterval: 2.0)
    }

    private func write(_ screenshot: XCUIScreenshot, named name: String) {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ihsan-live-activity", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
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
