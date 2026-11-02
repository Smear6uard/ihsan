import XCTest

/// Pins the two retroactive entry points end to end: a passed prayer
/// logged from the plate's marker → the card's seals, and prior days
/// logged or edited from Path's day card — the canonical way to log
/// yesterday and earlier.
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
        // Today's location gate asks with "Allow location" while the
        // system has not asked yet ("Continue" was its old label).
        let retry = app.buttons.matching(
            NSPredicate(format: "label == 'Allow location' OR label == 'Continue'")
        ).firstMatch
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

    /// Scrolls until the element is hittable.
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

        // The focused card swaps to Dhuhr's window-closed state.
        let passedCard = element(in: app, labelBeginning: "Dhuhr prayer, window closed")
        XCTAssertTrue(passedCard.waitForExistence(timeout: 3))

        // The corrected truth rule: the timing axis describes when
        // the prayer was PERFORMED, not when the entry is created —
        // a closed window offers all four seals, On Time included
        // (praying in the window and logging after it is the most
        // common pattern).
        for timing in ["On Time", "Delayed", "Qadā", "Missed"] {
            XCTAssertTrue(
                app.buttons["Log as \(timing)"].waitForExistence(timeout: 5),
                "A closed window must offer \(timing)."
            )
        }
        app.buttons["Log as Delayed"].tap()

        XCTAssertTrue(
            element(in: app, labelBeginning: "Dhuhr prayer, logged, delayed")
                .waitForExistence(timeout: 5),
            "The card must reflect the retro log."
        )
    }

    /// Opens Path and moves the day card back one day, to yesterday.
    private func openYesterdayOnPath(in app: XCUIApplication) {
        app.tabBars.buttons["Path"].tap()
        let earlier = app.buttons["Earlier day"]
        XCTAssertTrue(earlier.waitForExistence(timeout: 10))
        scrollTo(earlier, in: app)
        earlier.tap()
    }

    // MARK: - 2. A prior day, from Path

    @MainActor
    func testLoggingAPriorDayFromPath() throws {
        // Seed one log so Path renders its grid; yesterday's Dhuhr
        // stays empty.
        let app = launch(
            nowOverride: Self.middayOverride,
            extraArguments: ["-IhsanDebugLogPrayer", "fajr:onTime"]
        )
        openYesterdayOnPath(in: app)

        let row = app.buttons["Dhuhr, \(yesterdayLabelFragment), no record"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        scrollTo(row, in: app)
        row.tap()

        // A past day offers all four timings, and one tap records.
        for timing in ["On Time", "Delayed", "Missed"] {
            XCTAssertTrue(app.buttons["Log as \(timing)"].waitForExistence(timeout: 5))
        }
        let qada = app.buttons["Log as Qadā"]
        XCTAssertTrue(qada.waitForExistence(timeout: 5))
        qada.tap()

        XCTAssertTrue(
            app.buttons["Dhuhr, \(yesterdayLabelFragment), qadā"].waitForExistence(timeout: 5),
            "The day card must reflect the entry."
        )
        XCTAssertTrue(
            app.staticTexts["Qadā, 1"].exists || app.otherElements["Qadā, 1"].exists,
            "The key's count must follow the entry."
        )
    }

    // MARK: - 3. Editing an existing prior-day entry

    @MainActor
    func testEditingAPriorDayEntryFromPath() throws {
        let app = launch(
            nowOverride: Self.middayOverride,
            extraArguments: ["-IhsanDebugLogPrayer", "dhuhr:late:-1"]
        )
        openYesterdayOnPath(in: app)

        let row = app.buttons["Dhuhr, \(yesterdayLabelFragment), delayed"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        scrollTo(row, in: app)
        row.tap()

        let onTime = app.buttons["Change to On Time"]
        XCTAssertTrue(onTime.waitForExistence(timeout: 5))
        onTime.tap()

        XCTAssertTrue(
            app.buttons["Dhuhr, \(yesterdayLabelFragment), on time"].waitForExistence(timeout: 5),
            "The day card must reflect the edit."
        )
    }

    // MARK: - 4. Taking it back

    @MainActor
    func testUndoRestoresThePriorDayEntry() throws {
        let app = launch(
            nowOverride: Self.middayOverride,
            extraArguments: ["-IhsanDebugLogPrayer", "dhuhr:late:-1"]
        )
        openYesterdayOnPath(in: app)

        let delayed = app.buttons["Dhuhr, \(yesterdayLabelFragment), delayed"]
        XCTAssertTrue(delayed.waitForExistence(timeout: 10))
        scrollTo(delayed, in: app)
        delayed.tap()

        let missed = app.buttons["Change to Missed"]
        XCTAssertTrue(missed.waitForExistence(timeout: 5))
        missed.tap()
        XCTAssertTrue(
            app.buttons["Dhuhr, \(yesterdayLabelFragment), missed"].waitForExistence(timeout: 5)
        )

        let undo = app.buttons["Undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 3))
        undo.tap()

        XCTAssertTrue(
            app.buttons["Dhuhr, \(yesterdayLabelFragment), delayed"].waitForExistence(timeout: 5),
            "Undo must put the record back."
        )
    }

    @MainActor
    func testRemovingAPriorDayEntryIsUndoable() throws {
        let app = launch(
            nowOverride: Self.middayOverride,
            extraArguments: ["-IhsanDebugLogPrayer", "fajr:onTime;dhuhr:late:-1"]
        )
        openYesterdayOnPath(in: app)

        let delayed = app.buttons["Dhuhr, \(yesterdayLabelFragment), delayed"]
        XCTAssertTrue(delayed.waitForExistence(timeout: 10))
        scrollTo(delayed, in: app)
        delayed.tap()

        let remove = app.buttons["Remove record"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5))
        remove.tap()
        XCTAssertTrue(
            app.buttons["Dhuhr, \(yesterdayLabelFragment), no record"].waitForExistence(timeout: 5)
        )

        app.buttons["Undo"].tap()
        XCTAssertTrue(
            app.buttons["Dhuhr, \(yesterdayLabelFragment), delayed"].waitForExistence(timeout: 5)
        )
    }
}
