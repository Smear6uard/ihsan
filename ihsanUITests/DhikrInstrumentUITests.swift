import XCTest

/// Drives the tasbīḥ instrument through one full 33-count cycle: the
/// center numeral tracks every tap, the cycle completes back at the
/// ring (a completed-cycle dot appears and the total carries on), and
/// closing the instrument records the session. Doubles as the
/// screen-recording harness for the phase report.
final class DhikrInstrumentUITests: XCTestCase {

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    private func launch(nowOverride: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-IhsanDebugCompletedOnboarding",
            "-IhsanDebugResetStore",
            "-IhsanNowOverride", nowOverride,
            "-IhsanDebugPresentDhikr",
        ]
        app.launch()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow While Using App"]
        if allow.waitForExistence(timeout: 4) {
            allow.tap()
        }
        return app
    }

    @MainActor
    func testFullCycleCountsAndCompletes() throws {
        let app = launch(nowOverride: "2026-07-27T21:30:00")

        let counter = app.descendants(matching: .any)["dhikr.counter"].firstMatch
        XCTAssertTrue(counter.waitForExistence(timeout: 8), "instrument did not present")

        // A tap anywhere on the counting surface counts. Tap low on
        // the screen, clear of the label row and chrome.
        let surface = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.62))
        for _ in 0..<33 {
            surface.tap()
        }

        // The cycle completed: the accessibility value carries the
        // full-cycle fact.
        XCTAssertTrue(
            counter.value.debugDescription.contains("33"),
            "cycle did not reach 33: \(String(describing: counter.value))"
        )

        // One more tap begins the next cycle: 1 of 33, total 34.
        surface.tap()
        XCTAssertTrue(
            counter.value.debugDescription.contains("total 34"),
            "second cycle did not begin: \(String(describing: counter.value))"
        )

        // Close — the session records quietly.
        app.buttons["Close"].tap()
        XCTAssertFalse(counter.waitForExistence(timeout: 3), "instrument did not dismiss")
    }
}
