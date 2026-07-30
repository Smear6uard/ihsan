import XCTest

/// The native-bar acceptance: one system tab bar, identical on all
/// four tabs, still present after the minimize-on-scroll round trip.
final class TabBarChromeUITests: XCTestCase {

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testNativeBarRidesAllFourTabsAndSurvivesScroll() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-IhsanDebugCompletedOnboarding",
            "-IhsanDebugResetStore",
            "-IhsanNowOverride", "2026-08-16T17:30:00Z",
            "-IhsanDebugLogPrayer", "fajr:onTime",
        ]
        app.launch()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow While Using App"]
        if allow.waitForExistence(timeout: 4) { allow.tap() }

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15))

        // The same four system items on every tab.
        for label in ["Path", "Reflect", "Set", "Today", "Path"] {
            let item = tabBar.buttons[label]
            XCTAssertTrue(item.waitForExistence(timeout: 5), "\(label) missing from the bar")
            item.tap()
            Thread.sleep(forTimeInterval: 1.2)
        }

        // Minimize-on-scroll round trip on Path (a scrolling page):
        // the bar recedes on the way down and returns on the way up.
        app.swipeUp(velocity: .slow)
        Thread.sleep(forTimeInterval: 1.0)
        app.swipeUp(velocity: .slow)
        Thread.sleep(forTimeInterval: 1.5)
        app.swipeDown(velocity: .slow)
        Thread.sleep(forTimeInterval: 1.5)

        XCTAssertTrue(tabBar.exists, "The bar must survive the scroll round trip.")

        // While minimized only the active item remains as the pill; a
        // tap on it re-expands the full bar, and switching still works.
        let today = tabBar.buttons["Today"]
        if !today.waitForExistence(timeout: 2) {
            let pill = tabBar.buttons.firstMatch
            if pill.exists { pill.tap() }
        }
        if !today.waitForExistence(timeout: 2) {
            app.swipeDown(velocity: .slow)
        }
        XCTAssertTrue(today.waitForExistence(timeout: 3), "The full bar must return.")
        today.tap()
        XCTAssertTrue(today.isSelected)
    }
}
