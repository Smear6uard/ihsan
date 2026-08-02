import Foundation
import Testing
@testable import IhsanCore

/// The bundled remembrance file is the only place a religious text can
/// come from, so it is the only thing standing between the app and
/// showing someone a broken or half-transcribed duʿāʾ. These tests read
/// the shipped file itself — not a fixture — and refuse anything
/// incomplete.
@Suite("Bundled adhkar content")
struct AdhkarContentTests {

    private func content() throws -> AdhkarContent {
        try #require(BundledAdhkar.content, "bundled content failed to load: \(String(describing: BundledAdhkar.loadError))")
    }

    @Test("The shipped file parses")
    func bundledFileLoads() throws {
        #expect(BundledAdhkar.loadError == nil)
        let content = try content()
        #expect(content.schemaVersion == AdhkarContentLoader.supportedSchemaVersion)
        #expect(!content.contentVersion.isEmpty)
        #expect(!content.items.isEmpty)
    }

    /// Every field the reader sees, on every item. A blank translation
    /// or a missing citation is a shipping defect, not a display edge
    /// case.
    @Test("Every item carries Arabic, transliteration, translation, source, and a count")
    func everyItemIsComplete() throws {
        for item in try content().items {
            #expect(!item.arabic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(item.id) arabic")
            #expect(!item.transliteration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(item.id) transliteration")
            #expect(!item.translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(item.id) translation")
            #expect(!item.source.collection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(item.id) source.collection")
            #expect(!item.source.reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(item.id) source.reference")
            #expect(item.repetitions >= 1, "\(item.id) repetitions")
        }
    }

    /// Full tashkeel is the whole reason the Arabic typography work
    /// exists. An item transcribed bare would render as a different
    /// text to a reader learning it by sight.
    @Test("Every Arabic text carries tashkeel")
    func arabicIsVocalised() throws {
        // Fatḥatan…sukūn, plus the superscript alif used in ٱللَّٰه forms.
        let marks = CharacterSet(charactersIn: "\u{064B}"..."\u{0652}")
            .union(CharacterSet(charactersIn: "\u{0670}"))

        for item in try content().items {
            let hasMarks = item.arabic.unicodeScalars.contains { marks.contains($0) }
            #expect(hasMarks, "\(item.id) has no tashkeel")
        }
    }

    /// Nothing but Arabic script, marks, punctuation and spaces may
    /// appear in an Arabic field — a stray Latin character means a
    /// transcription slipped.
    @Test("Arabic fields hold only Arabic")
    func arabicFieldsAreArabic() throws {
        let latin = CharacterSet.init(charactersIn: "a"..."z")
            .union(CharacterSet(charactersIn: "A"..."Z"))
        for item in try content().items {
            let stray = item.arabic.unicodeScalars.filter { latin.contains($0) }
            #expect(stray.isEmpty, "\(item.id) has Latin characters in its Arabic")
        }
    }

    @Test("Identifiers are unique and namespaced by category")
    func identifiersAreWellFormed() throws {
        var seen = Set<String>()
        for item in try content().items {
            #expect(seen.insert(item.id).inserted, "duplicate id \(item.id)")
            #expect(
                item.id.hasPrefix("\(item.category.rawValue)."),
                "\(item.id) is not namespaced by its category"
            )
        }
    }

    /// Each set runs 1…n with no gaps: the reader walks a sequence, and
    /// a hole in it would silently drop a text.
    @Test("Each set's order is contiguous from one")
    func ordersAreContiguous() throws {
        let content = try content()
        for category in AdhkarCategory.allCases {
            let orders = content.items(in: category).map(\.order)
            guard !orders.isEmpty else { continue }
            #expect(
                orders == Array(1...orders.count),
                "\(category.rawValue) order is \(orders)"
            )
        }
    }

    /// Curated scope, held in a test rather than in a promise. Growth
    /// past this line is the moment the feature would start becoming
    /// the library it must not be.
    @Test("The set stays curated")
    func scopeStaysSmall() throws {
        let content = try content()
        #expect(content.items.count <= 60, "\(content.items.count) items — past the curated ceiling")

        for category in AdhkarCategory.allCases {
            let count = content.items(in: category).count
            #expect(count > 0, "\(category.rawValue) is empty")
        }
        #expect(content.items(in: .situational).count <= 10)
    }

    /// The transmitted counts the reader will actually be asked to
    /// keep. Anything outside this set is a transcription slip, not a
    /// new practice.
    @Test("Repetition counts are transmitted ones")
    func repetitionsAreTransmitted() throws {
        let known: Set<Int> = [1, 3, 7, 10, 33, 34, 100]
        for item in try content().items {
            #expect(known.contains(item.repetitions), "\(item.id) count \(item.repetitions)")
        }
    }
}

/// The scholar-review gate. Its whole value is that it cannot be
/// forgotten, so it is asserted from both ends: the file is draft, and
/// a draft file is invisible to a release build.
@Suite("Adhkar review gate")
struct AdhkarReviewGateTests {

