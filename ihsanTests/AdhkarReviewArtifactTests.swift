import Foundation
import Testing

/// `ADHKAR_REVIEW.md` is what a scholar actually reads. It is generated
/// from the content file by `docs/adhkar/generate-review.py`, and these
/// tests hold the two of them together: a text that ships must be a
/// text that was reviewed.
///
/// If one of these fails, the fix is to regenerate the document —
/// never to edit it by hand.
@Suite("Adhkar review artifact")
struct AdhkarReviewArtifactTests {

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var reviewDocument: String {
        get throws {
            try String(
                contentsOf: repoRoot.appending(path: "ADHKAR_REVIEW.md"),
                encoding: .utf8
            )
        }
    }

    private struct Content: Decodable {
        struct Source: Decodable {
            let collection: String
            let reference: String
            let needsVerification: Bool?
        }
        struct Item: Decodable {
            let id: String
            let category: String
            let arabic: String
            let translation: String
            let source: Source
            let repetitions: Int
        }
        let reviewStatus: String
        let items: [Item]
    }

    private var content: Content {
        get throws {
            let url = repoRoot.appending(
                path: "Packages/IhsanCore/Sources/IhsanCore/Resources/adhkar-content.json"
            )
            return try JSONDecoder().decode(Content.self, from: Data(contentsOf: url))
        }
    }

    @Test("Every item in the content file is in the review document")
    func everyItemIsUpForReview() throws {
        let document = try reviewDocument
        for item in try content.items {
            #expect(
                document.contains("`\(item.id)`"),
                "\(item.id) ships but is not in ADHKAR_REVIEW.md — regenerate it"
            )
            #expect(
                document.contains(item.arabic),
                "\(item.id)'s Arabic in the review document does not match the content file"
            )
            #expect(
                document.contains(item.translation),
                "\(item.id)'s translation in the review document does not match the content file"
            )
        }
    }

    /// One checkbox per item, so a reviewer cannot sign off on the set
    /// without having passed each text.
    @Test("Every item has its own checkbox")
    func everyItemHasACheckbox() throws {
        let document = try reviewDocument
        let expected = try content.items.count
        let boxes = document.components(
            separatedBy: "- [ ] Arabic, translation, source, and count are all correct."
        ).count - 1
        #expect(boxes == expected, "\(boxes) checkboxes for \(expected) items")
    }

    /// Uncertain citations are flagged where the reviewer will see
    /// them, not only in the JSON.
    @Test("References needing verification are flagged in the document")
    func uncertainReferencesAreFlagged() throws {
        let document = try reviewDocument
        let flagged = try content.items.filter { $0.source.needsVerification == true }
        #expect(!flagged.isEmpty, "nothing is flagged — that is suspicious, not clean")

        let markers = document.components(separatedBy: "⚠ verify reference").count - 1
        #expect(
            markers == flagged.count,
            "\(markers) flags in the document for \(flagged.count) flagged references"
        )
    }

    @Test("The document says the content is draft, because it is")
    func documentCarriesTheDraftStatus() throws {
        let document = try reviewDocument
        let status = try content.reviewStatus
        #expect(document.contains("DRAFT — PENDING SCHOLAR REVIEW"))
        #expect(status == "draft")
    }

    /// The document explains the gate and names the code that enforces
    /// it, so a reader can check the claim rather than trust it.
    @Test("The document explains the gate and names its enforcement")
    func documentExplainsTheGate() throws {
        let document = try reviewDocument
        #expect(document.contains("AdhkarAvailability"))
        #expect(document.contains("reviewStatus"))
    }
}
