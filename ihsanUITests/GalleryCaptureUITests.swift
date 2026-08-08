import XCTest

/// The screenshot harness.
///
/// Every phase gate in the ship pass owes a picture. Rather than
/// driving the simulator by hand, each frame is one launch with the
/// debug arguments that put the app in the state being shown, followed
/// by one full-screen capture written to the simulator's tmp directory
/// — which the host reads at
/// `~/Library/Developer/CoreSimulator/Devices/<udid>/data/tmp/ihsan-gallery`.
///
/// The frames double as the App Store screenshot set (Phase 8): they
/// come from the real app on real data, never a mockup.
final class GalleryCaptureUITests: XCTestCase {

    /// One frame: a name, the launch arguments that stage it, and an
    /// optional settle time for surfaces that animate in.
    private struct Frame {
        let name: String
        let arguments: [String]
        var settle: TimeInterval = 2.5
        /// Some surfaces are taller than the screen; this scrolls to
        /// the end before the shutter so the frame shows the rest.
        var scrollsToBottom: Bool = false
        /// An accessibility-labelled control to open after launch.
        /// Used for user-initiated flows whose destination must never
        /// be staged automatically in production.
        var tapLabel: String? = nil
        /// An accessibility-label fragment that must arrive before
        /// capture (for example, a live Maps result row).
        var waitLabelFragment: String? = nil
    }

    private static let chicagoNight = "2026-07-30T21:40:00"
    private static let chicagoDawn = "2026-07-31T04:35:00"
    private static let chicagoAfternoon = "2026-07-30T15:10:00"
    /// Feature captures run with the simulator staged in Makkah for
    /// the travel gate. These Chicago-zone instants resolve to a
    /// Makkah afternoon and night respectively.
    private static let travelAfternoon = "2026-07-30T07:10:00"
    private static let travelNight = "2026-07-30T15:00:00"

    /// A week with something of every state in it, so the pattern is a
    /// pattern rather than a column of one mark.
    private static let mixedWeek = [
        "fajr:onTime:0", "dhuhr:onTime:0", "asr:late:0",
        "fajr:onTime:-1", "dhuhr:late:-1", "asr:onTime:-1", "maghrib:onTime:-1", "isha:onTime:-1",
        "fajr:missed:-2", "dhuhr:onTime:-2", "asr:onTime:-2", "maghrib:qada:-2",
        "fajr:onTime:-3", "dhuhr:onTime:-3", "asr:onTime:-3", "maghrib:onTime:-3", "isha:late:-3",
        "fajr:late:-4", "dhuhr:onTime:-4", "asr:missed:-4", "maghrib:onTime:-4",
        "fajr:onTime:-5", "dhuhr:onTime:-5", "asr:onTime:-5", "maghrib:onTime:-5", "isha:onTime:-5",
        "dhuhr:onTime:-6", "asr:late:-6", "maghrib:onTime:-6"
    ].joined(separator: ";")

    private static let baseArguments = [
        "-IhsanDebugCompletedOnboarding",
        "-IhsanDebugResetStore"
    ]

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: - Frames

