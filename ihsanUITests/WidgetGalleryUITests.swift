import XCTest

/// Phase 3's gate: pictures of the widgets as iOS actually renders
/// them.
///
/// A widget cannot be launched. It is drawn by WidgetKit on a home
/// screen, from a timeline the app wrote to the App Group — so this
/// primes that cache by running the app at a chosen moment, then drives
/// Springboard to place the widgets and photographs the result.
///
/// Placement is the fragile part (Springboard's own gallery changes
/// between releases), so each step is best-effort and the run reports
/// what it managed to place rather than failing the phase over a
/// gesture. What it must not do is invent a picture: every frame here
/// is a real render or it is absent.
final class WidgetGalleryUITests: XCTestCase {

    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testCaptureWidgetsOnTheHomeScreen() throws {
        // 1. Prime the App Group schedule cache at a night moment, so
        //    the widgets have a real day to draw.
        primeCache(at: "2026-07-30T21:40:00")

        // 2. Go to the home screen and photograph whatever Ihsan
        //    widgets are already placed there.
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 2)
        capture("w-01-home-night")

        // 3. Add each family we can reach through the gallery.
        for name in ["Today's Prayers", "Nightstand", "Next Prayer", "Today"] {
            if addWidget(named: name) {
                Thread.sleep(forTimeInterval: 1.5)
                capture("w-02-added-\(name.replacingOccurrences(of: " ", with: "-").replacingOccurrences(of: "'", with: ""))")
            }
        }

        // 4. The same home screen after the ground has moved to dawn.
        primeCache(at: "2026-07-31T04:35:00")
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 3)
        capture("w-03-home-dawn")

        // 5. The lock screen, where the accessory families live.
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 1)
        capture("w-04-lock")
    }

    // MARK: - Steps

    @MainActor
    private func primeCache(at override: String) {
        let app = XCUIApplication()
        app.launchArguments = [
            "-IhsanDebugCompletedOnboarding",
            "-IhsanNowOverride", override
        ]
        app.launch()
        let allow = springboard.buttons["Allow While Using App"]
        if allow.waitForExistence(timeout: 5) { allow.tap() }
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 20)
        // Long enough for the snapshot refresh to write the App Group
        // cache and for WidgetKit to reload from it.
        Thread.sleep(forTimeInterval: 4)
        app.terminate()
    }

    /// Long-press the home screen, open the widget gallery, search for
    /// the widget by its configuration display name, and place it.
    @MainActor
    @discardableResult
    private func addWidget(named name: String) -> Bool {
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 1.5)

        // Long press an empty area to enter edit mode.
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.22))
            .press(forDuration: 1.6)
        Thread.sleep(forTimeInterval: 1.5)

        let edit = springboard.buttons["Edit"]
        if edit.waitForExistence(timeout: 3) {
            edit.tap()
            Thread.sleep(forTimeInterval: 1)
        }
        let addWidget = springboard.buttons["Add Widget"]
        if addWidget.waitForExistence(timeout: 3) {
            addWidget.tap()
        } else {
            let plus = springboard.buttons["Add"]
            if plus.waitForExistence(timeout: 2) { plus.tap() }
        }
        Thread.sleep(forTimeInterval: 1.5)

        let search = springboard.searchFields.firstMatch
        guard search.waitForExistence(timeout: 4) else {
            dismissEditing()
            return false
        }
        search.tap()
        search.typeText("Ihsan")
        Thread.sleep(forTimeInterval: 1.5)

        // Springboard's gallery rows expose their label as a static
        // text that is not itself hittable; tapping its centre by
        // coordinate reaches the row underneath.
        let ihsan = springboard.staticTexts["Ihsan"].firstMatch
        guard ihsan.waitForExistence(timeout: 4) else {
            dismissEditing()
            return false
        }
        ihsan.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        Thread.sleep(forTimeInterval: 1.5)

        let target = springboard.staticTexts[name]
        guard target.waitForExistence(timeout: 4) else {
            dismissEditing()
            return false
        }
        target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        Thread.sleep(forTimeInterval: 1.5)
        capture("w-gallery-\(name.replacingOccurrences(of: " ", with: "-"))")

        let add = springboard.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Add Widget'")
        ).firstMatch
        if add.waitForExistence(timeout: 3) {
            add.tap()
            Thread.sleep(forTimeInterval: 2)
        }
        dismissEditing()
        return true
    }

    @MainActor
    private func dismissEditing() {
        let done = springboard.buttons["Done"]
        if done.exists { done.tap() }
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 1)
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
