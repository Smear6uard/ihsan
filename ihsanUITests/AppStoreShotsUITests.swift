import XCTest

/// The App Store screenshot set: six frames from the real app, on real
/// data, at a real moment of a real day.
///
/// Nothing here is a mockup or a composite. Each frame is one launch
/// with the debug arguments that stage its state, so the set can be
/// regenerated after any change rather than being a folder of images
/// nobody can reproduce.
///
/// Captions are in `docs/app-store-captions.md` — quiet and factual,
/// in the app's own register, to be set in App Store Connect rather
/// than burned into the images.
final class AppStoreShotsUITests: XCTestCase {

    /// A July day in Chicago. Night for the hero, dawn for the second
    /// frame, mid-afternoon where a window is open.
    private static let night = "2026-07-30T21:40:00"
    private static let dawn = "2026-07-31T04:35:00"
    private static let afternoon = "2026-07-30T15:10:00"

    /// A month of logged days, so Path and Repair show a life rather
    /// than an empty grid: four weeks, mostly on time, a few delayed,
    /// and a few left unrecorded the way a real month is.
    private static let seededMonth: String = {
        let prayers = ["fajr", "dhuhr", "asr", "maghrib", "isha"]
        var specs: [String] = []
        for day in 1...27 {
            for (index, prayer) in prayers.enumerated() {
                let roll = (day * 7 + index * 3) % 23
                if roll == 0 { continue }
                specs.append("\(prayer):\(roll < 3 ? "late" : "onTime"):-\(day)")
            }
        }
        specs += ["fajr:onTime:0", "dhuhr:onTime:0", "asr:onTime:0"]
        return specs.joined(separator: ";")
    }()

    /// The same month with today's Dhuhr and Asr still open.
    private static let seededMonthBeforeDhuhr = seededMonth
        .split(separator: ";")
        .filter { !$0.hasPrefix("dhuhr:onTime:0") && !$0.hasPrefix("asr:onTime:0") }
        .joined(separator: ";")

    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testCaptureTheSix() throws {
        // 1. The night plate — the app at its most itself.
        capture("store-1-night-plate", arguments: [
            "-IhsanNowOverride", Self.night,
            "-IhsanDebugLogPrayer", Self.seededMonth
        ])

        // 2. Dawn, where the palette turns over.
        capture("store-2-dawn", arguments: [
            "-IhsanNowOverride", Self.dawn,
            "-IhsanDebugLogPrayer", Self.seededMonth
        ])

        // 3. Logging: the two axes, with an open window and the
        // answer being given. Dhuhr is left unlogged so the sheet opens
        // fresh — a seeded log lands after the sheet has read its
        // state, which framed "Save Changes" over an empty choice.
        capture("store-3-logging", arguments: [
            "-IhsanNowOverride", Self.afternoon,
            "-IhsanDebugLogPrayer", Self.seededMonthBeforeDhuhr,
            "-IhsanDebugPresentLogSheet", "dhuhr"
        ], settle: 3.5, tapLabelPrefix: "On Time")

        // 4. Repair — the makeup thread.
        capture("store-4-repair", arguments: [
            "-IhsanNowOverride", Self.night,
            "-IhsanDebugLogPrayer", Self.seededMonth,
            "-IhsanDebugTab", "trajectory",
            "-IhsanDebugSeedFastingLedger", "18",
            "-IhsanDebugPresentRepair"
        ], settle: 3.5)

        // 5. The qibla instrument.
        capture("store-5-qibla", arguments: [
            "-IhsanNowOverride", Self.night,
            "-IhsanDebugPresentQibla"
        ], settle: 3.5)

        // 6. Path — the month as a pattern, not a score. (This frame
        // used to be the debug widget gallery, scrolled until one of
        // its section labels sat under the status bar clock.)
        capture("store-6-path", arguments: [
            "-IhsanNowOverride", Self.night,
            "-IhsanDebugLogPrayer", Self.seededMonth,
            "-IhsanDebugTab", "trajectory"
        ], settle: 3.5)
    }

    @MainActor
    private func capture(
        _ name: String,
        arguments: [String],
        settle: TimeInterval = 3.0,
        tapLabelPrefix: String? = nil
    ) {
        let app = XCUIApplication()
        app.launchArguments = [
            "-IhsanDebugCompletedOnboarding",
            "-IhsanDebugResetStore",
            // The store shows what ships: no layer still behind its
            // review gate (the adhkār texts, and with them the weather
            // duas) may appear in a frame.
            "-IhsanDebugShippingGates"
        ] + arguments
        app.launch()

        let allow = springboard.buttons["Allow While Using App"]
        if allow.waitForExistence(timeout: 5) { allow.tap() }
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 20)

        // Wait for the day to resolve, not merely for the app to be up.
        let loading = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] 'Loading prayer times'"))
            .firstMatch
        let deadline = Date().addingTimeInterval(25)
        while loading.exists && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.5)
        }
        Thread.sleep(forTimeInterval: settle)

        if let tapLabelPrefix {
            let control = app.buttons
                .matching(NSPredicate(format: "label BEGINSWITH %@", tapLabelPrefix))
                .firstMatch
            XCTAssertTrue(control.waitForExistence(timeout: 10), "Missing \(tapLabelPrefix)")
            control.tap()
            Thread.sleep(forTimeInterval: 1.0)
        }

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

        app.terminate()
    }
}