    @MainActor
    func testCaptureGallery() throws {
        let frames: [Frame] = [
            Frame(name: "01-today-night", arguments: [
                "-IhsanNowOverride", Self.chicagoNight
            ]),
            Frame(name: "02-today-dawn", arguments: [
                "-IhsanNowOverride", Self.chicagoDawn
            ]),
            Frame(name: "03-today-afternoon", arguments: [
                "-IhsanNowOverride", Self.chicagoAfternoon
            ]),
            Frame(name: "04-log-sheet", arguments: [
                "-IhsanNowOverride", Self.chicagoAfternoon,
                "-IhsanDebugPresentLogSheet", "dhuhr"
            ], settle: 3.0),
            Frame(name: "05-path", arguments: [
                "-IhsanNowOverride", Self.chicagoNight,
                "-IhsanDebugTab", "trajectory",
                "-IhsanDebugLogPrayer", "fajr:onTime"
            ]),
            Frame(name: "06-qibla", arguments: [
                "-IhsanNowOverride", Self.chicagoNight,
                "-IhsanDebugPresentQibla"
            ], settle: 3.0),
            Frame(name: "07-repair", arguments: [
                "-IhsanNowOverride", Self.chicagoNight,
                "-IhsanDebugTab", "trajectory",
                "-IhsanDebugPresentRepair"
            ], settle: 3.0),
            Frame(name: "08-set", arguments: [
                "-IhsanNowOverride", Self.chicagoNight,
                "-IhsanDebugTab", "settings"
            ]),
            Frame(name: "09-calculation-method", arguments: [
                "-IhsanNowOverride", Self.chicagoNight,
                "-IhsanDebugTab", "settings",
                "-IhsanDebugSettingsRoute", "calculationMethod"
            ], settle: 3.0),
            Frame(name: "09b-adhan", arguments: [
                "-IhsanNowOverride", Self.chicagoNight,
                "-IhsanDebugTab", "settings",
                "-IhsanDebugSettingsRoute", "adhanSound"
            ], settle: 3.0),
            Frame(name: "10-reflect", arguments: [
                "-IhsanNowOverride", Self.chicagoNight,
                "-IhsanDebugTab", "reflection",
                "-IhsanDebugSeedReflections"
            ]),
            Frame(name: "12-widget-faces-night", arguments: [
                "-IhsanNowOverride", Self.chicagoNight,
                "-IhsanDebugWidgetGallery"
            ], settle: 3.0),
            Frame(name: "13-widget-faces-night-lower", arguments: [
                "-IhsanNowOverride", Self.chicagoNight,
                "-IhsanDebugWidgetGallery"
            ], settle: 3.0, scrollsToBottom: true),
            Frame(name: "14-widget-faces-dawn", arguments: [
                "-IhsanNowOverride", Self.chicagoDawn,
                "-IhsanDebugWidgetGallery"
            ], settle: 3.0),
            // Path's presence rows: the two states that matter are
            // "there is voluntary worship in this window" and "there
            // is none". The second is the card most people see, and it
            // must stay pristine — no gutter, no labels, no rows.
            Frame(name: "15-path-voluntary-7d-night", arguments: [
                "-IhsanNowOverride", Self.chicagoNight,
                "-IhsanDebugTab", "trajectory",
                "-IhsanDebugPeriod", "7",
                "-IhsanDebugSeedVoluntary", "10",
                "-IhsanDebugLogPrayer", Self.mixedWeek
            ], settle: 3.0),
            Frame(name: "16-path-voluntary-30d-night", arguments: [
                "-IhsanNowOverride", Self.chicagoNight,
                "-IhsanDebugTab", "trajectory",
                "-IhsanDebugSeedVoluntary", "30",
                "-IhsanDebugLogPrayer", Self.mixedWeek
            ], settle: 3.0),
            Frame(name: "17-path-voluntary-30d-day", arguments: [
                "-IhsanNowOverride", Self.chicagoAfternoon,
                "-IhsanDebugTab", "trajectory",
                "-IhsanDebugSeedVoluntary", "30",
                "-IhsanDebugLogPrayer", Self.mixedWeek
            ], settle: 3.0),
            Frame(name: "18-path-pristine-30d-day", arguments: [
                "-IhsanNowOverride", Self.chicagoAfternoon,
                "-IhsanDebugTab", "trajectory",
                "-IhsanDebugLogPrayer", Self.mixedWeek
            ], settle: 3.0),
            Frame(name: "19-path-day-detail", arguments: [
                "-IhsanNowOverride", Self.chicagoNight,
                "-IhsanDebugTab", "trajectory",
                "-IhsanDebugPeriod", "7",
                "-IhsanDebugSeedVoluntary", "10",
                "-IhsanDebugLogPrayer", Self.mixedWeek,
                "-IhsanDebugExpandPracticeDay", "0"
            ], settle: 3.0, scrollsToBottom: true),
            Frame(name: "11-dhikr", arguments: [
                "-IhsanNowOverride", Self.chicagoNight,
                "-IhsanDebugPresentDhikr"
            ], settle: 3.0)
        ]

        for frame in frames {
            capture(frame)
        }
    }

    /// The same surfaces at the largest accessibility text size, which
    /// is where truncation of meaning shows up.
    @MainActor
    func testCaptureAccessibilityTypeGallery() throws {
        let sizes = ["UICTContentSizeCategoryAccessibilityXXXL"]
        let surfaces: [Frame] = [
            Frame(name: "a5-today", arguments: ["-IhsanNowOverride", Self.chicagoNight]),
            Frame(name: "a5-log-sheet", arguments: [
                "-IhsanNowOverride", Self.chicagoAfternoon,
                "-IhsanDebugPresentLogSheet", "dhuhr"
            ], settle: 3.0),
            Frame(name: "a5-set", arguments: [
                "-IhsanNowOverride", Self.chicagoNight,
                "-IhsanDebugTab", "settings"
            ]),
            Frame(name: "a5-calculation-method", arguments: [
                "-IhsanNowOverride", Self.chicagoNight,
                "-IhsanDebugTab", "settings",
                "-IhsanDebugSettingsRoute", "calculationMethod"
            ], settle: 3.0),
            Frame(name: "a5-reflect", arguments: [
                "-IhsanNowOverride", Self.chicagoNight,
                "-IhsanDebugTab", "reflection",
                "-IhsanDebugSeedReflections"
            ]),
            Frame(name: "a5-path", arguments: [
                "-IhsanNowOverride", Self.chicagoNight,
                "-IhsanDebugTab", "trajectory",
                "-IhsanDebugLogPrayer", "fajr:onTime"
            ]),
            Frame(name: "a5-yesterday", arguments: [
                "-IhsanNowOverride", Self.chicagoNight,
                "-IhsanDebugPresentYesterday"
            ], settle: 3.0),
            Frame(name: "a5-adhan", arguments: [
                "-IhsanNowOverride", Self.chicagoNight,
                "-IhsanDebugTab", "settings",
                "-IhsanDebugSettingsRoute", "adhanSound"
            ], settle: 3.0)
        ]

        for size in sizes {
            for surface in surfaces {
                var frame = surface
                frame = Frame(
                    name: surface.name,
                    arguments: surface.arguments + ["-UIPreferredContentSizeCategoryName", size],
                    settle: surface.settle,
                    scrollsToBottom: surface.scrollsToBottom
                )
                capture(frame)
            }
        }
    }

