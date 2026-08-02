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
        // The remembrance layer.
        "ihsan/Adhkar/AdhkarQuietCard.swift",
        "ihsan/Adhkar/AdhkarSetScreen.swift",
        "ihsan/Adhkar/Helpers/AdhkarOffer.swift",
        "ihsan/Adhkar/ViewModel/AdhkarSetState.swift",
        "Packages/IhsanCore/Sources/IhsanCore/Adhkar/AdhkarContent.swift",
        "Packages/IhsanCore/Sources/IhsanCore/Adhkar/AdhkarContentLoader.swift",
        "Packages/IhsanCore/Sources/IhsanCore/Models/AdhkarSession.swift",
        "Packages/IhsanCore/Sources/IhsanCore/Resources/adhkar-content.json",
        "Packages/IhsanPrayerTimes/Sources/IhsanPrayerTimes/AdhkarWindows.swift",
        "Packages/IhsanIntents/Sources/IhsanIntents/Intents/SaveAdhkarSessionIntent.swift",
        "Packages/IhsanDesignSystem/Sources/IhsanDesignSystem/Components/AdhkarSequenceBand.swift",
        "Packages/IhsanDesignSystem/Sources/IhsanDesignSystem/Components/RemembranceRing.swift",
        "Packages/IhsanDesignSystem/Sources/IhsanDesignSystem/Components/ArabicScriptText.swift",
    ]

    private var repoRoot: URL {
        // …/ihsanTests/BannedLanguageSweepTests.swift → repo root.
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    /// The words a person can read, not the words a compiler can.
    ///
    /// Swift identifiers are not copy: `Result.failure` is a language
    /// construct, and failing a file for containing it would push
    /// someone into contorting real code to satisfy a text search.
    /// Comments are not copy either, and the honest ones say things
    /// like "no streaks" precisely because there are none. So a Swift
    /// file is swept through its STRING LITERALS, which is what ships
    /// on a screen; other files are swept whole.
    private func sweptText(of source: String, isSwift: Bool) -> String {
        guard isSwift else { return source.lowercased() }
        var literals: [String] = []
        for line in source.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("//") else { continue }
            var inLiteral = false
            var current = ""
            var previous: Character?
            for character in line {
                if character == "\"" && previous != "\\" {
                    if inLiteral { literals.append(current); current = "" }
                    inLiteral.toggle()
                } else if inLiteral {
                    current.append(character)
                }
                previous = character
            }
        }
        return literals.joined(separator: "\n").lowercased()
    }

    @Test
    func newSurfacesCarryNoBannedLanguage() throws {
        for relative in Self.sweptFiles {
            let url = repoRoot.appendingPathComponent(relative)
            let source = try String(contentsOf: url, encoding: .utf8)
            let swept = sweptText(of: source, isSwift: relative.hasSuffix(".swift"))
            for fragment in Self.bannedFragments {
                #expect(
                    !swept.contains(fragment),
                    "\(relative) contains banned fragment '\(fragment)' in copy"
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

/// The remembrance layer's own copy rules, beyond the shared banned
/// list.
///
/// The specific failure mode here is not a cheerful string — it is a
/// FIGURE. A percentage, a total across days, a running score: any of
/// those turns a record into a report card, and this layer sits closer
/// to that line than anything else in the app because it counts.
@Suite("Adhkar copy discipline")
struct AdhkarCopyDisciplineTests {

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appending(path: path), encoding: .utf8)
    }

    /// `AdhkarSession`'s stored properties, pinned.
    ///
    /// It records how many items were counted and NOT how many there
    /// were. Without the denominator, no percentage can be computed
    /// from the record — which is the point, and is the kind of thing
    /// that gets added later by someone being helpful. Adding a field
    /// here should take a deliberate edit to this list.
    @Test("The session record carries no denominator")
    func sessionHasNoSetSize() throws {
        let text = try source("Packages/IhsanCore/Sources/IhsanCore/Models/AdhkarSession.swift")

        let declared = Set(
            text.split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.hasPrefix("public var ") }
                .compactMap { line -> String? in
                    line.dropFirst("public var ".count)
                        .prefix { $0.isLetter || $0.isNumber || $0 == "_" }
                        .description
                }
        )

        #expect(
            declared == [
                "id", "sessionDate", "categoryRaw", "completedItemCount",
                "startedAt", "loggedTimeZoneIdentifier", "sourceSurfaceRaw",
                "createdAt", "modifiedAt",
            ],
            "AdhkarSession's fields changed: \(declared.sorted())"
        )
    }

    /// No adhkar surface divides one count by another. A proportion
    /// rendered anywhere is a score, whatever it is called.
    @Test("No adhkar surface computes a proportion")
    func noSurfaceComputesAProportion() throws {
        for path in [
            "ihsan/Adhkar/AdhkarSetScreen.swift",
            "ihsan/Adhkar/AdhkarQuietCard.swift",
            "ihsan/Adhkar/ViewModel/AdhkarSetState.swift",
            "ihsan/Adhkar/Helpers/AdhkarOffer.swift",
        ] {
            let text = try source(path)
            for line in text.split(separator: "\n") {
                let code = line.trimmingCharacters(in: .whitespaces)
                guard !code.hasPrefix("//"), !code.hasPrefix("///") else { continue }
                let divides = code.contains("Double(") && code.contains("/")
                #expect(!divides, "\(path) divides counts: \(code)")
            }
        }
    }
}
