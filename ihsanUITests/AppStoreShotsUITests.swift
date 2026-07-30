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
    /// than an empty grid.
    private static let seededMonth = [
        "fajr:onTime:-1", "dhuhr:onTime:-1", "asr:late:-1", "maghrib:onTime:-1", "isha:onTime:-1",
        "fajr:onTime:-2", "dhuhr:onTime:-2", "asr:onTime:-2", "maghrib:onTime:-2", "isha:late:-2",
        "fajr:late:-3", "dhuhr:onTime:-3", "asr:onTime:-3", "maghrib:onTime:-3", "isha:onTime:-3",
        "fajr:onTime:-4", "dhuhr:onTime:-4", "asr:onTime:-4", "maghrib:onTime:-4", "isha:onTime:-4",
        "fajr:onTime:-5", "dhuhr:late:-5", "asr:onTime:-5", "maghrib:onTime:-5", "isha:onTime:-5",
        "fajr:onTime:-6", "dhuhr:onTime:-6", "asr:onTime:-6", "maghrib:onTime:-6", "isha:onTime:-6",
        "fajr:onTime:0", "dhuhr:onTime:0", "asr:onTime:0"
    ].joined(separator: ";")

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

        // 3. Logging: the two axes, with an open window.
        capture("store-3-logging", arguments: [
            "-IhsanNowOverride", Self.afternoon,
            "-IhsanDebugLogPrayer", Self.seededMonth,
            "-IhsanDebugPresentLogSheet", "dhuhr"
        ], settle: 3.5)

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

        // 6. The nightstand face.
        capture("store-6-standby", arguments: [
            "-IhsanNowOverride", Self.night,
            "-IhsanDebugLogPrayer", Self.seededMonth,
            "-IhsanDebugWidgetGallery"
        ], settle: 3.5, scrollsToBottom: true)
    }

    @MainActor
    private func capture(
        _ name: String,
        arguments: [String],
        settle: TimeInterval = 3.0,
        scrollsToBottom: Bool = false
    ) {
        let app = XCUIApplication()
        app.launchArguments = [
            "-IhsanDebugCompletedOnboarding",
            "-IhsanDebugResetStore"
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

        if scrollsToBottom {
            for _ in 0..<4 {
                app.swipeUp(velocity: .fast)
                Thread.sleep(forTimeInterval: 0.4)
            }
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
