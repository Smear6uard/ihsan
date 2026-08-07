import XCTest

/// Drives a full remembrance set from the first item to the completion
/// moment, then a second run that proves an excused pause changes
/// nothing about the contextual Remembrance offer.
///
/// Doubles as the capture harness for the phase report: run with
/// `xcrun simctl io <udid> recordVideo` alongside and the whole flow is
/// on film.
final class AdhkarSetUITests: XCTestCase {

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    private func launch(
        extraArguments: [String],
        nowOverride: String
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-IhsanDebugCompletedOnboarding",
            "-IhsanDebugResetStore",
            "-IhsanDebugEnableAdhkar",
            "-IhsanNowOverride", nowOverride,
        ] + extraArguments
        app.launch()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow While Using App"]
        if allow.waitForExistence(timeout: 4) {
            allow.tap()
        }
        return app
    }

    /// A tap anywhere below the chrome counts. Low on the screen but
    /// clear of the ring's own accessibility element and the source
    /// button.
    @MainActor
    private func countingSurface(_ app: XCUIApplication) -> XCUICoordinate {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.55))
    }

    /// The sleep set: seven items, and its counts (1, 1, 1, 1, 33, 33,
    /// 34) make a full run tractable in a test while still exercising
    /// every ring form — unity, and two sizes of tick ring.
    @MainActor
    func testFullSetCountsThroughToTheCompletionMoment() throws {
        let app = launch(
            extraArguments: ["-IhsanDebugPresentAdhkar", "sleep"],
            nowOverride: "2026-08-02T22:30:00"
        )

        let counter = app.descendants(matching: .any)["adhkar.counter"].firstMatch
        XCTAssertTrue(counter.waitForExistence(timeout: 10), "the set did not present")

        let surface = countingSurface(app)
        // 1 + 1 + 1 + 1 + 33 + 33 + 34 — the sleep set's transmitted
        // counts. Every tap is one count; the surface advances itself
        // as each item is kept.
        let totalTaps = 1 + 1 + 1 + 1 + 33 + 33 + 34
        for _ in 0..<totalTaps {
            surface.tap()
        }

        // The completion moment: one quiet line, and the counter is
        // gone because there is nothing left to count.
        let recorded = app.staticTexts["Tonight's remembrance is recorded."].firstMatch
        XCTAssertTrue(
            recorded.waitForExistence(timeout: 6),
            "the set did not reach its completion moment"
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["adhkar.counter"].firstMatch.exists,
            "the counter outlived the set"
        )

        app.buttons["Close"].tap()
        XCTAssertFalse(recorded.waitForExistence(timeout: 3), "the set did not dismiss")
    }

    /// The per-item count is honoured exactly: an item of one is kept
    /// on the first tap and the set moves on, rather than swallowing
    /// taps into a single running total.
    @MainActor
    func testEachItemIsKeptAtItsOwnCount() throws {
        let app = launch(
            extraArguments: ["-IhsanDebugPresentAdhkar", "sleep"],
            nowOverride: "2026-08-02T22:30:00"
        )

        let counter = app.descendants(matching: .any)["adhkar.counter"].firstMatch
        XCTAssertTrue(counter.waitForExistence(timeout: 10))

        let surface = countingSurface(app)
        surface.tap()

        // Four items of one, then the thirty-threes. After four taps
        // the chrome says four are kept.
        for _ in 0..<3 { surface.tap() }
        XCTAssertTrue(
            app.staticTexts["4 of 7 counted"].waitForExistence(timeout: 4),
            "four single-count items were not each kept on one tap"
        )
    }

    /// **Hard rule: an excused pause does not suppress remembrance.**
    ///
    /// The Today screen during a pause shows the paused card instead of
    /// the focused card — and still shows the Remembrance panel's direct
    /// Begin action, which is the whole point.
    @MainActor
    func testRemembranceIsOfferedDuringAnExcusedPause() throws {
        let app = launch(
            extraArguments: ["-IhsanDebugPauseSince", "2"],
            nowOverride: "2026-08-02T06:10:00"
        )

        let offer = app.buttons["Begin Morning adhkār"]
        XCTAssertTrue(
            offer.waitForExistence(timeout: 12),
            "the morning offer vanished during an excused pause"
        )

        // …and it opens, during the pause, to a set that counts.
        offer.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["adhkar.counter"].firstMatch.waitForExistence(timeout: 6),
            "the set would not open during an excused pause"
        )
    }
}
