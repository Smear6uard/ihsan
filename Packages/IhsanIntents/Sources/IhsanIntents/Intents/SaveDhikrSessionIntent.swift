import AppIntents
import Foundation
import IhsanCore
import OSLog
import SwiftData

/// Stores one tasbīḥ sitting as a quiet fact — date, count, phrase.
/// Every surface that ends a session writes through here, so the
/// record's shape can never drift. Not discoverable: sessions are
/// recorded by the instrument, not dictated.
public struct SaveDhikrSessionIntent: AppIntent {
    public static let title: LocalizedStringResource = "Save Tasbīḥ Session"
    public static let description = IntentDescription(
        "Record a completed tasbīḥ count."
    )
    public static let openAppWhenRun: Bool = false
    public static let isDiscoverable: Bool = false

    @Parameter(title: "Count")
    public var count: Int

    /// `DhikrPhrase.rawValue`.
    @Parameter(title: "Phrase")
    public var phraseKey: String

    @Parameter(title: "Custom phrase")
    public var customPhrase: String?

    /// The civil day the session belongs to. Defaults to today.
    @Parameter(title: "Day")
    public var sessionDate: Date?

    private static let logger = Logger(
        subsystem: "com.sameerstudios.ihsan.intents",
        category: "SaveDhikrSessionIntent"
    )

    public init() {}

    public init(
        count: Int,
        phrase: DhikrPhrase,
        customPhrase: String? = nil,
        sessionDate: Date? = nil
    ) {
        self.count = count
        self.phraseKey = phrase.rawValue
        self.customPhrase = customPhrase
        self.sessionDate = sessionDate
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        Self.logger.info("Invoked SaveDhikrSessionIntent")

        guard count > 0 else {
            return .result(dialog: IntentDialog("Nothing to record."))
        }
        let phrase = DhikrPhrase(rawValue: phraseKey) ?? .subhanallah

        let container = try await ModelContainerAccess.shared.container()
        let context = ModelContext(container)
        let clock = NowProvider.active

        let session = DhikrSession(
            sessionDate: sessionDate ?? PrayerCycleClock.sharedCycleDate(at: clock.now()),
            count: count,
            phrase: phrase,
            customPhrase: phrase == .custom ? customPhrase : nil,
            startedAt: clock.now(),
            sourceSurface: .app
        )
        context.insert(session)
        try context.save()

        return .result(dialog: IntentDialog("Tasbīḥ recorded."))
    }
}
