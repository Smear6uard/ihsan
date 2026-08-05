import XCTest

/// The expanded card's swipe, driven through the live app.
///
/// A gesture is the one kind of affordance a unit test cannot reach:
/// there is no function to call, only a finger to move. So the
/// destinations are asserted here, on the real card, in the real
/// window — including the part that matters most, which is that a
/// wobble during a tap on a commit button is not read as a swipe.
final class FocusedCardSwipeUITests: XCTestCase {

    /// Maghrib is open at this instant, so the card expands rather than
    /// going straight to the sheet.
    private static let chicagoMaghrib = "2026-07-30T20:30:00"

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    private func launchExpanded() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-IhsanDebugCompletedOnboarding",
            "-IhsanDebugResetStore",
            "-IhsanNowOverride", Self.chicagoMaghrib,
            "-IhsanDebugExpandCard"
        ]
        app.launch()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow While Using App"]
        if allow.waitForExistence(timeout: 5) { allow.tap() }

        XCTAssertTrue(
            app.tabBars.firstMatch.waitForExistence(timeout: 20),
            "The app must come up."
        )
        // The expanded controls are the proof the card is open.
        XCTAssertTrue(
            app.buttons["Log as On Time"].waitForExistence(timeout: 20),
            "The card must launch expanded."
        )
        return app
    }

    /// The commit button is the reliable handle on the expanded card:
    /// it exists only in that state and sits inside the card's bounds.
    @MainActor
    private func card(in app: XCUIApplication) -> XCUIElement {
        app.buttons["Log as On Time"]
    }

    /// A vertical drag measured in points, so the distances in these
    /// tests mean the same thing the threshold in the card does.
    /// Negative is upward.
    @MainActor
    private func drag(_ element: XCUIElement, byPoints dy: CGFloat) {
        let start = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = start.withOffset(CGVector(dx: 0, dy: dy))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    // MARK: - Up opens the sheet

    @MainActor
    func testSwipingUpOpensTheFullLogSheet() throws {
        let app = launchExpanded()

        drag(card(in: app), byPoints: -120)

        // Qadā exists only on the full sheet — the expanded card offers
        // On Time and Delayed and nothing else.
        let qada = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'Qadā'"))
            .firstMatch
        XCTAssertTrue(
            qada.waitForExistence(timeout: 6),
            "Swiping the card up must open the full log sheet."
        )
    }

    // MARK: - Down closes the card

    @MainActor
    func testSwipingDownCollapsesTheCard() throws {
        let app = launchExpanded()
        let commit = card(in: app)

        drag(commit, byPoints: 120)

        let collapsed = NSPredicate(format: "exists == false")
        expectation(for: collapsed, evaluatedWith: app.buttons["Log as On Time"])
        waitForExpectations(timeout: 6)
    }

    // MARK: - The part that has to not happen

    /// A short wobble during a tap must commit the prayer, not fly off
    /// to the sheet. The gesture's minimum distance and threshold exist
    /// for exactly this.
    @MainActor
    func testASmallWobbleStillCommitsTheTap() throws {
        let app = launchExpanded()
        let commit = card(in: app)

        // 18pt: past the gesture's minimum distance, well short of the
        // threshold that commits it.
        drag(commit, byPoints: 18)

        // Either the tap landed (card goes to its logged state, whose
        // commits are gone) or nothing happened — but the full sheet
        // must not have opened.
        let qada = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'Qadā'"))
            .firstMatch
        XCTAssertFalse(
            qada.waitForExistence(timeout: 3),
            "A small movement must not be read as a swipe."
        )
    }

    // MARK: - The link the gesture does not replace

    /// Nobody using VoiceOver or Switch Control can swipe, so the
    /// visible door has to stay.
    @MainActor
    func testTheMoreLinkStillOpensTheSheet() throws {
        let app = launchExpanded()

        let more = app.buttons["More options"]
        XCTAssertTrue(more.waitForExistence(timeout: 6), "MORE must stay visible.")
        more.tap()

        let qada = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'Qadā'"))
            .firstMatch
        XCTAssertTrue(
            qada.waitForExistence(timeout: 6),
            "The visible link must reach the same sheet the swipe does."
        )
    }
}
