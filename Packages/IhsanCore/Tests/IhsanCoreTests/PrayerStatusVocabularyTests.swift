import IhsanCore
import XCTest

/// Pins the timing vocabulary, and in particular the distinction that
/// this file exists to protect.
///
/// The bug that prompted it: `Late` was captioned "PRAYED AFTER ITS
/// WINDOW" while `Qadā` was captioned "MADE UP LATER" — two phrases for
/// the same fact, and neither of them the Hanafi distinction that
/// matters. Delayed is *inside* the window; qadā is *after* it.
final class PrayerStatusVocabularyTests: XCTestCase {

    func testDisplayNames() {
        XCTAssertEqual(PrayerStatus.onTime.displayName, "On Time")
        XCTAssertEqual(PrayerStatus.late.displayName, "Delayed")
        XCTAssertEqual(PrayerStatus.qada.displayName, "Qad\u{0101}")
        XCTAssertEqual(PrayerStatus.missed.displayName, "Missed")
    }

    /// The word "Late" must not survive anywhere in the user-facing
    /// vocabulary as a status NAME — it is the name that was wrong.
    func testLateIsNoLongerAStatusName() {
        for status in PrayerStatus.allCases {
            XCTAssertNotEqual(status.displayName, "Late")
            XCTAssertNotEqual(status.inscription, "LATE")
            XCTAssertNotEqual(status.spokenLabel, "late")
        }
    }

    func testInscriptionsAreTheUppercasedNames() {
        for status in PrayerStatus.allCases {
            XCTAssertEqual(status.inscription, status.displayName.uppercased())
        }
    }

    /// Delayed happens INSIDE the window; qadā happens AFTER it. This
    /// is the whole repair.
    func testDelayedIsInsideTheWindowAndQadaIsAfterIt() {
        XCTAssertEqual(PrayerStatus.late.caption, "PRAYED LATE IN ITS WINDOW")
        XCTAssertEqual(PrayerStatus.qada.caption, "PRAYED AFTER ITS WINDOW")
        XCTAssertEqual(PrayerStatus.onTime.caption, "PRAYED IN ITS WINDOW")
        XCTAssertEqual(PrayerStatus.missed.caption, "ITS WINDOW PASSED UNPRAYED")
    }

    /// The original defect was two statuses wearing captions that
    /// described the same fact. No two may ever match again.
    func testEveryCaptionIsDistinct() {
        let captions = PrayerStatus.allCases.map(\.caption)
        XCTAssertEqual(Set(captions).count, captions.count, "two statuses share a caption")
    }

    /// On Time and Delayed differ by exactly one word, because they
    /// differ by exactly one fact.
    func testOnTimeAndDelayedDifferByOneWord() {
        let onTime = PrayerStatus.onTime.caption.split(separator: " ")
        let delayed = PrayerStatus.late.caption.split(separator: " ")
        XCTAssertEqual(delayed.count, onTime.count + 1)
        XCTAssertEqual(delayed.filter { $0 != "LATE" }, onTime)
    }

    func testSpokenLabels() {
        XCTAssertEqual(PrayerStatus.onTime.spokenLabel, "on time")
        XCTAssertEqual(PrayerStatus.late.spokenLabel, "delayed")
        XCTAssertEqual(PrayerStatus.qada.spokenLabel, "qad\u{0101}")
        XCTAssertEqual(PrayerStatus.missed.spokenLabel, "missed")
    }

    /// The stored raw values are untouched by the rename — every
    /// existing row, CloudKit record, and widget snapshot payload still
    /// reads back.
    func testRawValuesAreUnchangedByTheRename() {
        XCTAssertEqual(PrayerStatus.onTime.rawValue, "onTime")
        XCTAssertEqual(PrayerStatus.late.rawValue, "late")
        XCTAssertEqual(PrayerStatus.qada.rawValue, "qada")
        XCTAssertEqual(PrayerStatus.missed.rawValue, "missed")
    }
}
