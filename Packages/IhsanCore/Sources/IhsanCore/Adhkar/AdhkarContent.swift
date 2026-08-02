import Foundation

// The bundled remembrance content.
//
// Every word of Arabic, every translation, and every citation the app
// can ever display lives in ONE versioned file:
// `Resources/adhkar-content.json`. Nothing in Ihsan composes,
// paraphrases, completes, or "improves" a religious text — not the
// on-device model, not a formatter, not a fallback string. If a text
// is not in that file, the app has nothing to show.
//
// The file ships marked DRAFT and the app refuses to surface draft
// content in a release build (see `AdhkarAvailability`). The gate
// clears when a scholar has read `ADHKAR_REVIEW.md` and the
// maintainer flips `reviewStatus` to `reviewed`.

/// Which set an item belongs to. The categories are the day's
/// occasions, not a taxonomy for browsing — each one is offered in its
/// own window and nowhere else.
public enum AdhkarCategory: String, Codable, CaseIterable, Sendable {
    case morning
    case evening
    case postPrayer
    case sleep
    /// Occasioned duas (waking, the door, the table, the road). Carried
    /// in the content file and the review artifact; no surface offers
    /// them in this build.
    case situational

    /// The label a surface uses. Kept here so no screen invents one.
    public var displayName: String {
        switch self {
        case .morning: "Morning"
        case .evening: "Evening"
        case .postPrayer: "After prayer"
        case .sleep: "Before sleep"
        case .situational: "Occasions"
        }
    }

    /// The inscription-register label — the app's small-caps voice.
    public var inscription: String {
        switch self {
        case .morning: "MORNING ADHKĀR"
        case .evening: "EVENING ADHKĀR"
        case .postPrayer: "AFTER PRAYER"
        case .sleep: "BEFORE SLEEP"
        case .situational: "OCCASIONS"
        }
    }
}

/// Where a text comes from. `reference` is the collection's own
/// numbering where it is known; `needsVerification` marks the ones the
/// maintainer must have confirmed against a printed copy before the
/// review gate can clear. Marking uncertainty is the point — a
/// confidently wrong number is worse than an acknowledged gap.
public struct AdhkarSource: Codable, Sendable, Equatable, Hashable {
    public let collection: String
    public let reference: String
    public let needsVerification: Bool

    public init(collection: String, reference: String, needsVerification: Bool = false) {
        self.collection = collection
        self.reference = reference
        self.needsVerification = needsVerification
    }

    private enum CodingKeys: String, CodingKey {
        case collection, reference, needsVerification
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        collection = try container.decode(String.self, forKey: .collection)
        reference = try container.decode(String.self, forKey: .reference)
        needsVerification = try container.decodeIfPresent(
            Bool.self, forKey: .needsVerification
        ) ?? false
    }

    /// The one line a surface shows when the reader asks where a text
    /// came from.
    public var citation: String {
        reference.isEmpty ? collection : "\(collection) \(reference)"
    }
}

/// One remembrance: the Arabic as transmitted, its transliteration,
/// its translation, its source, and the count it is said.
public struct AdhkarItem: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let id: String
    public let category: AdhkarCategory
    /// Position in the set's customary sequence, 1-based.
    public let order: Int
    /// Arabic with full tashkeel, exactly as it appears in the source.
    public let arabic: String
    public let transliteration: String
    public let translation: String
    public let source: AdhkarSource
    /// The transmitted count, or 1 where none is transmitted.
    public let repetitions: Int
    /// The occasion, for situational items; nil elsewhere.
    public let note: String?

    public init(
        id: String,
        category: AdhkarCategory,
        order: Int,
        arabic: String,
        transliteration: String,
        translation: String,
        source: AdhkarSource,
        repetitions: Int,
        note: String? = nil
    ) {
        self.id = id
        self.category = category
        self.order = order
        self.arabic = arabic
        self.transliteration = transliteration
        self.translation = translation
        self.source = source
        self.repetitions = repetitions
        self.note = note
    }
}

/// Whether a human scholar has read the content file.
public enum AdhkarReviewStatus: String, Codable, Sendable {
    /// Transcribed and awaiting review. Release builds show nothing.
    case draft
    /// A scholar has read `ADHKAR_REVIEW.md` and the maintainer has
    /// cleared the gate.
    case reviewed
}

/// The whole bundled file, parsed.
public struct AdhkarContent: Codable, Sendable, Equatable {
    /// Bumped when the SHAPE of the file changes. The loader refuses a
    /// version it was not written for rather than guessing.
    public let schemaVersion: Int
    /// Bumped when the CONTENT changes — dated, human-readable.
    public let contentVersion: String
    public let reviewStatus: AdhkarReviewStatus
    /// The review request, carried in the file itself so it cannot be
    /// separated from the texts it governs.
    public let reviewNote: String
    public let items: [AdhkarItem]

    public init(
        schemaVersion: Int,
        contentVersion: String,
        reviewStatus: AdhkarReviewStatus,
        reviewNote: String,
        items: [AdhkarItem]
    ) {
        self.schemaVersion = schemaVersion
        self.contentVersion = contentVersion
        self.reviewStatus = reviewStatus
        self.reviewNote = reviewNote
        self.items = items
    }

    /// One set, in its customary sequence.
    public func items(in category: AdhkarCategory) -> [AdhkarItem] {
        items.filter { $0.category == category }.sorted { $0.order < $1.order }
    }
}
