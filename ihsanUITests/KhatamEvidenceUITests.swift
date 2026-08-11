import XCTest

/// Feature-gate recordings and stills from the real app and real SwiftData
/// store. Xcode records each test automatically; named stills are retained
/// so the final report can export the exact audited frames.
final class KhatamEvidenceUITests: XCTestCase {
    private static let ramadanDhuhr = "2026-02-27T19:00:00Z"
    private static let day = "2026-07-30T15:10:00"
    private static let night = "2026-07-30T21:40:00"

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testRamadanOfferAndSetupArithmeticAtAccessibility5() throws {
        let app = launch([
            "-IhsanDebugCompletedOnboarding",
            "-IhsanDebugResetStore",
            "-IhsanNowOverride", Self.ramadanDhuhr,
            "-IhsanDebugTab", "trajectory",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL",
        ])

        let offer = app.staticTexts["Ramadan is here — pace a reading of the Qur’an."]
        XCTAssertTrue(offer.waitForExistence(timeout: 20))
        app.buttons["khatam-ramadan-begin"].tap()
        XCTAssertTrue(app.staticTexts["Choose a period"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'This Ramadan'")
        ).firstMatch.exists)

        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["Count from your own mushaf"].waitForExistence(timeout: 5))
        app.buttons["Continue"].tap()

        let arithmetic = app.staticTexts[
            "About 20 pages a day — around 4 after each prayer."
        ]
        XCTAssertTrue(arithmetic.waitForExistence(timeout: 5))
        retainScreenshot(app, name: "khatam-setup-arithmetic-a5")

        // Beginning the offer spends it for this Ramadan even if setup is
        // closed before the plan is saved.
        app.terminate()
        app.launchArguments = [
            "-IhsanDebugCompletedOnboarding",
            "-IhsanNowOverride", Self.ramadanDhuhr,
            "-IhsanDebugTab", "trajectory",
        ]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 20))
        XCTAssertFalse(offer.waitForExistence(timeout: 3))
    }

    @MainActor
    func testSparseRecomputeCardDayAndNight() throws {
        for (name, instant) in [("day", Self.day), ("night", Self.night)] {
            let app = launch([
                "-IhsanDebugCompletedOnboarding",
                "-IhsanDebugResetStore",
                "-IhsanNowOverride", instant,
                "-IhsanDebugTab", "trajectory",
                "-IhsanDebugSeedKhatam", "sparse",
            ])
            let card = app.buttons.matching(
                NSPredicate(format: "label BEGINSWITH 'Khatam'")
            ).firstMatch
            let cardExists = card.waitForExistence(timeout: 20)
            if !cardExists {
                retainScreenshot(app, name: "khatam-sparse-card-\(name)-failure")
            }
            XCTAssertTrue(cardExists, app.debugDescription)
            var attempts = 0
            while !card.isHittable, attempts < 5 {
                app.swipeUp()
                attempts += 1
            }
            XCTAssertTrue(card.isHittable)
            XCTAssertTrue(card.label.contains("today, 27 pages"))
            // Keep the full readout above the floating tab bar in the
            // retained frame; a partially hittable card is not useful
            // visual evidence.
            let tabBarTop = app.tabBars.firstMatch.frame.minY
            while card.frame.maxY > tabBarTop - 12, attempts < 7 {
                app.swipeUp()
                attempts += 1
            }
            XCTAssertLessThanOrEqual(card.frame.maxY, tabBarTop - 12)
            retainScreenshot(app, name: "khatam-sparse-card-\(name)")
            app.terminate()
        }
    }

    @MainActor
    func testCompletionMoment() throws {
        let app = launch([
            "-IhsanDebugCompletedOnboarding",
            "-IhsanDebugResetStore",
            "-IhsanNowOverride", Self.night,
            "-IhsanDebugTab", "trajectory",
            "-IhsanDebugSeedKhatam", "complete",
            "-IhsanDebugPresentKhatam",
        ])
        let completionTitle = app.staticTexts["The reading is complete."]
        let presented = completionTitle.waitForExistence(timeout: 20)
        if !presented {
            retainScreenshot(app, name: "khatam-completion-moment-failure")
        }
        XCTAssertTrue(presented, app.debugDescription)
        XCTAssertTrue(app.buttons["Continue"].exists)
        XCTAssertTrue(app.buttons["Undo last entry"].exists)
        retainScreenshot(app, name: "khatam-completion-moment")
    }

    @MainActor
    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        allowLocationIfAsked(app)
        return app
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
