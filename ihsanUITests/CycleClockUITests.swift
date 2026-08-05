import XCTest

/// The 1 AM check, run rather than described.
///
/// Everything in this file happens at an hour the app used to get
/// wrong. The tracking day rolled at midnight, so at 1 AM the Today
/// screen offered a fresh empty slate for a day whose Fajr was three
/// hours away, an Isha logged then landed on it, and Path grew a
/// column for a cycle that had not begun. Meanwhile the Hijri date sat
/// on the previous daytime's, hours after Maghrib had turned it.
///
/// Both clocks are checked at once because they disagree on purpose:
/// at 1 AM the PRAYER cycle is still the evening before's, while the
/// HIJRI day has already moved on. Neither of them turns at midnight.
final class CycleClockUITests: XCTestCase {

    // Instants are written in the DEVICE's timezone, which is where
    // `-IhsanNowOverride` resolves them; the place is whatever the
    // simulator's location reports, and may sit hours west of it. So
    // every instant below is chosen to hold its meaning under a few
    // hours of skew rather than against one city's exact table:
    // late evening is late evening anywhere, and midday is midday.
    private static let lateEvening = "2026-07-30T23:50:00"
    private static let afterMidnight = "2026-07-31T00:10:00"
    private static let oneAm = "2026-07-31T01:00:00"
    private static let middayNext = "2026-07-31T12:00:00"
    private static let middayBefore = "2026-07-30T12:00:00"

    private static let baseArguments = [
        "-IhsanDebugCompletedOnboarding",
        "-IhsanDebugResetStore"
    ]

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: - Clock 1: the tracker rolls at Fajr

    /// At 1 AM the Today screen is still the evening's: Isha is the
    /// current prayer, and the countdown names the Fajr that will end
    /// the cycle.
    @MainActor
    func testTodayAtOneAmIsStillTheEveningCycle() {
        let app = launch(at: Self.oneAm)
        let header = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] 'Next prayer: Fajr'"))
            .firstMatch
        XCTAssertTrue(
            header.waitForExistence(timeout: 20),
            "At 1 AM the next prayer must be the Fajr that ends this cycle"
        )
        attach(name: "k1-today-1am")
    }

    /// Path's newest row is the cycle in progress. At 1 AM that is the
    /// evening before — July 30 — not the day the wall clock reads.
    @MainActor
    func testPathNewestRowIsTheEveningCycleUntilFajr() {
        let app = launch(at: Self.oneAm, extra: [
            "-IhsanDebugTab", "trajectory",
            "-IhsanDebugLogPrayer", "isha:onTime"
        ])
        XCTAssertTrue(
            row(in: app, containing: "July 30").waitForExistence(timeout: 20),
            "Path must still be showing the cycle that began on July 30"
        )
        XCTAssertFalse(
            row(in: app, containing: "July 31").exists,
            "A column appeared for a cycle whose Fajr has not been called"
        )
        attach(name: "k2-path-1am")
    }

    /// And once Fajr has been called the cycle has rolled. The exact
    /// boundary is pinned by the property tests in IhsanPrayerTimes;
    /// what this proves is that the surface follows it.
    @MainActor
    func testPathRollsOnceFajrHasBeenCalled() {
        let app = launch(at: Self.middayNext, extra: [
            "-IhsanDebugTab", "trajectory",
            "-IhsanDebugLogPrayer", "fajr:onTime"
        ])
        XCTAssertTrue(
            row(in: app, containing: "July 31").waitForExistence(timeout: 20),
            "After Fajr the cycle must have rolled to July 31"
        )
        attach(name: "k3-path-midday")
    }

    /// A 1 AM Isha is loggable, and the sheet offers the in-window
    /// choices — because the window really is open.
    @MainActor
    func testIshaIsLoggableAtOneAm() {
        let app = launch(
            at: Self.oneAm, extra: ["-IhsanDebugPresentLogSheet", "isha"]
        )
        let onTime = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] 'On time'"))
            .firstMatch
        XCTAssertTrue(
            onTime.waitForExistence(timeout: 20),
            "Isha must still be loggable on time at 1 AM"
        )
        attach(name: "k4-log-sheet-isha-1am")
    }

    // MARK: - Clock 2: the Hijri day turned at Maghrib

    /// Two assertions, either side of the two boundaries that matter.
    ///
    /// Midday and late evening of one civil day read DIFFERENT Hijri
    /// dates: the sun set between them and the day turned. Late
    /// evening and twenty minutes past midnight read the SAME one:
    /// nothing happened at midnight.
    @MainActor
    func testHijriDateTurnsAtMaghribAndNotAtMidnight() {
        let midday = hijriLine(at: Self.middayBefore)
        let evening = hijriLine(at: Self.lateEvening)
        let afterMidnight = hijriLine(at: Self.afterMidnight)

        XCTAssertFalse(midday.isEmpty, "No Hijri date was rendered")
        XCTAssertNotEqual(
            midday, evening,
            "The Hijri date did not turn at Maghrib"
        )
        XCTAssertEqual(
            evening, afterMidnight,
            "Midnight moved the Hijri date; it turns at Maghrib and nowhere else"
        )
    }

    // MARK: - Harness

    @MainActor
    private func launch(at instant: String, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = Self.baseArguments + ["-IhsanNowOverride", instant] + extra
        app.launch()
        grantLocationIfAsked()
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 20)
        let loading = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] 'Loading prayer times'"))
            .firstMatch
        let deadline = Date().addingTimeInterval(25)
        while loading.exists && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.5)
        }
        Thread.sleep(forTimeInterval: 2.5)
        return app
    }

    /// The header's spoken label carries the Hijri date verbatim.
    @MainActor
    private func hijriLine(at instant: String) -> String {
        let app = launch(at: instant)
        let element = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] 'Hijri date:'"))
            .firstMatch
        guard element.waitForExistence(timeout: 20) else { return "" }
        let label = element.label
        defer { app.terminate() }
        guard let range = label.range(of: "Hijri date: ") else { return "" }
        let rest = label[range.upperBound...]
        return String(rest.prefix(while: { $0 != "." }))
    }

    @MainActor
    private func row(in app: XCUIApplication, containing text: String) -> XCUIElement {
        app.buttons
            .matching(NSPredicate(format: "label CONTAINS[c] %@", text))
            .firstMatch
    }

    @MainActor
    private func attach(name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func grantLocationIfAsked() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow While Using App"]
        if allow.waitForExistence(timeout: 5) { allow.tap() }
        let allowOnce = springboard.buttons["Allow Once"]
        if allowOnce.exists { allowOnce.tap() }
    }
}
