import XCTest

/// Phase 6's VoiceOver gate.
///
/// XCUITest cannot turn VoiceOver on, but it reads the same
/// accessibility tree VoiceOver does — so it can check the two things
/// that actually go wrong: an interactive element with no label (which
/// VoiceOver announces as "button", and nothing else), and a label that
/// states a fact the screen does not.
///
/// The walk covers Today and the logging path, which is the journey a
/// person makes every day, plus the surfaces this pass added.
final class VoiceOverWalkUITests: XCTestCase {

    private static let night = "2026-07-30T21:40:00"
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testNothingInteractiveIsUnlabelled() throws {
        let surfaces: [(name: String, arguments: [String])] = [
            ("Today", []),
            ("logging", ["-IhsanDebugPresentLogSheet", "maghrib"]),
            ("yesterday", ["-IhsanDebugPresentYesterday"]),
            ("Path", ["-IhsanDebugTab", "trajectory"]),
            ("Set", ["-IhsanDebugTab", "settings"]),
            ("calculation", ["-IhsanDebugTab", "settings",
                             "-IhsanDebugSettingsRoute", "calculationMethod"]),
            ("adhan", ["-IhsanDebugTab", "settings",
                       "-IhsanDebugSettingsRoute", "adhanSound"]),
            ("qibla", ["-IhsanDebugPresentQibla"]),
            ("dhikr", ["-IhsanDebugPresentDhikr"])
        ]

        for surface in surfaces {
            let app = launch(extraArguments: surface.arguments)
            Thread.sleep(forTimeInterval: 2.5)

            var unlabelled: [String] = []
            for button in app.buttons.allElementsBoundByIndex {
                guard button.exists, button.isHittable else { continue }
                let label = button.label.trimmingCharacters(in: .whitespacesAndNewlines)
                if label.isEmpty {
                    unlabelled.append("\(button.elementType.rawValue) at \(button.frame)")
                }
            }

            XCTAssertTrue(
                unlabelled.isEmpty,
                "\(surface.name) has \(unlabelled.count) unlabelled controls: "
                    + unlabelled.joined(separator: "; ")
            )
            app.terminate()
        }
    }

    /// The plate's markers are the app's primary information display,
    /// and each has to carry its own prayer, time, and state — a marker
    /// that reads as "button" tells a VoiceOver user nothing at all.
    @MainActor
    func testEveryPlateMarkerVoicesItsPrayerAndState() throws {
        let app = launch()
        Thread.sleep(forTimeInterval: 3)

        for prayer in ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"] {
            let marker = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label BEGINSWITH %@", prayer))
                .firstMatch
            XCTAssertTrue(
                marker.waitForExistence(timeout: 8),
                "\(prayer) has no marker in the accessibility tree."
            )
            let spoken = marker.label + " " + ((marker.value as? String) ?? "")
            XCTAssertTrue(
                spoken.contains("AM") || spoken.contains("PM"),
                "\(prayer) does not voice its time: \"\(spoken)\""
            )
            let states = ["upcoming", "now", "logged", "passed", "current"]
            XCTAssertTrue(
                states.contains { spoken.lowercased().contains($0) },
                "\(prayer) does not voice its state: \"\(spoken)\""
            )
        }
    }

    /// Yesterday's rows voice the prayer and what it currently says,
    /// which is the whole content of the sheet.
    @MainActor
    func testYesterdayRowsVoicePrayerAndState() throws {
        let app = launch(extraArguments: ["-IhsanDebugPresentYesterday"])
        Thread.sleep(forTimeInterval: 3)

        for prayer in ["fajr", "dhuhr", "asr", "maghrib", "isha"] {
            let row = app.descendants(matching: .any)["yesterday-row-\(prayer)"]
            XCTAssertTrue(row.waitForExistence(timeout: 6), "\(prayer) row missing.")
            XCTAssertFalse(row.label.isEmpty, "\(prayer) row has no label.")
            XCTAssertEqual(
                row.value as? String, "not logged",
                "\(prayer) row does not voice its state."
            )
        }
    }

    /// A method row's whole purpose is its angles, and a VoiceOver user
    /// must hear them as degrees rather than as "15 degree slash 15
    /// degree".
    @MainActor
    func testMethodRowsSpeakTheirAngles() throws {
        let app = launch(extraArguments: [
            "-IhsanDebugTab", "settings",
            "-IhsanDebugSettingsRoute", "calculationMethod"
        ])
        Thread.sleep(forTimeInterval: 3)

        let isna = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'ISNA'")).firstMatch
        XCTAssertTrue(isna.waitForExistence(timeout: 8))
        let spoken = (isna.value as? String) ?? ""
        XCTAssertTrue(
            spoken.contains("degrees"),
            "A method row must speak its angles as degrees, not symbols: \"\(spoken)\""
        )
        XCTAssertTrue(spoken.contains("Fajr") && spoken.contains("Isha"), spoken)
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
}
