import XCTest

/// The always-open door, driven end to end.
///
/// `RemembranceMenuTests` holds the composition rules. What only the
/// live app can prove is the presentation: the hub is a sheet and both
/// of its destinations are full-screen, so a destination raised while
/// the sheet is still dismissing gets dropped. That is why the chosen
/// destination is held and applied in `onDismiss`, and why this test
/// exists to catch it if anyone simplifies that away.
final class RemembranceDoorUITests: XCTestCase {

    /// Mid-afternoon: no remembrance window is open at all, which is
    /// the entire point — before the door existed, this is the moment
    /// when adhkār were unreachable.
    private static let chicagoAfternoon = "2026-07-30T15:10:00"

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-IhsanDebugCompletedOnboarding",
            "-IhsanDebugResetStore",
            "-IhsanNowOverride", Self.chicagoAfternoon
        ]
        app.launch()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow While Using App"]
        if allow.waitForExistence(timeout: 5) { allow.tap() }
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 20)
        return app
    }

    @MainActor
    private func openHub(_ app: XCUIApplication) {
        let band = app.buttons["Remembrance"]
        XCTAssertTrue(
            band.waitForExistence(timeout: 20),
            "The door must be on Today at every hour."
        )
        band.tap()
    }

    // MARK: - The door

    @MainActor
    func testOnlyOccasionBoundActionsRemainWhenNoTimeWindowIsOpen() throws {
        let app = launch()
        openHub(app)

        for name in ["After prayer", "Before sleep"] {
            let row = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label BEGINSWITH %@", name))
                .firstMatch
            XCTAssertTrue(
                row.waitForExistence(timeout: 6),
                "\(name) must remain reachable as an occasion-bound action."
            )
        }
        XCTAssertFalse(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "label BEGINSWITH 'Morning adhkār'"))
                .firstMatch.exists,
            "Morning adhkār must be absent after its window closes."
        )
        XCTAssertFalse(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "label BEGINSWITH 'Evening adhkār'"))
                .firstMatch.exists,
            "Evening adhkār must be absent before its window opens."
        )
        XCTAssertTrue(app.buttons["Free tasbīḥ"].exists, "The instrument must be listed.")
    }

    // MARK: - Both destinations survive the dismissal

    @MainActor
    func testChoosingASetOpensItsReader() throws {
        let app = launch()
        openHub(app)

        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'After prayer'"))
            .firstMatch
            .tap()

        let counter = app.descendants(matching: .any)["adhkar.counter"].firstMatch
        XCTAssertTrue(
            counter.waitForExistence(timeout: 10),
            "The reader must survive the hub's dismissal."
        )
    }

    @MainActor
    func testChoosingFreeTasbihOpensTheInstrument() throws {
        let app = launch()
        openHub(app)

        app.buttons["Free tasbīḥ"].tap()

        let counter = app.descendants(matching: .any)["dhikr.counter"].firstMatch
        XCTAssertTrue(
            counter.waitForExistence(timeout: 10),
            "The instrument must survive the hub's dismissal."
        )
    }
}
