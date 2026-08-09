import Foundation
import IhsanFiqhConfig
import Testing

/// `PATH_FIQH_REVIEW.md` is what a scholar actually reads. These hold
/// it and the shipped copy together in both directions: text that
/// ships must be text that was put up for review, and the document
/// cannot drift into describing copy the app no longer has.
///
/// There is no generator for this one — the document is maintained by
/// hand alongside the source — so the exact-match checks below are the
/// only thing keeping the two honest.
@Suite("Path fiqh review artifact")
struct PathFiqhReviewArtifactTests {

    private var reviewDocument: String {
        get throws {
            let root = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
            return try String(
                contentsOf: root.appending(path: "PATH_FIQH_REVIEW.md"),
                encoding: .utf8
            )
        }
    }

    /// Markdown hard-wraps the bodies; the shipped strings are single
    /// lines. Compare on collapsed whitespace so a rewrap is not a
    /// failure but a word change is.
    private func collapsed(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    @Test("Every shipped reading appears in the review document")
    func everyReadingIsUpForReview() throws {
        let document = collapsed(try reviewDocument)

        for kind in PathFindingKind.allCases {
            let framing = TrajectoryFindingFraming.standard(for: kind)
            #expect(
                document.contains(kind.rawValue),
                "\(kind.rawValue) is not named in PATH_FIQH_REVIEW.md"
            )
            #expect(
                document.contains(collapsed(framing.title)),
                "\(kind.rawValue) ships a title that was never reviewed"
            )
            #expect(
                document.contains(collapsed(framing.body)),
                "\(kind.rawValue) ships a body that was never reviewed"
            )
            #expect(
                document.contains(collapsed(framing.citation)),
                "\(kind.rawValue) ships a citation that was never reviewed"
            )
        }
    }

    /// The document names nine readings and the app has nine. A tenth
    /// heading here, or a tenth case there, has to be a deliberate edit
    /// to both.
    @Test("The document describes exactly the readings that exist")
    func documentCoversNoStaleReadings() throws {
        let document = try reviewDocument
        let headings = document
            .split(separator: "\n")
            .filter { $0.hasPrefix("## ") && $0.contains("`") }

        #expect(
            headings.count == PathFindingKind.allCases.count,
            Comment(rawValue: "the document lists \(headings.count) readings, the app has "
                + "\(PathFindingKind.allCases.count)")
        )
    }

    /// The gate is honest about itself. Until a scholar has signed off,
    /// the status line says so — flipping it is a deliberate edit made
    /// after review, not something that drifts.
    @Test("The review status is stated explicitly")
    func reviewStatusIsDeclared() throws {
        let document = try reviewDocument
        #expect(document.contains("**Status:"))
        #expect(
            document.contains("PENDING SCHOLAR REVIEW")
                || document.contains("REVIEWED"),
            "the document must declare one status or the other"
        )
    }

    /// The card renders no quotation marks, and the copy is written in
    /// indirect speech so that no English rendering is mistaken for
    /// transmitted wording.
    @Test("No reading presents itself as a quotation")
    func nothingIsQuoted() {
        let quotes = CharacterSet(charactersIn: #""“”„‟«»"#)
        for kind in PathFindingKind.allCases {
            let framing = TrajectoryFindingFraming.standard(for: kind)
            #expect(
                framing.body.rangeOfCharacter(from: quotes) == nil,
                "\(kind.rawValue) quotes a report directly"
            )
        }
    }
}
