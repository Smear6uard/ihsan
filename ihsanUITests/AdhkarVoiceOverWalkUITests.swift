import XCTest

/// The VoiceOver gate for the remembrance surfaces.
///
/// XCUITest cannot turn VoiceOver on, but it reads the same
/// accessibility tree VoiceOver does — so it can check the things that
/// actually go wrong: an interactive element with no label, an Arabic
/// line that is not tagged as Arabic (which a synthesiser will spell
/// out in an English voice), and a reading order that puts the
/// romanisation between the text and its meaning.
final class AdhkarVoiceOverWalkUITests: XCTestCase {

    /// Inside the morning window (Fajr 4:14, sunrise 5:45 in Chicago
    /// on this date, so the window runs to 7:15).
    private static let morning = "2026-08-02T06:10:00"
    private static let afternoon = "2026-08-02T13:10:00"

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    private func launch(
        _ extraArguments: [String],
        nowOverride: String = AdhkarVoiceOverWalkUITests.afternoon
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-IhsanDebugCompletedOnboarding",
            "-IhsanDebugResetStore",
            "-IhsanDebugEnableAdhkar",
            "-IhsanNowOverride", nowOverride,
        ] + extraArguments
        app.launch()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow While Using App"]
        if allow.waitForExistence(timeout: 4) { allow.tap() }
        return app
    }

    @MainActor
    func testNothingInteractiveIsUnlabelledOnTheRemembranceSurfaces() throws {
        let surfaces: [(name: String, arguments: [String])] = [
            ("after-prayer set", ["-IhsanDebugPresentAdhkar", "postPrayer"]),
            ("morning set", ["-IhsanDebugPresentAdhkar", "morning"]),
            ("sleep set", ["-IhsanDebugPresentAdhkar", "sleep"]),
            ("Set · adhkār windows", ["-IhsanDebugTab", "settings",
                                      "-IhsanDebugSettingsRoute", "adhkarWindows"]),
        ]

        for surface in surfaces {
            let app = launch(surface.arguments)
            Thread.sleep(forTimeInterval: 3)

            // The stepper's − and + glyphs are `accessibilityHidden`
            // and the control speaks as ONE adjustable element with a
            // label and a value — the correct VoiceOver design and the
            // app's established pattern. XCUITest enumerates the drawn
            // glyphs anyway; verified identically against the
            // pre-existing duha-window picker, so this is a query
            // artifact rather than a defect. They are excluded by
            // their exact 28×28 size, and the labelled adjustable
            // control they belong to is asserted below.
            let stepperSide: CGFloat = 28
            let unlabelled = app.buttons.allElementsBoundByIndex
                .filter { $0.exists && $0.isHittable }
                .filter { $0.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .filter { !($0.frame.width == stepperSide && $0.frame.height == stepperSide) }
                .map { "button at \($0.frame)" }

            XCTAssertTrue(
                unlabelled.isEmpty,
                "\(surface.name) has \(unlabelled.count) unlabelled controls: "
                    + unlabelled.joined(separator: "; ")
            )
            // Every stepper on the window editor speaks as a labelled
            // adjustable control, which is what VoiceOver reaches.
            if surface.name.contains("windows") {
                let adjustables = app.otherElements.allElementsBoundByIndex
                    .filter { $0.label.lowercased().contains("minutes") }
                XCTAssertEqual(
                    adjustables.count, 2,
                    "the window editor's steppers do not speak: "
                        + adjustables.map(\.label).joined(separator: "; ")
                )
            }

            app.terminate()
        }
    }

    /// The per-item order: Arabic, then the translation, then the
    /// count. The romanisation is deliberately absent — a screen-reader
    /// user has just heard the line in Arabic, and hearing an English
    /// voice work through "Astaghfiru'llāh" immediately afterwards is
    /// noise, not help.
    @MainActor
    func testItemReadingOrderIsArabicThenTranslationThenCount() throws {
        let app = launch(["-IhsanDebugPresentAdhkar", "postPrayer"])

        let counter = app.descendants(matching: .any)["adhkar.counter"].firstMatch
        XCTAssertTrue(counter.waitForExistence(timeout: 25), "the set did not present")

        // Tree order is the order VoiceOver walks.
        let texts = app.staticTexts.allElementsBoundByIndex
            .filter { $0.exists && !$0.label.isEmpty }
            .map(\.label)

        let arabic = texts.firstIndex { $0.contains("\u{0623}") || $0.contains("\u{0644}") }
        let translation = texts.firstIndex { $0 == "I seek Allah's forgiveness." }

        let arabicIndex = try XCTUnwrap(arabic, "the Arabic line is not in the accessibility tree")
        let translationIndex = try XCTUnwrap(translation, "the translation is not in the tree")
        XCTAssertLessThan(
            arabicIndex, translationIndex,
            "the translation is read before the Arabic"
        )

        // The romanisation is not spoken.
        XCTAssertFalse(
            texts.contains("Astaghfiru'llāh."),
            "the transliteration is in the reading order"
        )

        // The count is reachable and states both numbers.
        let value = try XCTUnwrap(counter.value as? String)
        XCTAssertTrue(value.contains("0"), "the count does not state where it is: \(value)")
        XCTAssertTrue(value.contains("3"), "the count does not state its target: \(value)")
    }

    /// Every mark in the band names its position and says what state it
    /// is in, so someone who cannot see the gilding still knows how far
    /// through the set they are.
    @MainActor
    func testTheSequenceBandSpeaksPositionAndState() throws {
        let app = launch(["-IhsanDebugPresentAdhkar", "sleep"])
        XCTAssertTrue(
            app.descendants(matching: .any)["adhkar.counter"].firstMatch.waitForExistence(timeout: 25),
            "the set did not present"
        )

        let marks = app.buttons.allElementsBoundByIndex.filter { $0.label.contains(" of 7,") }
        XCTAssertEqual(marks.count, 7, "the band does not speak one mark per item")
        XCTAssertEqual(marks.first?.value as? String, "current")
        XCTAssertEqual(marks.last?.value as? String, "not yet counted")

        // Count the first item through; its mark changes what it says.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.55)).tap()
        Thread.sleep(forTimeInterval: 1.5)
        let refreshed = app.buttons.allElementsBoundByIndex.filter { $0.label.contains(" of 7,") }
        XCTAssertEqual(refreshed.first?.value as? String, "counted")
    }

    /// The offer card says what it is, when it is, and what its
    /// dismissal does.
    @MainActor
    func testTheOfferCardSpeaksItsWindow() throws {
        // Inside the morning window, which is when a card exists at
        // all — at one in the afternoon the day is offering nothing,
        // and that is the design rather than a fault.
        let app = launch([], nowOverride: Self.morning)
        let offer = app.buttons
            .containing(NSPredicate(format: "label CONTAINS[c] %@", "adhkār"))
            .firstMatch
        XCTAssertTrue(offer.waitForExistence(timeout: 25), "no offer card to read")
        XCTAssertTrue(offer.label.contains("window"), "the card does not say its window: \(offer.label)")
        XCTAssertTrue(app.buttons["Not now"].exists, "the dismissal is unlabelled")
    }
}
