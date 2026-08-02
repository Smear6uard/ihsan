import Foundation

public enum AdhkarContentError: Error, Equatable, Sendable {
    case resourceMissing
    /// The file declares a shape this build was not written for.
    case unsupportedSchemaVersion(found: Int, supported: Int)
    case malformed(String)
    /// A field the app depends on is empty. The loader refuses the
    /// whole file rather than rendering a half-item.
    case incompleteItem(id: String, field: String)
    case duplicateIdentifier(String)
    /// Two items in one set claim the same position.
    case duplicateOrder(category: AdhkarCategory, order: Int)
}

/// Reads and validates the bundled remembrance file.
///
/// Validation is total and fatal: an item missing its Arabic, its
/// translation, or its source fails the whole load. There is no
/// partial mode, because a partially-loaded religious text is worse
/// than none — the reader cannot tell which part is missing.
public enum AdhkarContentLoader {

    /// The file shape this build understands.
    public static let supportedSchemaVersion = 1

    public static let resourceName = "adhkar-content"

    /// Parse and validate JSON that is already in memory. The pure
    /// entry point — tests drive this directly.
    public static func parse(_ data: Data) throws -> AdhkarContent {
        let decoder = JSONDecoder()
        let content: AdhkarContent
        do {
            content = try decoder.decode(AdhkarContent.self, from: data)
        } catch {
            throw AdhkarContentError.malformed(String(describing: error))
        }

        guard content.schemaVersion == supportedSchemaVersion else {
            throw AdhkarContentError.unsupportedSchemaVersion(
                found: content.schemaVersion,
                supported: supportedSchemaVersion
            )
        }

        try validate(content)
        return content
    }

    /// Every rule the content must satisfy to be shown to anyone.
    public static func validate(_ content: AdhkarContent) throws {
        guard !content.contentVersion.trimmed.isEmpty else {
            throw AdhkarContentError.malformed("contentVersion is empty")
        }
        guard !content.reviewNote.trimmed.isEmpty else {
            throw AdhkarContentError.malformed("reviewNote is empty")
        }

        var seenIdentifiers = Set<String>()
        var seenPositions = Set<String>()

        for item in content.items {
            guard !item.id.trimmed.isEmpty else {
                throw AdhkarContentError.incompleteItem(id: "(blank)", field: "id")
            }
            guard seenIdentifiers.insert(item.id).inserted else {
                throw AdhkarContentError.duplicateIdentifier(item.id)
            }

            for (field, value) in [
                ("arabic", item.arabic),
                ("transliteration", item.transliteration),
                ("translation", item.translation),
                ("source.collection", item.source.collection),
                ("source.reference", item.source.reference)
            ] where value.trimmed.isEmpty {
                throw AdhkarContentError.incompleteItem(id: item.id, field: field)
            }

            guard item.repetitions >= 1 else {
                throw AdhkarContentError.incompleteItem(id: item.id, field: "repetitions")
            }
            guard item.order >= 1 else {
                throw AdhkarContentError.incompleteItem(id: item.id, field: "order")
            }

            let position = "\(item.category.rawValue)#\(item.order)"
            guard seenPositions.insert(position).inserted else {
                throw AdhkarContentError.duplicateOrder(
                    category: item.category, order: item.order
                )
            }
        }
    }

    /// Load the file that ships inside the package.
    public static func loadBundled() throws -> AdhkarContent {
        guard let url = Bundle.module.url(
            forResource: resourceName, withExtension: "json"
        ) else {
            throw AdhkarContentError.resourceMissing
        }
        return try parse(try Data(contentsOf: url))
    }
}

/// The parsed file, loaded once.
///
/// A failure here is a build defect, not a runtime condition — the
/// file ships inside the binary and the tests parse it on every run —
/// so the cache holds the error and every caller sees the same empty
/// content rather than the app half-working.
public enum BundledAdhkar {
    private static let cached: Result<AdhkarContent, any Error> = {
        Result { try AdhkarContentLoader.loadBundled() }
    }()

    /// The content, or nil if the bundled file failed to load.
    public static var content: AdhkarContent? {
        try? cached.get()
    }

    /// The load error, for the tests that assert there isn't one.
    public static var loadError: (any Error)? {
        switch cached {
        case .success: nil
        case .failure(let error): error
        }
    }

    public static func items(in category: AdhkarCategory) -> [AdhkarItem] {
        content?.items(in: category) ?? []
    }
}

/// Whether the app may show remembrance content at all.
///
/// The scholar-review gate, enforced in code rather than by
/// convention. While the bundled file is marked `draft`, a RELEASE
/// build has no adhkar: no cards, no Set group, no reader. A DEBUG
/// build keeps the surfaces so the maintainer can review typography
/// and behaviour on device, and says DRAFT plainly where it does.
///
/// The gate clears by flipping `reviewStatus` in the content file
/// after a scholar has signed off on `ADHKAR_REVIEW.md`. Nothing else
/// opens it.
public enum AdhkarAvailability {

    /// True when a surface may offer remembrance to this person.
    public static var isAvailable: Bool {
        guard let content = BundledAdhkar.content, !content.items.isEmpty else {
            return false
        }
        switch content.reviewStatus {
        case .reviewed:
            return true
        case .draft:
            #if DEBUG
            return true
            #else
            return false
            #endif
        }
    }

    /// True when the surfaces are showing texts a scholar has not yet
    /// cleared. Set says so; nothing else does.
    public static var isShowingDraftContent: Bool {
        isAvailable && BundledAdhkar.content?.reviewStatus == .draft
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