    /// Feature-gate evidence for nearby masjids and pattern sharing.
    /// Masjid result rows are checked separately against a simulated
    /// travel location using live MapKit; these four frames pin every
    /// non-result branch without turning network behavior into a mock.
    @MainActor
    func testCaptureNearbyMasjidAndPatternSharing() throws {
        let frames: [Frame] = [
            Frame(name: "20-masjid-loading-day", arguments: [
                "-IhsanNowOverride", Self.travelAfternoon,
                "-IhsanDebugPresentMasjids",
                "-IhsanDebugMasjidState", "loading"
            ]),
            Frame(name: "21-masjid-empty-day", arguments: [
                "-IhsanNowOverride", Self.travelAfternoon,
                "-IhsanDebugPresentMasjids",
                "-IhsanDebugMasjidState", "empty"
            ]),
            Frame(name: "22-masjid-permission-night", arguments: [
                "-IhsanNowOverride", Self.travelNight,
                "-IhsanDebugPresentMasjids",
                "-IhsanDebugMasjidState", "permission"
            ]),
            Frame(name: "23-masjid-failure-night", arguments: [
                "-IhsanNowOverride", Self.travelNight,
                "-IhsanDebugPresentMasjids",
                "-IhsanDebugMasjidState", "offline"
            ]),
            Frame(name: "24-share-preview-7d-day", arguments: [
                "-IhsanNowOverride", Self.chicagoAfternoon,
                "-IhsanDebugTab", "trajectory",
                "-IhsanDebugPeriod", "7",
                "-IhsanDebugSeedVoluntary", "10",
                "-IhsanDebugLogPrayer", Self.mixedWeek
            ], settle: 3.0, tapLabel: "Share the current pattern"),
            Frame(name: "25-share-preview-30d-night", arguments: [
                "-IhsanNowOverride", Self.chicagoNight,
                "-IhsanDebugTab", "trajectory",
                "-IhsanDebugPeriod", "30",
                "-IhsanDebugSeedVoluntary", "30",
                "-IhsanDebugLogPrayer", Self.mixedWeek
            ], settle: 3.0, tapLabel: "Share the current pattern"),
            Frame(name: "26-share-preview-a5-day", arguments: [
                "-IhsanNowOverride", Self.chicagoAfternoon,
                "-IhsanDebugTab", "trajectory",
                "-IhsanDebugPeriod", "7",
                "-IhsanDebugSeedVoluntary", "10",
                "-IhsanDebugLogPrayer", Self.mixedWeek,
                "-UIPreferredContentSizeCategoryName",
                "UICTContentSizeCategoryAccessibilityXXXL"
            ], settle: 3.0, tapLabel: "Share the current pattern"),
            Frame(name: "27-masjid-travel-live-day", arguments: [
                "-IhsanNowOverride", Self.travelAfternoon,
                "-IhsanDebugPresentMasjids"
            ], settle: 3.0, waitLabelFragment: "Opens directions in Maps")
        ]

        for frame in frames {
            capture(frame)
        }
    }

