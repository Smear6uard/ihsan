import IhsanCore
@testable import IhsanIntents
import SwiftData
import XCTest

/// The wider-worship funnels: fasting records toggle idempotently
/// with no negative transition anywhere, and tasbīḥ sessions land as
/// quiet facts.
final class DhikrAndFastIntentTests: XCTestCase {
    private let fixedDay = Date(timeIntervalSinceReferenceDate: 700_000_000)

    // MARK: - Fasting

    @MainActor
    func testRecordsAndTogglesTheDaysFast() async throws {
        let context = try await makeContext()

        _ = try await LogFastIntent(kind: .whiteDay, state: .intended, fastDate: fixedDay).perform()
        var fasts = try context.fetch(FetchDescriptor<FastLog>())
        XCTAssertEqual(fasts.count, 1)
        XCTAssertEqual(fasts.first?.state, .intended)

        // The intention fulfilled: the row upgrades in place.
        _ = try await LogFastIntent(kind: .whiteDay, state: .kept, fastDate: fixedDay).perform()
        fasts = try context.fetch(FetchDescriptor<FastLog>())
        XCTAssertEqual(fasts.count, 1)
        XCTAssertEqual(fasts.first?.state, .kept)

        // A kept fast never downgrades back to an intention.
        _ = try await LogFastIntent(kind: .whiteDay, state: .intended, fastDate: fixedDay).perform()
        fasts = try context.fetch(FetchDescriptor<FastLog>())
        XCTAssertEqual(fasts.first?.state, .kept)

        // Same state again: the tap removes (undo).
        _ = try await LogFastIntent(kind: .whiteDay, state: .kept, fastDate: fixedDay).perform()
        XCTAssertTrue(try context.fetch(FetchDescriptor<FastLog>()).isEmpty)
    }

    @MainActor
    func testOneRowPerDayAcrossKinds() async throws {
        let context = try await makeContext()
        _ = try await LogFastIntent(kind: .monThu, state: .kept, fastDate: fixedDay).perform()
        _ = try await LogFastIntent(
            kind: .qada, state: .kept,
            fastDate: fixedDay.addingTimeInterval(86_400)
        ).perform()
        let fasts = try context.fetch(FetchDescriptor<FastLog>())
        XCTAssertEqual(fasts.count, 2)
        XCTAssertEqual(Set(fasts.map(\.dedupKey)).count, 2)
    }

    // MARK: - Dhikr

    @MainActor
    func testSavesASessionAsAQuietFact() async throws {
        let context = try await makeContext()

        _ = try await SaveDhikrSessionIntent(
            count: 66, phrase: .alhamdulillah, sessionDate: fixedDay
        ).perform()

        let sessions = try context.fetch(FetchDescriptor<DhikrSession>())
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.count, 66)
        XCTAssertEqual(sessions.first?.phrase, .alhamdulillah)
        XCTAssertNil(sessions.first?.customPhrase)
    }

    @MainActor
    func testZeroCountSessionsAreNotRecorded() async throws {
        let context = try await makeContext()
        _ = try await SaveDhikrSessionIntent(
            count: 0, phrase: .subhanallah, sessionDate: fixedDay
        ).perform()
        XCTAssertTrue(try context.fetch(FetchDescriptor<DhikrSession>()).isEmpty)
    }

    @MainActor
    func testCustomPhraseTravelsOnlyWithTheCustomKind() async throws {
        let context = try await makeContext()
        _ = try await SaveDhikrSessionIntent(
            count: 33, phrase: .custom, customPhrase: "Ḥasbunallāh", sessionDate: fixedDay
        ).perform()
        let session = try XCTUnwrap(try context.fetch(FetchDescriptor<DhikrSession>()).first)
        XCTAssertEqual(session.phrase, .custom)
        XCTAssertEqual(session.customPhrase, "Ḥasbunallāh")
        XCTAssertEqual(session.displayLabel, "Ḥasbunallāh")
    }
}
