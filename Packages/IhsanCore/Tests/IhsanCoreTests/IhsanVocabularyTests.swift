import IhsanCore
import XCTest

/// Pins the canonical romanization so no surface can drift back to
/// apostrophes, middle dots, or bare 'a's: jamāʿah is spelled with
/// the macron ā (U+0101) and the ʿayn half-ring ʿ (U+02BF),
/// everywhere.
final class IhsanVocabularyTests: XCTestCase {

    func testCanonicalSpellingUsesMacronAndAyn() {
        XCTAssertEqual(IhsanVocabulary.jamaah, "jam\u{0101}\u{02BF}ah")
        XCTAssertEqual(IhsanVocabulary.jamaahTitle, "Jam\u{0101}\u{02BF}ah")
        XCTAssertEqual(IhsanVocabulary.jamaahInscription, "JAM\u{0100}\u{02BF}AH")
        XCTAssertEqual(IhsanVocabulary.inJamaahTitle, "In Jam\u{0101}\u{02BF}ah")
    }

    func testFormsAgreeOnTheSameWord() {
        XCTAssertEqual(IhsanVocabulary.jamaahTitle.lowercased(), IhsanVocabulary.jamaah)
        XCTAssertEqual(
            IhsanVocabulary.jamaahInscription.lowercased(),
            IhsanVocabulary.jamaah.lowercased()
        )
        XCTAssertTrue(IhsanVocabulary.inJamaahTitle.hasSuffix(IhsanVocabulary.jamaahTitle))
    }
}
