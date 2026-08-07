import Foundation
import IhsanCore
import Testing

/// The boundaries this feature must not cross, enforced against
/// the sources because neither of them fails at runtime.
///
/// 1. **Adhkar UI never schedules directly.** Reminder policy stays in
///    the notification layer, where it is opt-in, silent, and bounded
///    to the morning and evening windows.
/// 2. **No religious text exists outside the versioned content file.**
///    Not a fallback string, not a preview constant, not a test
///    fixture that drifted into a shipping source. If it is not in
///    `adhkar-content.json`, the app cannot show it.
@Suite("Adhkar boundaries")
struct AdhkarBoundaryTests {

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    /// Every source this feature added or touched, on the app side and
    /// in the packages.
    private static let adhkarSources: [String] = [
        "ihsan/Adhkar/AdhkarQuietCard.swift",
        "ihsan/Adhkar/AdhkarSetScreen.swift",
        "ihsan/Adhkar/AdhkarTypeGalleryScreen.swift",
        "ihsan/Adhkar/Helpers/AdhkarOffer.swift",
        "ihsan/Adhkar/ViewModel/AdhkarSetState.swift",
        "Packages/IhsanCore/Sources/IhsanCore/Adhkar/AdhkarContent.swift",
        "Packages/IhsanCore/Sources/IhsanCore/Adhkar/AdhkarContentLoader.swift",
        "Packages/IhsanCore/Sources/IhsanCore/Models/AdhkarSession.swift",
        "Packages/IhsanPrayerTimes/Sources/IhsanPrayerTimes/AdhkarWindows.swift",
        "Packages/IhsanIntents/Sources/IhsanIntents/Intents/SaveAdhkarSessionIntent.swift",
        "Packages/IhsanDesignSystem/Sources/IhsanDesignSystem/Components/AdhkarSequenceBand.swift",
        "Packages/IhsanDesignSystem/Sources/IhsanDesignSystem/Components/RemembranceRing.swift",
        "Packages/IhsanDesignSystem/Sources/IhsanDesignSystem/Components/ArabicScriptText.swift",
        "Packages/IhsanDesignSystem/Sources/IhsanDesignSystem/Tokens/IhsanArabicType.swift",
        "Packages/IhsanDesignSystem/Sources/IhsanDesignSystem/Previews/AdhkarTypeGallery.swift",
    ]

    private func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appending(path: path), encoding: .utf8)
    }

    // MARK: - Notification separation

    @Test("No adhkar source reaches for a notification")
    func nothingSchedulesANotification() throws {
        let forbidden = [
            "UNUserNotificationCenter",
            "UNNotificationRequest",
            "UNMutableNotificationContent",
            "NotificationScheduler",
            "import UserNotifications",
            "BGTaskScheduler",
            "AlarmManager",
        ]
        for path in Self.adhkarSources {
            let text = try source(path)
            for fragment in forbidden {
                #expect(
                    !text.contains(fragment),
                    "\(path) reaches for \(fragment) — the windows offer, they never call"
                )
            }
        }
    }

    @Test("Adhkar reminder content is explicitly quiet")
    func notificationLayerKeepsAdhkarQuiet() throws {
        let text = try source(
            "Packages/IhsanNotifications/Sources/IhsanNotifications/NotificationContent.swift"
        )
        guard let start = text.range(of: "public static func makeAdhkarContent"),
              let end = text.range(of: "private static func localizedTimeString", range: start.upperBound..<text.endIndex) else {
            Issue.record("the adhkar reminder factory is missing")
            return
        }
        let factory = String(text[start.lowerBound..<end.lowerBound])
        #expect(factory.contains("content.sound = nil"))
        #expect(!factory.contains(".timeSensitive"))
        #expect(!factory.contains("displayNameArabic"))
    }

    // MARK: - One source of text

    /// Arabic script anywhere in a shipping source, outside the content
    /// file, means a religious text has escaped the review gate.
    ///
    /// Two exemptions, both single words that are chrome rather than
    /// text to be recited: the prayer names and the dhikr phrases,
    /// which predate this feature and belong to their own surfaces.
    @Test("No Arabic script lives in an adhkar source")
    func noArabicOutsideTheContentFile() throws {
        // The Arabic block, excluding the space and punctuation that
        // appear in transliteration.
        let arabic = CharacterSet(charactersIn: "\u{0600}"..."\u{06FF}")
            .union(CharacterSet(charactersIn: "\u{0750}"..."\u{077F}"))
            .union(CharacterSet(charactersIn: "\u{FB50}"..."\u{FEFF}"))

        for path in Self.adhkarSources {
            let text = try source(path)
            // Comments explain the feature and may name a text; the
            // check is on code, so strip comment lines first.
            let code = text
                .split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")

            let stray = code.unicodeScalars.filter { arabic.contains($0) }
            #expect(
                stray.isEmpty,
                "\(path) carries Arabic script in code: \(String(String.UnicodeScalarView(stray)))"
            )
        }
    }

    /// The bundled file is the only resource any Arabic can come from.
    @Test("There is exactly one adhkar content resource")
    func oneContentResource() throws {
        let base = repoRoot.appending(path: "Packages")
        let walker = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil)
        let matches = (walker?.compactMap { $0 as? URL } ?? [])
            .filter { $0.lastPathComponent == "adhkar-content.json" }
            // Build output is not a source of Arabic — it is a copy of
            // the one source. SwiftPM writes `.build/`; an xcodebuild
            // run against a package (a watchOS build will do it) writes
            // `build/`, and that copy used to fail this test with a
            // second "content file" nobody had written.
            .filter { !$0.pathComponents.contains(".build") }
            .filter { !$0.pathComponents.contains("build") }
        #expect(matches.count == 1, "found \(matches.count) content files: \(matches.map(\.path))")
    }

    /// No path in the app generates, completes, or rewrites a
    /// remembrance. The on-device model never touches any of this.
    @Test("No adhkar source reaches for the on-device model")
    func nothingGeneratesReligiousText() throws {
        let forbidden = [
            "FoundationModels",
            "SystemLanguageModel",
            "LanguageModelSession",
            "IhsanInsights",
        ]
        for path in Self.adhkarSources {
            let text = try source(path)
            for fragment in forbidden {
                #expect(
                    !text.contains(fragment),
                    "\(path) reaches for \(fragment) — nothing may generate a religious text"
                )
            }
        }
    }
}
