import XCTest

/// Pins the two retroactive entry points end to end: a passed prayer
/// logged from the plate's marker → card → sheet path, and prior
/// days logged or edited from Path's day×prayer grid — the canonical
/// way to log yesterday and earlier.
final class RetroactiveLogUITests: XCTestCase {

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        // Orientation is device state that leaks between test runs; a
        // landscape leftover pushes the sheet's commit bar offscreen.
        XCUIDevice.shared.orientation = .portrait
    }

    /// 22:00Z = 18:00 at the New York fixture — Asr's window is open,
    /// Dhuhr's has closed. The civil day is August 16, 2026.
    private static let eveningOverride = "2026-08-16T22:00:00Z"
    /// 17:30Z on the same fixture day, used for the Path tests.
    private static let middayOverride = "2026-08-16T17:30:00Z"

    private func launch(nowOverride: String, extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-IhsanDebugCompletedOnboarding",
            "-IhsanDebugResetStore",
            "-IhsanNowOverride", nowOverride,
        ] + extraArguments
        app.launch()
        allowLocationIfAsked(app)
        return app
    }

    private func allowLocationIfAsked(_ app: XCUIApplication) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow While Using App"]
        if allow.waitForExistence(timeout: 4) {
            allow.tap()
        }
        let retry = app.buttons["Continue"]
        if retry.waitForExistence(timeout: 2) {
            retry.tap()
            if allow.waitForExistence(timeout: 4) {
                allow.tap()
            }
        }
    }

    private func element(in app: XCUIApplication, labelBeginning prefix: String) -> XCUIElement {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@", prefix)
        ).firstMatch
    }

    /// "EEEE, MMMM d" for the fixture's yesterday (August 15, 2026),
    /// computed in the runner's calendar — the same calendar the app
    /// formats grid labels with.
    private var yesterdayLabelFragment: String {
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 15
        let date = Calendar.current.date(from: components)!
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }

    /// Scrolls until the element is hittable (the practice grid sits
    /// below the fold on Path).
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        var attempts = 0
        while !element.isHittable && attempts < 5 {
            app.swipeUp()
            attempts += 1
        }
    }

    // MARK: - 1. A passed prayer, from the plate

    @MainActor
    func testLoggingAPassedPrayerFromThePlate() throws {
        let app = launch(nowOverride: Self.eveningOverride)

        // The Dhuhr marker announces the passed state.
        let dhuhrMarker = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Dhuhr at' AND label CONTAINS 'passed, not logged'")
        ).firstMatch
        XCTAssertTrue(dhuhrMarker.waitForExistence(timeout: 15))
        dhuhrMarker.tap()

        // The focused card swaps to Dhuhr's window-closed state and
        // carries the log affordance; tapping it opens the sheet.
        let passedCard = element(in: app, labelBeginning: "Dhuhr prayer, window closed")
        XCTAssertTrue(passedCard.waitForExistence(timeout: 3))
        passedCard.tap()

        // The corrected truth rule: the timing axis describes when
        // the prayer was PERFORMED, not when the entry is created —
        // a closed window offers all four states, On Time included
        // (praying in the window and logging after it is the most
        // common pattern).
        let onTimeTile = app.buttons["On Time, prayed in its window"]
        XCTAssertTrue(onTimeTile.waitForExistence(timeout: 5))
        XCTAssertTrue(onTimeTile.isEnabled, "A closed window must keep On Time available.")

        let lateTile = app.buttons["Delayed, prayed late in its window"]
        XCTAssertTrue(lateTile.isEnabled)
        lateTile.tap()

        let commit = app.buttons["Log Dhuhr"]
        XCTAssertTrue(commit.waitForExistence(timeout: 3))
        commit.tap()

        XCTAssertTrue(commit.waitForNonExistence(timeout: 5))
        XCTAssertTrue(
            element(in: app, labelBeginning: "Dhuhr prayer, logged, delayed")
                .waitForExistence(timeout: 5),
            "The card must reflect the retro log."
        )
    }

    // MARK: - 2. A prior day, from Path

    @MainActor
    func testLoggingAPriorDayFromPath() throws {
        // Seed one log so Path renders its grid; yesterday's Dhuhr
        // cell stays empty.
        let app = launch(
            nowOverride: Self.middayOverride,
            extraArguments: ["-IhsanDebugLogPrayer", "fajr:onTime"]
        )

        app.tabBars.buttons["Path"].tap()

        let cell = app.buttons["Dhuhr, \(yesterdayLabelFragment), not logged"]
        XCTAssertTrue(cell.waitForExistence(timeout: 10))
        scrollTo(cell, in: app)
        cell.tap()

        // Fresh entry on a past day: the commit names the act and
        // all four tiles are live.
        let commit = app.buttons["Log Dhuhr"]
        XCTAssertTrue(commit.waitForExistence(timeout: 5))
        let qadaTile = app.buttons["Qadā, prayed after its window"]
        XCTAssertTrue(qadaTile.isEnabled, "A past day offers all four states.")
        XCTAssertTrue(app.buttons["On Time, prayed in its window"].isEnabled)

        qadaTile.tap()
        commit.tap()

        XCTAssertTrue(commit.waitForNonExistence(timeout: 5))
        XCTAssertTrue(
            app.buttons["Dhuhr, \(yesterdayLabelFragment), qadā"].waitForExistence(timeout: 5),
            "The cell must reflect the retro entry."
        )
    }

    // MARK: - 3. Editing an existing prior-day entry

    @MainActor
    func testEditingAPriorDayEntryFromPath() throws {
        let app = launch(
            nowOverride: Self.middayOverride,
            extraArguments: ["-IhsanDebugLogPrayer", "dhuhr:late:-1"]
        )

        app.tabBars.buttons["Path"].tap()

        let cell = app.buttons["Dhuhr, \(yesterdayLabelFragment), delayed"]
        XCTAssertTrue(cell.waitForExistence(timeout: 10))
        scrollTo(cell, in: app)
        cell.tap()

        // Editing: the commit says Save Changes, and the past-day
        // rule keeps every tile live.
        let save = app.buttons["Save Changes"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        let onTimeTile = app.buttons["On Time, prayed in its window"]
        XCTAssertTrue(onTimeTile.isEnabled)

        onTimeTile.tap()
        save.tap()

        XCTAssertTrue(save.waitForNonExistence(timeout: 5))
        XCTAssertTrue(
            app.buttons["Dhuhr, \(yesterdayLabelFragment), on time"].waitForExistence(timeout: 5),
            "The cell must reflect the edit."
        )
    }
}
