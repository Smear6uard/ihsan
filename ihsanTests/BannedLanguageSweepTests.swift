import Foundation
import Testing

/// The Repair banned-language list, applied to every file the wider-
/// worship prompt added: no streaks, no scoring, no celebration
/// states, no negative fasting language — the app records worship
/// factually and kindly. The sweep reads the sources themselves so a
/// stray string cannot ship unnoticed.
@Suite("Banned language sweep")
struct BannedLanguageSweepTests {

    private static let bannedFragments: [String] = [
        "streak", "badge", "congratulation", "congrats", "well done",
        "great job", "keep it up", "on fire", "don't break", "do not break",
        "broken fast", "you missed", "you failed", "failure",
        "fell short", "behind on", "catch up",
    ]

    /// New user-facing sources of this prompt, relative to the repo
    /// root.
    private static let sweptFiles: [String] = [
        "ihsan/Today/Helpers/FastingDayModel.swift",
        "ihsan/Today/Components/HijriMonthSheet.swift",
        "ihsan/Today/Components/TodayHeader.swift",
        "ihsan/Dhikr/DhikrScreen.swift",
        "ihsan/App/TabGlyphs.swift",
        "ihsan/Repair/Components/RepairSheets.swift",
        "Packages/IhsanCore/Sources/IhsanCore/Hijri/HijriConverter.swift",
        "Packages/IhsanCore/Sources/IhsanCore/Enums/FastKind.swift",
        "Packages/IhsanCore/Sources/IhsanCore/Enums/DhikrPhrase.swift",
        "Packages/IhsanCore/Sources/IhsanCore/Models/FastLog.swift",
        "Packages/IhsanCore/Sources/IhsanCore/Models/DhikrSession.swift",
        "Packages/IhsanIntents/Sources/IhsanIntents/Intents/LogFastIntent.swift",
        "Packages/IhsanIntents/Sources/IhsanIntents/Intents/StartTasbihIntent.swift",
        "Packages/IhsanIntents/Sources/IhsanIntents/Intents/SaveDhikrSessionIntent.swift",
    ]

    private var repoRoot: URL {
        // …/ihsanTests/BannedLanguageSweepTests.swift → repo root.
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    @Test
    func newSurfacesCarryNoBannedLanguage() throws {
        for relative in Self.sweptFiles {
            let url = repoRoot.appendingPathComponent(relative)
            let source = try String(contentsOf: url, encoding: .utf8).lowercased()
            for fragment in Self.bannedFragments {
                #expect(
                    !source.contains(fragment),
                    "\(relative) contains banned fragment '\(fragment)'"
                )
            }
        }
    }

    /// The fasting model has no representable negative state — the
    /// enum itself is the proof, pinned here so a future case can't
    /// arrive quietly.
    @Test
    func fastStateHasNoNegativeCase() throws {
        let url = repoRoot.appendingPathComponent(
            "Packages/IhsanCore/Sources/IhsanCore/Enums/FastKind.swift"
        )
        let source = try String(contentsOf: url, encoding: .utf8)
        #expect(source.contains("case intended"))
        #expect(source.contains("case kept"))
        for negative in ["case broken", "case failed", "case missed", "case lapsed"] {
            #expect(!source.contains(negative), "FastState grew a negative case: \(negative)")
        }
    }
}
