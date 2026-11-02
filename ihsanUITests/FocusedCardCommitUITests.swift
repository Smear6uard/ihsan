import XCTest

/// The card that records, driven through the live app.
///
/// Every recording on Today happens on the focused card in one tap, and
/// every recording can be taken back in one tap. These are the paths a
/// unit test cannot reach — a finger on a seal, the record arriving
/// through the funnel and the @Query, Undo putting it back — asserted
/// on the real card in the real window.
final class FocusedCardCommitUITests: XCTestCase {

    /// 4 PM on the device clock (Chicago) is 21:00Z: Dhuhr's window is
    /// open whether the simulator stands in Chicago or San Francisco,
    /// so nothing here depends on one city's table.
    private static let dhuhrOpen = "2026-07-30T16:00:00"

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    private func launch(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-IhsanDebugCompletedOnboarding",
            "-IhsanDebugResetStore",
            "-IhsanNowOverride", Self.dhuhrOpen
        ] + extra
        app.launch()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow While Using App"]
        if allow.waitForExistence(timeout: 5) { allow.tap() }

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 20), "The app must come up.")
        return app
    }

    /// The chip carries the toggle trait, so XCUITest files it as a
    /// switch, not a button — match it by label across every type.
    @MainActor
    private func jamaahChip(in app: XCUIApplication) -> XCUIElement {
        element(in: app, labelBeginning: "In Jam")
    }

    @MainActor
    private func element(in app: XCUIApplication, labelBeginning prefix: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", prefix))
            .firstMatch
    }

    // MARK: - One tap records, one tap takes it back

    @MainActor
    func testOneTapRecordsAndUndoPutsItBack() throws {
        let app = launch()

        // An open window offers exactly its two in-window seals.
        let onTime = app.buttons["Log as On Time"]
        XCTAssertTrue(onTime.waitForExistence(timeout: 20), "The open window must offer On Time on the card.")
        XCTAssertTrue(app.buttons["Log as Delayed"].exists)
        XCTAssertFalse(app.buttons["Log as Qadā"].exists, "Qadā is after the window, which is still open.")

        onTime.tap()

        XCTAssertTrue(
            element(in: app, labelBeginning: "Dhuhr prayer, logged, on time").waitForExistence(timeout: 5),
            "One tap must record the prayer."
        )
        let undo = app.buttons["Undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 3), "Undo must be offered after a recording.")
        undo.tap()

        XCTAssertTrue(
            app.buttons["Log as On Time"].waitForExistence(timeout: 5),
            "Undo must put the prayer back to unrecorded."
        )
    }

    @MainActor
    func testUndoIsOnlyOfferedForAFewSeconds() throws {
        let app = launch()
        let onTime = app.buttons["Log as On Time"]
        XCTAssertTrue(onTime.waitForExistence(timeout: 20))
        onTime.tap()

        let undo = app.buttons["Undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 3))
        XCTAssertTrue(undo.waitForNonExistence(timeout: 10), "Undo must step back after a few seconds.")
        XCTAssertTrue(
            element(in: app, labelBeginning: "Dhuhr prayer, logged, on time").exists,
            "The record stays once Undo has gone."
        )
    }

    // MARK: - Jamāʿah, after the fact

    @MainActor
    func testJamaahIsSetAfterTheCommitInOneTap() throws {
        let app = launch()
        let onTime = app.buttons["Log as On Time"]
        XCTAssertTrue(onTime.waitForExistence(timeout: 20))
        onTime.tap()

        let chip = jamaahChip(in: app)
        XCTAssertTrue(chip.waitForExistence(timeout: 5), "A recorded prayer carries its jamāʿah chip.")
        chip.tap()

        let recorded = app.descendants(matching: .any).matching(NSPredicate(
            format: "label BEGINSWITH 'Dhuhr prayer, logged' AND label CONTAINS[c] 'in jam'"
        )).firstMatch
        XCTAssertTrue(recorded.waitForExistence(timeout: 5), "The chip must apply jamāʿah at once.")
    }

    // MARK: - Changing and removing, in place

    @MainActor
    func testARecordChangesInPlace() throws {
        let app = launch(extra: ["-IhsanDebugLogPrayer", "dhuhr:onTime"])

        let recorded = element(in: app, labelBeginning: "Dhuhr prayer, logged, on time")
        XCTAssertTrue(recorded.waitForExistence(timeout: 20))
        recorded.tap()

        let delayed = app.buttons["Change to Delayed"]
        XCTAssertTrue(delayed.waitForExistence(timeout: 5), "Tapping the record opens its change on the card.")
        delayed.tap()

        XCTAssertTrue(
            element(in: app, labelBeginning: "Dhuhr prayer, logged, delayed").waitForExistence(timeout: 5),
            "The change must land on the record."
        )
    }

    @MainActor
    func testARecordCanBeRemovedAndRestored() throws {
        let app = launch(extra: ["-IhsanDebugLogPrayer", "dhuhr:late"])

        let recorded = element(in: app, labelBeginning: "Dhuhr prayer, logged, delayed")
        XCTAssertTrue(recorded.waitForExistence(timeout: 20))
        recorded.tap()

        let remove = app.buttons["Remove record"].firstMatch
        XCTAssertTrue(remove.waitForExistence(timeout: 5))
        remove.tap()

        XCTAssertTrue(
            app.buttons["Log as On Time"].waitForExistence(timeout: 5),
            "Removing must leave the prayer unrecorded."
        )
        let undo = app.buttons["Undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 3))
        undo.tap()

        XCTAssertTrue(
            element(in: app, labelBeginning: "Dhuhr prayer, logged, delayed").waitForExistence(timeout: 5),
            "Undo must restore the record exactly as it was."
        )
    }

    // MARK: - A closed window

    @MainActor
    func testAClosedWindowOffersAllFourAndMissedTakesNoJamaah() throws {
        let app = launch(extra: ["-IhsanDebugFocusPrayer", "fajr"])

        for timing in ["On Time", "Delayed", "Qadā", "Missed"] {
            XCTAssertTrue(
                app.buttons["Log as \(timing)"].waitForExistence(timeout: 20),
                "A closed window must offer \(timing)."
            )
        }
        app.buttons["Log as Missed"].tap()

        XCTAssertTrue(
            element(in: app, labelBeginning: "Fajr prayer, logged, missed").waitForExistence(timeout: 5)
        )
        XCTAssertFalse(
            jamaahChip(in: app).waitForExistence(timeout: 2),
            "A prayer not offered was not offered in congregation."
        )
    }

    // MARK: - The drawer is gone

    /// The card used to be a drawer: a swipe up summoned a separate
    /// sheet. Nothing hides behind a gesture now — a swipe on the card
    /// does nothing, and no sheet exists to arrive.
    @MainActor
    func testNoSheetHidesBehindTheCard() throws {
        let app = launch()
        let onTime = app.buttons["Log as On Time"]
        XCTAssertTrue(onTime.waitForExistence(timeout: 20))

        let start = onTime.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -140)))

        XCTAssertFalse(
            app.staticTexts["WHEN IT WAS PRAYED"].waitForExistence(timeout: 3),
            "No sheet may open from the card."
        )
    }
}
