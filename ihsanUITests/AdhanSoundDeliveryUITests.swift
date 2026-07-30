import XCTest

/// Phase 2's gate: every sound choice fires, on a real device clock,
/// carrying the sound it promised.
///
/// This is a timed test rather than a unit test on purpose. A bundled
/// tone that iOS declines — wrong container, over thirty seconds, not
/// actually copied into the bundle — produces a notification that
/// arrives perfectly and makes no sound, and nothing in code can tell
/// you that happened. So the probe schedules real notifications a few
/// seconds out and this waits for them.
final class AdhanSoundDeliveryUITests: XCTestCase {

    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testEverySoundChoiceDeliversAndCarriesItsOwnTone() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-IhsanDebugCompletedOnboarding",
            "-IhsanDebugResetStore",
            "-IhsanNowOverride", "2026-07-30T21:40:00",
            "-IhsanDebugSoundProbe", "chime,chime-dawn,takbirat,silent"
        ]
        app.launch()

        allowIfAsked("Allow While Using App")
        allowIfAsked("Allow")

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 20))

        // The probe fires at +3s, +6s, +9s, +12s. Backgrounding the app
        // is what makes iOS present banners at all.
        XCUIDevice.shared.press(.home)

        // Each banner names its choice, and its body is the audio file
        // that choice actually resolved to.
        let expectations: [(choice: String, body: String)] = [
            ("chime", "ihsan-chime.caf"),
            ("chime-dawn", "ihsan-chime-dawn.caf"),
            // Not yet recorded: it must stand in with the chime, never
            // fall silent and never reach for the system tri-tone.
            ("takbirat", "ihsan-chime.caf"),
            ("silent", "no sound")
        ]

        for expectation in expectations {
            let banner = springboard.otherElements.containing(
                NSPredicate(format: "label CONTAINS %@", "Probe \(expectation.choice)")
            ).firstMatch
            XCTAssertTrue(
                banner.waitForExistence(timeout: 25),
                "The \(expectation.choice) notification never arrived."
            )

            let body = springboard.staticTexts[expectation.body]
            XCTAssertTrue(
                body.waitForExistence(timeout: 5),
                "The \(expectation.choice) notification arrived carrying something "
                    + "other than \(expectation.body)."
            )

            // Dismiss so the next banner is the one being read.
            banner.swipeUp()
            Thread.sleep(forTimeInterval: 0.6)
        }
    }

    @MainActor
    private func allowIfAsked(_ label: String) {
        let button = springboard.buttons[label]
        if button.waitForExistence(timeout: 4) { button.tap() }
    }
}