    @Test("The shipped content is still marked draft")
    func contentIsDraft() throws {
        let content = try #require(BundledAdhkar.content)
        #expect(
            content.reviewStatus == .draft,
            "The content file claims review is complete. If a scholar has signed ADHKAR_REVIEW.md, delete this expectation deliberately in the same commit."
        )
        #expect(content.reviewNote.contains("PENDING SCHOLAR REVIEW"))
    }

    /// The gate, exercised. A DEBUG build keeps the surfaces so the
    /// maintainer can review them on device; a release build has no
    /// adhkar at all while the file is draft.
    @Test("Draft content is unavailable in a release build")
    func draftIsGated() {
        #if DEBUG
        #expect(AdhkarAvailability.isAvailable)
        #expect(AdhkarAvailability.isShowingDraftContent)
        #else
        #expect(!AdhkarAvailability.isAvailable)
        #expect(!AdhkarAvailability.isShowingDraftContent)
        #endif
    }
}

/// The loader refuses malformed content rather than rendering part of
/// it. A partially-loaded religious text is worse than none, because
/// the reader cannot tell what is missing.
@Suite("Adhkar content loader")
struct AdhkarContentLoaderTests {

    private func json(
        schemaVersion: Int = 1,
        reviewStatus: String = "draft",
        items: String
    ) -> Data {
        Data("""
        {
          "schemaVersion": \(schemaVersion),
          "contentVersion": "test",
          "reviewStatus": "\(reviewStatus)",
          "reviewNote": "PENDING SCHOLAR REVIEW",
          "items": [\(items)]
        }
        """.utf8)
    }

    private func item(
        id: String = "morning.one",
        order: Int = 1,
        arabic: String = "سُبْحَانَ اللَّهِ",
        translation: String = "Glory is to Allah.",
        reference: String = "2691",
        repetitions: Int = 1
    ) -> String {
        """
        {
          "id": "\(id)", "category": "morning", "order": \(order),
          "arabic": "\(arabic)", "transliteration": "Subḥāna'llāh.",
          "translation": "\(translation)",
          "source": { "collection": "Muslim", "reference": "\(reference)" },
          "repetitions": \(repetitions)
        }
        """
    }

    @Test("A well-formed file parses")
    func wellFormedParses() throws {
        let content = try AdhkarContentLoader.parse(json(items: item()))
        #expect(content.items.count == 1)
        #expect(content.items[0].source.needsVerification == false)
        #expect(content.items[0].source.citation == "Muslim 2691")
    }

    @Test("A future schema version is refused, not guessed at")
    func futureSchemaIsRefused() {
        #expect(throws: AdhkarContentError.unsupportedSchemaVersion(found: 2, supported: 1)) {
            try AdhkarContentLoader.parse(json(schemaVersion: 2, items: item()))
        }
    }

    @Test("An empty translation fails the whole file")
    func emptyFieldIsFatal() {
        #expect(throws: AdhkarContentError.incompleteItem(id: "morning.one", field: "translation")) {
            try AdhkarContentLoader.parse(json(items: item(translation: "")))
        }
    }

    @Test("An empty source reference fails the whole file")
    func emptySourceIsFatal() {
        #expect(throws: AdhkarContentError.incompleteItem(id: "morning.one", field: "source.reference")) {
            try AdhkarContentLoader.parse(json(items: item(reference: "")))
        }
    }

    @Test("A zero repetition count fails the whole file")
    func zeroRepetitionIsFatal() {
        #expect(throws: AdhkarContentError.incompleteItem(id: "morning.one", field: "repetitions")) {
            try AdhkarContentLoader.parse(json(items: item(repetitions: 0)))
        }
    }

    @Test("Duplicate identifiers fail the whole file")
    func duplicateIdentifierIsFatal() {
        let two = item(id: "morning.one", order: 1) + "," + item(id: "morning.one", order: 2)
        #expect(throws: AdhkarContentError.duplicateIdentifier("morning.one")) {
            try AdhkarContentLoader.parse(json(items: two))
        }
    }

    @Test("Two items claiming one position fail the whole file")
    func duplicateOrderIsFatal() {
        let two = item(id: "morning.one", order: 1) + "," + item(id: "morning.two", order: 1)
        #expect(throws: AdhkarContentError.duplicateOrder(category: .morning, order: 1)) {
            try AdhkarContentLoader.parse(json(items: two))
        }
    }

    @Test("Unparseable JSON is reported, never partially applied")
    func malformedJSONIsReported() {
        #expect(throws: (any Error).self) {
            try AdhkarContentLoader.parse(Data("{ not json".utf8))
        }
    }

    /// Sets come back in their customary sequence regardless of the
    /// order the file happens to list them in.
    @Test("Items come back in sequence")
    func itemsSortByOrder() throws {
        let unordered = item(id: "morning.two", order: 2) + "," + item(id: "morning.one", order: 1)
        let content = try AdhkarContentLoader.parse(json(items: unordered))
        #expect(content.items(in: .morning).map(\.id) == ["morning.one", "morning.two"])
    }
}
