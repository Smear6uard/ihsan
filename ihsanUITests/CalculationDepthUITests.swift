import XCTest

/// Phase 1's gate: the angles are visible, an override is reachable,
/// and changing one moves the plate.
///
/// The last assertion is the one that matters. A settings screen that
/// accepts a number and quietly computes something else would be worse
/// than no setting at all, so the test reads Fajr off the Today plate
/// before and after and requires it to have moved.
final class CalculationDepthUITests: XCTestCase {

    private static let nowOverride = "2026-07-30T21:40:00"

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testAnglesAreShownAndACustomAngleMovesFajr() throws {
        let app = launchAtCalculationMethod()

        // 1. Every listed preset carries its angles.
        XCTAssertTrue(
            app.staticTexts["18° / 17°"].waitForExistence(timeout: 10),
            "MWL must display its 18° / 17° angles inline."
        )
        XCTAssertTrue(app.staticTexts["15° / 15°"].exists, "ISNA must display 15° / 15°.")
        XCTAssertTrue(
            app.staticTexts["18.5° / 90 min"].exists,
            "A fixed-interval method must display its interval, not a fake angle."
        )

        capture(app, named: "p1-01-methods")

        // 2. Advanced is reachable by scrolling, and shows the angle
        //    the app is currently computing with.
        let fajrAngle = app.otherElements["Custom Fajr angle, degrees"]
        scrollUntilHittable(fajrAngle, in: app)
        XCTAssertTrue(fajrAngle.exists, "The Advanced section must expose a custom Fajr angle.")
        XCTAssertEqual(fajrAngle.value as? String, "15°", "It must start at the preset's own angle.")

        capture(app, named: "p1-02-advanced")

        // 3. Read Fajr off the plate before changing anything.
        let before = fajrTimeOnPlate(app)
        XCTAssertFalse(before.isEmpty, "The plate must show a Fajr time.")

        // 4. Raise the angle by two full degrees. A steeper angle means
        //    first light is reached earlier, so Fajr must move back.
        goToSettings(app)
        scrollUntilHittable(fajrAngle, in: app)
        for _ in 0..<4 { tapIncrement(on: fajrAngle) }
        XCTAssertEqual(
            fajrAngle.value as? String, "17°",
            "Four half-degree steps from 15° must land on 17°. Control frame: \(fajrAngle.frame)."
        )

        // 5. The method is no longer ISNA anywhere in the app.
        XCTAssertTrue(
            app.staticTexts["Custom · 17° / 15°"].waitForExistence(timeout: 5),
            "Once an angle is overridden the app must stop calling it ISNA."
        )
        capture(app, named: "p1-03-custom")

        let after = fajrTimeOnPlate(app)
        XCTAssertNotEqual(
            before, after,
            "A custom Fajr angle must move Fajr on the plate. Was \(before), still \(after)."
        )
        capture(app, named: "p1-04-plate-moved")

        // 6. Reset restores the preset, and the plate returns.
        goToSettings(app)
        let reset = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'Reset to ISNA'"))
            .firstMatch
        scrollUntilHittable(reset, in: app)
        XCTAssertTrue(reset.exists, "A custom method must offer a way back to its preset.")
        XCTAssertTrue(
            reset.isHittable,
            "Reset row not hittable. type=\(reset.elementType.rawValue) frame=\(reset.frame)"
        )
        capture(app, named: "p1-05-before-reset")
        reset.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        Thread.sleep(forTimeInterval: 1.5)
        capture(app, named: "p1-06-after-reset")
        XCTAssertEqual(
            fajrAngle.value as? String, "15°",
            "Reset must return the control to the preset's angle."
        )

        let restored = fajrTimeOnPlate(app)
        XCTAssertEqual(restored, before, "Reset must put Fajr back exactly where it was.")
    }

    // MARK: - Helpers

    @MainActor
    private func launchAtCalculationMethod() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-IhsanDebugCompletedOnboarding",
            "-IhsanDebugResetStore",
            "-IhsanNowOverride", Self.nowOverride,
            "-IhsanDebugTab", "settings",
            "-IhsanDebugSettingsRoute", "calculationMethod"
        ]
        app.launch()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow While Using App"]
        if allow.waitForExistence(timeout: 5) { allow.tap() }

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 20))
        return app
    }

    /// The Fajr time as the plate renders it. The marker's label is
    /// "Fajr" with the time as its value, so this reads exactly what a
    /// person sees.
    @MainActor
    private func fajrTimeOnPlate(_ app: XCUIApplication) -> String {
        switchToTab("Today", in: app)
        Thread.sleep(forTimeInterval: 2.0)

        let marker = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'Fajr'")).firstMatch
        if marker.waitForExistence(timeout: 8), let value = marker.value as? String, !value.isEmpty {
            return value
        }
        // Fall back to the rendered label itself, which carries the time
        // when the marker exposes no separate value.
        return marker.exists ? marker.label : ""
    }

    @MainActor
    private func goToSettings(_ app: XCUIApplication) {
        switchToTab("Set", in: app)
        Thread.sleep(forTimeInterval: 1.5)
    }

    /// The native bar minimizes on scroll to a single pill, so a tab
    /// button may not exist until the bar is coaxed back.
    @MainActor
    private func switchToTab(_ label: String, in app: XCUIApplication) {
        let button = app.tabBars.buttons[label]
        for _ in 0..<4 {
            if button.exists && button.isHittable {
                button.tap()
                return
            }
            app.swipeDown(velocity: .slow)
            Thread.sleep(forTimeInterval: 0.8)
        }
        // Last resort: expand the collapsed pill, then pick the tab.
        let pill = app.tabBars.buttons.firstMatch
        if pill.exists { pill.tap() }
        Thread.sleep(forTimeInterval: 0.8)
        if button.waitForExistence(timeout: 3) { button.tap() }
    }

    /// The step controls are one adjustable element for VoiceOver — a
    /// swipe raises the angle — which is the right shipping behaviour
    /// but leaves no separate button for the test to press. It taps the
    /// "+" mark by position instead, and every call site asserts the
    /// resulting value, so a layout change fails here loudly rather
    /// than passing quietly.
    @MainActor
    private func tapIncrement(on element: XCUIElement) {
        // The control lays out as [28 minus][8][64 value][8][28 plus],
        // so the plus mark's centre is a fixed 122pt from the leading
        // edge whatever the value reads. Vertically it sits on the
        // bottom row, 14pt up from the control's foot.
        let frame = element.frame
        element.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: 122, dy: frame.height - 14))
            .tap()
        Thread.sleep(forTimeInterval: 0.35)
    }

    @MainActor
    private func scrollUntilHittable(
        _ element: XCUIElement,
        in app: XCUIApplication,
        maxSwipes: Int = 12
    ) {
        var swipes = 0
        while !(element.exists && element.isHittable) && swipes < maxSwipes {
            app.swipeUp(velocity: .slow)
            Thread.sleep(forTimeInterval: 0.5)
            swipes += 1
        }
    }

    @MainActor
    private func capture(_ app: XCUIApplication, named name: String) {
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
