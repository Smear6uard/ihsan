import XCTest

/// Live Activities have their own section in Settings, with a switch for
/// all of them and one per prayer, apart from the prayers' notifications.
final class LiveActivitySettingsUITests: XCTestCase {

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testEachPrayersLiveActivityHasItsOwnSwitch() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-IhsanDebugCompletedOnboarding",
            "-IhsanDebugResetStore",
            "-IhsanDebugTab", "settings"
        ]
        app.launch()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allowLocation = springboard.buttons["Allow While Using App"]
        if allowLocation.waitForExistence(timeout: 4) { allowLocation.tap() }

        let notifications = app.switches["Prayer notifications"]
        XCTAssertTrue(scroll(to: notifications, in: app))
        if notifications.value as? String == "0" {
            notifications.tap()
            let allow = springboard.buttons["Allow"]
            if allow.waitForExistence(timeout: 4) { allow.tap() }
        }

        let all = app.switches["Live Activities"]
        XCTAssertTrue(scroll(to: all, in: app), "There is no Live Activities switch.")
        // A prior run on this simulator may have left it off: the
        // preference is device-local and outlives the store reset.
        if all.value as? String == "0" { all.tap() }

        let asr = app.switches["Asr Live Activity"]
        XCTAssertTrue(scroll(to: asr, in: app), "Asr has no Live Activity switch of its own.")
        if asr.value as? String == "0" { asr.tap() }
        XCTAssertEqual(asr.value as? String, "1")
        asr.tap()
        XCTAssertEqual(asr.value as? String, "0", "Asr's switch did not turn off.")

        // The others, and Asr's own notification, stay as they were.
        XCTAssertEqual(app.switches["Fajr Live Activity"].value as? String, "1")
        XCTAssertEqual(app.switches["Asr notification"].value as? String, "1")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "live-activities-settings"
        attachment.lifetime = .keepAlways
        add(attachment)

        // Leave the simulator as it was found.
        asr.tap()
    }

    /// Settings is a long page; swipes until the element is on screen.
    @MainActor
    private func scroll(to element: XCUIElement, in app: XCUIApplication) -> Bool {
        var attempts = 0
        while !(element.exists && element.isHittable) && attempts < 20 {
            app.swipeUp(velocity: .slow)
            attempts += 1
        }
        return element.exists && element.isHittable
    }
}
