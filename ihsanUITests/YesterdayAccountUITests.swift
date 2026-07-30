import XCTest

/// Phase 6.5's gate: the offer appears, opens, fills a whole day in
/// seconds, and then never mentions it again.
///
/// The timing assertion is real. The claim is "two taps per prayer,
/// five prayers, under fifteen seconds"; this measures the wall clock
/// across the five commits and fails if it drifts past that.
final class YesterdayAccountUITests: XCTestCase {

    /// A night moment, so yesterday is a full closed day.
    private static let night = "2026-07-30T21:40:00"

    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: - The offer

    @MainActor
    func testTheOfferAppearsOnlyWhenYesterdayIsUnaccountedFor() throws {
        // Nothing logged at all: the line names the whole day.
        var app = launch()
        let offer = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'Yesterday,'")).firstMatch
        XCTAssertTrue(
            offer.waitForExistence(timeout: 15),
            "An entirely unlogged yesterday must be offered."
        )
        capture(app, named: "p65-01-offer")
        app.terminate()

        // Yesterday fully logged: silence.
        app = launch(extraArguments: [
            "-IhsanDebugLogPrayer",
            "fajr:onTime:-1;dhuhr:onTime:-1;asr:onTime:-1;maghrib:onTime:-1;isha:onTime:-1"
        ])
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 20)
        Thread.sleep(forTimeInterval: 3)
        XCTAssertFalse(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "label BEGINSWITH 'Yesterday,'")).firstMatch.exists,
            "A fully accounted yesterday must not be mentioned."
        )
        capture(app, named: "p65-02-silent-when-handled")
        app.terminate()

        // An excused pause covering yesterday: silence, whatever the
        // logs say.
        app = launch(extraArguments: ["-IhsanDebugPauseSince", "3"])
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 20)
        Thread.sleep(forTimeInterval: 3)
        XCTAssertFalse(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "label BEGINSWITH 'Yesterday,'")).firstMatch.exists,
            "An excused pause must silence the offer entirely."
        )
        capture(app, named: "p65-03-silent-under-pause")
    }

    @MainActor
    func testDismissingHidesTheOfferForTheRestOfTheDay() throws {
        let app = launch()
        let offer = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'Yesterday,'")).firstMatch
        XCTAssertTrue(offer.waitForExistence(timeout: 15))

        let dismiss = app.buttons["Dismiss yesterday's note"]
        XCTAssertTrue(dismiss.waitForExistence(timeout: 5), "The line must carry its own dismiss mark.")
        dismiss.tap()
        Thread.sleep(forTimeInterval: 1.5)

        XCTAssertFalse(offer.exists, "Dismissing must put the line away.")
        capture(app, named: "p65-04-dismissed")
    }

    // MARK: - The sheet

    @MainActor
    func testFivePrayersAreLoggedInUnderFifteenSeconds() throws {
        let app = launch(extraArguments: ["-IhsanDebugPresentYesterday"])
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 20)

        let sheetTitle = app.staticTexts["Yesterday"]
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 10), "The sheet must open.")
        capture(app, named: "p65-05-sheet-open")

        // The first unlogged row opens itself, so each prayer is one
        // tap: choose a timing, the row closes, the next opens.
        let start = Date()
        for prayer in ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"] {
            let chip = app.buttons["\(prayer), On Time"]
            XCTAssertTrue(
                chip.waitForExistence(timeout: 6),
                "\(prayer)'s row did not open itself after the previous commit."
            )
            chip.tap()
            Thread.sleep(forTimeInterval: 0.4)
        }
        let elapsed = Date().timeIntervalSince(start)

        capture(app, named: "p65-06-sheet-filled")
        XCTAssertLessThan(
            elapsed, 15,
            "Five prayers took \(elapsed)s; the whole point is that it is quick."
        )

        // Every row now reads back its answer.
        for prayer in ["fajr", "dhuhr", "asr", "maghrib", "isha"] {
            let row = app.descendants(matching: .any)["yesterday-row-\(prayer)"]
            XCTAssertEqual(
                row.value as? String, "on time",
                "\(prayer) did not read back as logged."
            )
        }

        // And with the day handled, the offer is gone for good.
        app.buttons["Done"].tap()
        Thread.sleep(forTimeInterval: 2)
        XCTAssertFalse(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "label BEGINSWITH 'Yesterday,'")).firstMatch.exists,
            "Once yesterday is accounted for the line must not come back."
        )
        capture(app, named: "p65-07-offer-gone")
    }

    @MainActor
    func testTheAllFiveShortcutFillsTheDayAndLeavesEveryRowEditable() throws {
        let app = launch(extraArguments: ["-IhsanDebugPresentYesterday"])
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 20)
        XCTAssertTrue(app.staticTexts["Yesterday"].waitForExistence(timeout: 10))

        let shortcut = app.buttons["Log all five prayers on time"]
        XCTAssertTrue(
            shortcut.waitForExistence(timeout: 5),
            "With nothing logged, the whole-day shortcut must be offered."
        )
        shortcut.tap()
        Thread.sleep(forTimeInterval: 2)
        capture(app, named: "p65-08-all-five")

        for prayer in ["fajr", "dhuhr", "asr", "maghrib", "isha"] {
            let row = app.descendants(matching: .any)["yesterday-row-\(prayer)"]
            XCTAssertEqual(row.value as? String, "on time")
        }

        // The shortcut withdraws once it no longer applies — it is for
        // an empty day, not a correction tool.
        XCTAssertFalse(
            shortcut.exists,
            "The shortcut must disappear once the day has answers."
        )

        // And a row is still editable afterwards.
        let fajr = app.descendants(matching: .any)["yesterday-row-fajr"]
        fajr.tap()
        Thread.sleep(forTimeInterval: 0.8)
        let late = app.buttons["Fajr, Late"]
        XCTAssertTrue(late.waitForExistence(timeout: 4), "A logged row must still open.")
        late.tap()
        Thread.sleep(forTimeInterval: 1.2)
        XCTAssertEqual(fajr.value as? String, "late")
        capture(app, named: "p65-09-still-editable")
    }

    // MARK: - Helpers

    @MainActor
    private func launch(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-IhsanDebugCompletedOnboarding",
            "-IhsanDebugResetStore",
            "-IhsanNowOverride", Self.night
        ] + extraArguments
        app.launch()
        let allow = springboard.buttons["Allow While Using App"]
        if allow.waitForExistence(timeout: 5) { allow.tap() }
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 20)
        return app
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
