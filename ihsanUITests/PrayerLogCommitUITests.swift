import XCTest

/// Pins the log sheet's commit path end to end: tap commit → the log
/// lands in the store the UI reads → the sheet dismisses → the focused
/// card renders the logged state.
///
/// Both sheet paths are covered — a fresh log ("LOG PRAYER") and an
/// edit of an existing entry ("SAVE CHANGES"). The launch recipe is
/// the standard debug harness: onboarding bypass, a flowing
/// now-override anchored inside Dhuhr's window, and the sheet
/// auto-present argument.
final class PrayerLogCommitUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// 17:30Z = 13:30 EDT at the New York fixture — inside Dhuhr's
    /// window, so the On Time tile is live. Each test anchors to its
    /// OWN date: the store persists across tests in a run, and the
    /// per-day dedup key means only a unique date isolates a test
    /// from its siblings and from reruns.
    private func launch(nowOverride: String, extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-IhsanDebugCompletedOnboarding",
            "-IhsanDebugResetStore",
            "-IhsanNowOverride", nowOverride,
            "-IhsanDebugPresentLogSheet", "dhuhr",
        ] + extraArguments
        app.launch()
        allowLocationIfAsked(app)
        return app
    }

    /// The sim's TCC grant does not reliably survive relaunches, so
    /// each test answers the system location dialog itself — and taps
    /// the app's own retry affordance if the denied state rendered.
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

    /// The logged focused card exposes one combined element:
    /// "Dhuhr prayer, logged, on time". Nothing else in the app
    /// carries that label, so it is the unambiguous signal that the
    /// commit reached the store the UI reads.
    private func loggedCard(in app: XCUIApplication, contains fragment: String) -> XCUIElement {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH 'Dhuhr prayer, logged' AND label CONTAINS %@", fragment)
        ).firstMatch
    }

    @MainActor
    func testFreshCommitLogsPrayerAndUpdatesCard() throws {
        let app = launch(nowOverride: "2026-08-14T17:30:00Z")

        let onTimeTile = app.buttons["On Time, prayed in its window"]
        XCTAssertTrue(
            onTimeTile.waitForExistence(timeout: 15),
            "The log sheet should auto-present with the timing tiles."
        )
        onTimeTile.tap()

        let commit = app.buttons["Log prayer"]
        XCTAssertTrue(commit.waitForExistence(timeout: 3), "Fresh path should title the commit 'Log prayer'.")
        XCTAssertTrue(commit.isEnabled, "Choosing a timing must enable the commit.")
        commit.tap()

        // Sheet dismisses…
        XCTAssertTrue(
            commit.waitForNonExistence(timeout: 5),
            "The sheet should dismiss on commit."
        )
        // …and the card reflects the new log immediately.
        XCTAssertTrue(
            loggedCard(in: app, contains: "on time").waitForExistence(timeout: 5),
            "The focused card must render the logged state after commit."
        )
    }

    @MainActor
    func testEditingExistingLogSavesChanges() throws {
        // Seed an existing 'late' log through the standard intent
        // funnel, then edit it to on-time via the sheet.
        let app = launch(
            nowOverride: "2026-08-12T17:30:00Z",
            extraArguments: ["-IhsanDebugLogPrayer", "dhuhr:late"]
        )

        let onTimeTile = app.buttons["On Time, prayed in its window"]
        XCTAssertTrue(
            onTimeTile.waitForExistence(timeout: 15),
            "The log sheet should auto-present with the timing tiles."
        )

        let save = app.buttons["Save changes"]
        XCTAssertTrue(
            save.waitForExistence(timeout: 5),
            "Editing an existing entry should title the commit 'Save changes'."
        )

        onTimeTile.tap()
        save.tap()

        XCTAssertTrue(
            save.waitForNonExistence(timeout: 5),
            "The sheet should dismiss on commit."
        )
        XCTAssertTrue(
            loggedCard(in: app, contains: "on time").waitForExistence(timeout: 5),
            "The focused card must render the updated state after saving."
        )
    }
}
