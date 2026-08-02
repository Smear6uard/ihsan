import XCTest

/// The Set group and the post-prayer path, exercised end to end.
final class AdhkarSettingsUITests: XCTestCase {

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    private func launch(
        _ extraArguments: [String],
        nowOverride: String,
        resetStore: Bool = true
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-IhsanDebugCompletedOnboarding",
            "-IhsanNowOverride", nowOverride,
        ] + (resetStore ? ["-IhsanDebugResetStore"] : []) + extraArguments
        app.launch()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow While Using App"]
        if allow.waitForExistence(timeout: 4) {
            allow.tap()
        }
        return app
    }

    /// Off by default, and the off state says nothing about what is
    /// missing: one row and one line, no list of absent features.
    @MainActor
    func testTheGroupIsOffByDefaultAndOpensItsSets() throws {
        let app = launch(["-IhsanDebugTab", "settings"], nowOverride: "2026-08-02T13:10:00")

        let master = app.switches["Adhkār and duʿāʾ"].firstMatch
        XCTAssertTrue(master.waitForExistence(timeout: 12), "the Adhkār group is missing from Set")
        XCTAssertEqual(master.value as? String, "0", "the layer is not off by default")

        // Nothing about the sets is visible while it is off.
        XCTAssertFalse(app.switches["Morning adhkār"].exists)
        XCTAssertFalse(app.switches["Before-sleep adhkār"].exists)

        master.tap()

        // Turning the layer on turns every set on; each stays its own
        // switch.
        for label in [
            "Morning adhkār", "Evening adhkār",
            "After-prayer adhkār", "Before-sleep adhkār",
            "Show transliteration",
        ] {
            let toggle = app.switches[label].firstMatch
            XCTAssertTrue(toggle.waitForExistence(timeout: 4), "\(label) did not appear")
            XCTAssertEqual(toggle.value as? String, "1", "\(label) did not come on")
        }

        // One set off is one set off.
        app.switches["Evening adhkār"].firstMatch.tap()
        XCTAssertEqual(app.switches["Evening adhkār"].firstMatch.value as? String, "0")
        XCTAssertEqual(app.switches["Morning adhkār"].firstMatch.value as? String, "1")
    }

    /// The window bounds are editable and carry neutral defaults.
    @MainActor
    func testWindowBoundsAreEditableWithNeutralDefaults() throws {
        let app = launch(
            ["-IhsanDebugTab", "settings", "-IhsanDebugEnableAdhkar"],
            nowOverride: "2026-08-02T13:10:00"
        )

        let row = app.buttons
            .containing(NSPredicate(format: "label CONTAINS[c] %@", "Window bounds"))
            .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 12), "the window-bounds row is missing")
        // The neutral defaults, stated on the row itself.
        XCTAssertTrue(row.label.contains("90"), "morning default is not 90: \(row.label)")
        XCTAssertTrue(row.label.contains("60"), "evening default is not 60: \(row.label)")

        row.tap()
        XCTAssertTrue(
            app.staticTexts["THE MORNING"].waitForExistence(timeout: 6),
            "the window-bounds editor did not open"
        )
        XCTAssertTrue(app.staticTexts["THE EVENING"].exists)
    }

    /// The transliteration toggle persists and the reading surface
    /// survives it.
    ///
    /// The transliteration itself is deliberately hidden from
    /// VoiceOver — a screen-reader user has just heard the line in
    /// Arabic — which means it is not in the accessibility tree and no
    /// UI test can see it. Its visual presence is verified by
    /// screenshot instead; what this test can prove is that the
    /// setting sticks and that turning it off does not take the Arabic
    /// or the translation with it.
    @MainActor
    func testTransliterationTogglePersistsAndLeavesTheSurfaceIntact() throws {
        let app = launch(
            ["-IhsanDebugTab", "settings", "-IhsanDebugEnableAdhkar"],
            nowOverride: "2026-08-02T13:10:00"
        )

        let toggle = app.switches["Show transliteration"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 12), "the transliteration switch is missing")
        XCTAssertEqual(toggle.value as? String, "1", "the reading aid is not on by default")
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "0")

        // Background the app the way a person does rather than killing
        // it. SwiftData's autosave flushes on the lifecycle
        // transition; `terminate()` is a SIGKILL that skips it, so a
        // test that terminates here would be measuring the harness
        // instead of the app. (Verified both ways against the store.)
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 3)
        app.terminate()

        // Relaunch onto the SAME store: the choice held, and the set
        // still reads.
        let reopened = launch(
            ["-IhsanDebugPresentAdhkar", "postPrayer"],
            nowOverride: "2026-08-02T13:10:00",
            resetStore: false
        )
        XCTAssertTrue(
            reopened.staticTexts["I seek Allah's forgiveness."].waitForExistence(timeout: 12),
            "turning off the reading aid took the translation with it"
        )
        XCTAssertTrue(
            reopened.descendants(matching: .any)["adhkar.counter"].firstMatch.exists,
            "turning off the reading aid broke the counter"
        )

        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 2)
        reopened.terminate()
        let settings = launch(
            ["-IhsanDebugTab", "settings"],
            nowOverride: "2026-08-02T13:10:00",
            resetStore: false
        )
        XCTAssertEqual(
            settings.switches["Show transliteration"].firstMatch.value as? String,
            "0",
            "the choice did not persist"
        )
    }

    /// **The post-prayer path.** With the after-prayer set on, the
    /// logged card's tasbīḥ link asks which of the two is meant.
    @MainActor
    func testLoggedCardOffersTheChoiceOnlyWhenTheSetIsOn() throws {
        // With the set OFF the link does exactly what it always did:
        // it opens the free instrument, and nothing hints otherwise.
        let plain = launch(
            ["-IhsanDebugLogPrayer", "dhuhr:onTime"],
            nowOverride: "2026-08-02T13:10:00"
        )
        let plainLink = plain.buttons["Tasbīḥ"].firstMatch
        XCTAssertTrue(plainLink.waitForExistence(timeout: 12), "the tasbīḥ link is missing")
        plainLink.tap()
        XCTAssertTrue(
            plain.descendants(matching: .any)["dhikr.counter"].firstMatch.waitForExistence(timeout: 6),
            "the link did not open the instrument when the set is off"
        )
        plain.terminate()

        // With the set ON the link asks.
        let app = launch(
            ["-IhsanDebugEnableAdhkar", "-IhsanDebugLogPrayer", "dhuhr:onTime"],
            nowOverride: "2026-08-02T13:10:00"
        )
        let link = app.buttons["Tasbīḥ"].firstMatch
        XCTAssertTrue(link.waitForExistence(timeout: 12), "the tasbīḥ link is missing")
        link.tap()

        let adhkarChoice = app.buttons["After-prayer adhkār"].firstMatch
        XCTAssertTrue(adhkarChoice.waitForExistence(timeout: 6), "the choice was not offered")
        XCTAssertTrue(app.buttons["Free tasbīḥ"].exists, "free tasbīḥ is no longer reachable")

        adhkarChoice.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["adhkar.counter"].firstMatch.waitForExistence(timeout: 8),
            "the after-prayer set did not open"
        )
        XCTAssertTrue(app.staticTexts["AFTER PRAYER"].exists)
    }
}
