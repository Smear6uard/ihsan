import XCTest

/// The live handoff: prayer log → numeric Khatam offer → prefilled
/// stepper → associated entry → offer recedes when today's amount is met.
final class KhatamPrayerMomentUITests: XCTestCase {
    private static let dhuhrWindow = "2026-08-14T18:30:00Z"

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testPrayerMomentPrefillsAssociatesAndRecedes() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-IhsanDebugCompletedOnboarding",
            "-IhsanDebugResetStore",
            "-IhsanNowOverride", Self.dhuhrWindow,
            "-IhsanDebugSeedKhatam", "active",
            "-IhsanDebugPresentLogSheet", "dhuhr"
        ]
        app.launch()
        allowLocationIfAsked(app)

        let onTime = app.buttons["On Time, prayed in its window"]
        XCTAssertTrue(onTime.waitForExistence(timeout: 20))
        onTime.tap()
        let logPrayer = app.buttons["Log Dhuhr"]
        XCTAssertTrue(logPrayer.waitForExistence(timeout: 3))
        XCTAssertTrue(logPrayer.isEnabled)
        logPrayer.tap()

        let offer = app.buttons["Log 4 pages after Dhuhr"]
        XCTAssertTrue(
            offer.waitForExistence(timeout: 20),
            "A logged in-window prayer should carry the active plan's per-prayer amount."
        )
        retainScreenshot(app, name: "khatam-per-prayer-offer")
        offer.tap()

        XCTAssertTrue(
            app.staticTexts["4"].waitForExistence(timeout: 5),
            "The numeric stepper should arrive prefilled with the per-prayer amount."
        )
        let daily = app.buttons["21 pages, today suggestion"]
        XCTAssertTrue(daily.waitForExistence(timeout: 3))
        daily.tap()
        app.buttons["Record"].tap()

        XCTAssertTrue(
            offer.waitForNonExistence(timeout: 6),
            "The offer should recede after today's reading amount is recorded."
        )

        app.tabBars.buttons["Path"].tap()
        let khatamCard = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Khatam'")
        ).firstMatch
        XCTAssertTrue(khatamCard.waitForExistence(timeout: 8))
        khatamCard.tap()
        XCTAssertTrue(
            app.staticTexts["AFTER DHUHR"].waitForExistence(timeout: 5),
            "The saved numeric entry should retain its prayer association."
        )
        retainScreenshot(app, name: "khatam-per-prayer-associated-entry")
    }

    @MainActor
    private func allowLocationIfAsked(_ app: XCUIApplication) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow While Using App"]
        if allow.waitForExistence(timeout: 5) { allow.tap() }
    }

    @MainActor
    private func retainScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
