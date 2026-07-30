import XCTest

/// Phase 4's gate: the first run, on a clean install, timed.
///
/// The claim is "under 60 seconds to the live app". The test walks the
/// three screens at a human pace and fails if the wall clock says
/// otherwise — including the location and notification permission
/// dialogs, which are part of the minute whether or not they are the
/// app's own code.
final class OnboardingUITests: XCTestCase {

    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testFirstRunReachesTheLiveAppInUnderAMinute() throws {
        let app = XCUIApplication()
        // No -IhsanDebugCompletedOnboarding: this is the real first run.
        app.launchArguments = [
            "-IhsanDebugResetStore",
            "-IhsanNowOverride", "2026-07-30T21:40:00"
        ]
        app.launch()

        let start = Date()

        // 1. The first screen is the app: a live plate, not a wordmark.
        let useLocation = app.buttons["Use my location"]
        XCTAssertTrue(
            useLocation.waitForExistence(timeout: 20),
            "The first screen must offer the location question in place."
        )
        // Makkah's real times are on screen before anything is asked.
        XCTAssertTrue(app.staticTexts["MAKKAH"].exists, "The default place must be named.")
        // And nothing has asked yet. The app used to run Today behind
        // the flow, which raised this dialog by itself at launch — in
        // front of the screen whose whole job is to ask.
        XCTAssertFalse(
            springboard.buttons["Allow While Using App"].exists,
            "The permission dialog must not appear before the question is asked."
        )
        capture("p4-01-plate")

        useLocation.tap()
        let allow = springboard.buttons["Allow While Using App"]
        XCTAssertTrue(
            allow.waitForExistence(timeout: 15),
            "Tapping the question must be what raises the dialog."
        )
        allow.tap()
        Thread.sleep(forTimeInterval: 3)
        capture("p4-02-plate-resolved")

        // 2. Calculation. When the place resolved, the plate redraws
        //    and waits on Continue; when reverse geocoding could not
        //    name it, there is nothing to redraw and the flow has
        //    already moved on. Both are correct.
        let calculationHeading = app.staticTexts["How the times are worked out"]
        if !calculationHeading.waitForExistence(timeout: 6) {
            app.buttons["Continue"].firstMatch.tap()
        }
        XCTAssertTrue(
            calculationHeading.waitForExistence(timeout: 8),
            "Screen two must be the calculation screen."
        )
        XCTAssertTrue(
            app.staticTexts["18° / 17°"].waitForExistence(timeout: 5),
            "Every method row must carry its angles here too."
        )
        capture("p4-03-calculation")

        // Asr is on this same screen, below the methods — it moves a
        // prayer by close to an hour and must not be left to be
        // discovered later in Set.
        let hanafi = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'Hanafi'")).firstMatch
        var swipes = 0
        while !hanafi.exists && swipes < 8 {
            app.swipeUp(velocity: .fast)
            Thread.sleep(forTimeInterval: 0.3)
            swipes += 1
        }
        XCTAssertTrue(hanafi.exists, "Asr belongs on the calculation screen.")
        capture("p4-03b-asr")

        app.buttons["Continue"].firstMatch.tap()

        // 3. The close: the two quiet lines, then the notification ask.
        let allowNotifications = app.buttons["Allow notifications"]
        XCTAssertTrue(
            allowNotifications.waitForExistence(timeout: 8),
            "Screen three must ask about notifications."
        )
        XCTAssertTrue(
            app.staticTexts.containing(
                NSPredicate(format: "label CONTAINS 'There is no server'")
            ).firstMatch.exists,
            "The privacy line must be stated before the flow ends."
        )
        XCTAssertTrue(
            app.staticTexts.containing(
                NSPredicate(format: "label CONTAINS 'sunnah layer'")
            ).firstMatch.exists,
            "The sunnah layer must be mentioned once, quietly."
        )
        capture("p4-04-close")

        allowNotifications.tap()
        let allowNotifs = springboard.buttons["Allow"]
        if allowNotifs.waitForExistence(timeout: 8) { allowNotifs.tap() }

        // 4. The live app.
        XCTAssertTrue(
            app.tabBars.firstMatch.waitForExistence(timeout: 20),
            "The flow must end in the app itself."
        )
        let elapsed = Date().timeIntervalSince(start)
        capture("p4-05-arrived")

        XCTAssertLessThan(
            elapsed, 60,
            "First run took \(elapsed)s; the whole point is that it is short."
        )
    }

    @MainActor
    func testDecliningLocationIsACompleteAnswer() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-IhsanDebugResetStore",
            "-IhsanNowOverride", "2026-07-30T21:40:00"
        ]
        app.launch()

        let notNow = app.buttons["Not now"]
        XCTAssertTrue(
            notNow.waitForExistence(timeout: 20),
            "Declining must be offered as plainly as accepting."
        )
        notNow.tap()

        XCTAssertTrue(
            app.staticTexts["How the times are worked out"].waitForExistence(timeout: 8),
            "Declining continues the flow rather than blocking it."
        )
        app.buttons["Continue"].firstMatch.tap()

        let skip = app.buttons["Not now"]
        XCTAssertTrue(skip.waitForExistence(timeout: 8))
        skip.tap()

        XCTAssertTrue(
            app.tabBars.firstMatch.waitForExistence(timeout: 20),
            "Declining everything must still reach the app."
        )
        capture("p4-06-declined-everything")
    }

    private func capture(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ihsan-gallery", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation
            .write(to: directory.appendingPathComponent("\(name).png"))
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