    /// Completes the 7D/30D × day/night export matrix without making
    /// the primary state-capture loop repeat its four masjid launches.
    @MainActor
    func testCapturePatternShareCrossPhaseVariants() throws {
        let frames: [Frame] = [
            Frame(name: "24b-share-preview-7d-night", arguments: [
                "-IhsanNowOverride", Self.chicagoNight,
                "-IhsanDebugTab", "trajectory",
                "-IhsanDebugPeriod", "7",
                "-IhsanDebugSeedVoluntary", "10",
                "-IhsanDebugLogPrayer", Self.mixedWeek
            ], settle: 3.0, tapLabel: "Share the current pattern"),
            Frame(name: "25b-share-preview-30d-day", arguments: [
                "-IhsanNowOverride", Self.chicagoAfternoon,
                "-IhsanDebugTab", "trajectory",
                "-IhsanDebugPeriod", "30",
                "-IhsanDebugSeedVoluntary", "30",
                "-IhsanDebugLogPrayer", Self.mixedWeek
            ], settle: 3.0, tapLabel: "Share the current pattern"),
            Frame(name: "25c-share-preview-30d-night", arguments: [
                "-IhsanNowOverride", Self.chicagoNight,
                "-IhsanDebugTab", "trajectory",
                "-IhsanDebugPeriod", "30",
                "-IhsanDebugSeedVoluntary", "30",
                "-IhsanDebugLogPrayer", Self.mixedWeek
            ], settle: 3.0, tapLabel: "Share the current pattern")
        ]

        for frame in frames {
            capture(frame)
        }
    }

    /// Drives the complete, always-user-initiated handoff. Run this
    /// while `simctl io recordVideo` is active to regenerate the flow
    /// recording used at the feature gate.
    @MainActor
    func testPatternShareSystemHandoff() throws {
        let app = XCUIApplication()
        app.launchArguments = Self.baseArguments + [
            "-IhsanNowOverride", Self.chicagoAfternoon,
            "-IhsanDebugTab", "trajectory",
            "-IhsanDebugPeriod", "7",
            "-IhsanDebugSeedVoluntary", "10",
            "-IhsanDebugLogPrayer", Self.mixedWeek
        ]
        app.launch()

        let entry = app.buttons["Share the current pattern"]
        XCTAssertTrue(entry.waitForExistence(timeout: 20))
        entry.tap()

        let handoff = app.buttons["Share this pattern image"]
        XCTAssertTrue(handoff.waitForExistence(timeout: 10))
        handoff.tap()

        let activityList = app.otherElements["ActivityListView"]
        XCTAssertTrue(
            activityList.waitForExistence(timeout: 10),
            "The system share sheet did not appear"
        )
        Thread.sleep(forTimeInterval: 3.0)

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "28-pattern-system-share-sheet"
        attachment.lifetime = .keepAlways
        add(attachment)

        let dismissRegion = app.otherElements["PopoverDismissRegion"]
        if dismissRegion.exists {
            dismissRegion.tap()
        }
    }

    // MARK: - Capture

    @MainActor
    private func capture(_ frame: Frame) {
        let app = XCUIApplication()
        app.launchArguments = Self.baseArguments + frame.arguments
        app.launch()

        grantLocationIfAsked()

        // The tab bar means the app is up; it does not mean the day
        // has resolved. Waiting for the loading inscription to go is
        // the difference between a frame of the app and a frame of a
        // spinner — two accessibility captures were spinners before
        // this existed.
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 20)
        let loading = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] 'Loading prayer times'"))
            .firstMatch
        let deadline = Date().addingTimeInterval(25)
        while loading.exists && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.5)
        }
        Thread.sleep(forTimeInterval: frame.settle)

        if let tapLabel = frame.tapLabel {
            let control = app.buttons[tapLabel]
            XCTAssertTrue(
                control.waitForExistence(timeout: 10),
                "Missing control labelled \(tapLabel)"
            )
            control.tap()
            XCTAssertTrue(
                app.staticTexts["This is what will be shared"]
                    .waitForExistence(timeout: 10),
                "Pattern preview did not open"
            )
            Thread.sleep(forTimeInterval: 2.0)
        }

        if let fragment = frame.waitLabelFragment {
            let match = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS[c] %@", fragment))
                .firstMatch
            XCTAssertTrue(
                match.waitForExistence(timeout: 20),
                "No element arrived with label containing \(fragment)"
            )
        }

        if frame.scrollsToBottom {
            for _ in 0..<4 {
                app.swipeUp(velocity: .fast)
                Thread.sleep(forTimeInterval: 0.4)
            }
            Thread.sleep(forTimeInterval: 1.0)
        }

        write(XCUIScreen.main.screenshot(), named: frame.name)
        app.terminate()
    }

    @MainActor
    private func grantLocationIfAsked() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow While Using App"]
        if allow.waitForExistence(timeout: 5) { allow.tap() }
        let allowOnce = springboard.buttons["Allow Once"]
        if allowOnce.exists { allowOnce.tap() }
    }

    private func write(_ screenshot: XCUIScreenshot, named name: String) {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ihsan-gallery", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true
        )
        let url = directory.appendingPathComponent("\(name).png")
        do {
            try screenshot.pngRepresentation.write(to: url)
        } catch {
            XCTFail("Could not write \(name): \(error)")
        }

        // Also attach, so a failed run still carries its evidence.
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
