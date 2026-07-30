import Foundation
import Testing

/// The haptic vocabulary, enforced against the sources.
///
/// Every worship commit makes the same physical event under the thumb:
/// `Haptics.settle()`. The rule is easy to break by accident, because
/// `Haptics.success()` is right there and reads as "it worked" — which
/// is exactly what a worship commit must not say. Before this pass six
/// different commits made five different feelings.
///
/// Reading the sources is the only way to catch it: nothing about a
/// wrong haptic fails at runtime, and nobody notices in a screenshot.
@Suite("Haptic vocabulary")
struct HapticVocabularyTests {

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appending(path: path), encoding: .utf8)
    }

    /// Every surface that records an act of worship.
    private static let worshipCommitSites: [String] = [
        "ihsan/Today/Components/PrayerLogSheet.swift",
        "ihsan/Today/Components/FocusedPrayerCard.swift",
        "ihsan/Today/Components/YesterdaySheet.swift",
        "ihsan/Reflection/Helpers/ReflectionHaptics.swift",
        "ihsan/Today/ViewModel/TodayViewModel.swift",
        "ihsan/Today/TodayScreen.swift",
        "ihsan/Dhikr/DhikrScreen.swift",
        "ihsan/Qibla/ViewModel/QiblaViewModel.swift",
    ]

    /// The only places allowed to fire a success notification: an
    /// operation either succeeded or failed, and the person needs to
    /// know which. None of them is an act of worship.
    private static let successAllowlist: [String] = [
        "ihsan/Settings/SettingsScreen.swift",       // export, delete-all
        "ihsan/Repair/Components/RepairSheets.swift", // ledger setup
        "ihsan/Repair/RepairSetupSteps.swift",        // ledger setup
        "ihsan/MasjidFinder/MasjidFinderScreen.swift" // directions handed off
    ]

    @Test("Every worship commit uses the settle, and none reaches for success")
    func worshipCommitsSpeakOneLanguage() throws {
        for path in Self.worshipCommitSites {
            let text = try source(path)

            #expect(
                text.contains("Haptics.settle()"),
                "\(path) records worship but never settles."
            )
            #expect(
                !text.contains("Haptics.success()"),
                "\(path) applauds a worship commit. Worship is recorded, not applauded."
            )
            #expect(
                !text.contains("Haptics.notification(.success)"),
                "\(path) applauds a worship commit. Worship is recorded, not applauded."
            )
        }
    }

    @Test("Success notifications stay on the allowlist")
    func successIsReservedForOperations() throws {
        let manager = FileManager.default
        guard let walker = manager.enumerator(
            at: repoRoot.appending(path: "ihsan"),
            includingPropertiesForKeys: nil
        ) else {
            Issue.record("Could not walk the app sources")
            return
        }

        for case let url as URL in walker where url.pathExtension == "swift" {
            let relative = url.path.replacingOccurrences(
                of: repoRoot.path + "/", with: ""
            )
            guard !Self.successAllowlist.contains(relative) else { continue }

            let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            if text.contains("Haptics.success()")
                || text.contains("Haptics.notification(.success)") {
                Issue.record("\(relative) fires a success notification; if it records worship it wants settle(), and if it is an operation it belongs on the allowlist with a reason")
            }
        }
    }

    @Test("Feedback generators live in exactly one file")
    func nothingBuildsItsOwnGenerators() throws {
        let manager = FileManager.default
        let roots = ["ihsan", "ihsanWatch", "ihsanWidgets"]
        let generators = ["UIImpactFeedbackGenerator", "UINotificationFeedbackGenerator"]

        for root in roots {
            guard let walker = manager.enumerator(
                at: repoRoot.appending(path: root), includingPropertiesForKeys: nil
            ) else { continue }

            for case let url as URL in walker where url.pathExtension == "swift" {
                // The one file allowed to own them.
                guard url.lastPathComponent != "Haptics.swift" else { continue }
                let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                for generator in generators where text.contains(generator) {
                    Issue.record("\(url.lastPathComponent) builds its own \(generator); every haptic routes through Haptics")
                }
            }
        }
    }

    @Test("The vocabulary is written down")
    func theVocabularyIsDocumented() throws {
        let doc = try source("docs/haptics.md")
        for call in ["settle()", "impact(.light)", "impact(.medium)", "notification(.warning)"] {
            #expect(doc.contains(call), "docs/haptics.md does not describe \(call).")
        }
    }
}
