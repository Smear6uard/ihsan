import AppIntents
import Foundation
import IhsanCore
import OSLog
import SwiftData

/// Stores one sitting with a remembrance set as a quiet fact — the day,
/// which set, how many items were counted through.
///
/// The single funnel, like every other recording path in the app: one
/// place writes an `AdhkarSession`, so the record's shape cannot drift
/// as surfaces are added. Not discoverable — sessions are recorded by
/// sitting with the set, not dictated to Siri.
public struct SaveAdhkarSessionIntent: AppIntent {
    public static let title: LocalizedStringResource = "Save Adhkār Session"
    public static let description = IntentDescription(
        "Record a sitting with a remembrance set."
    )
    public static let openAppWhenRun: Bool = false
    public static let isDiscoverable: Bool = false

    /// `AdhkarCategory.rawValue`.
    @Parameter(title: "Set")
    public var categoryKey: String

    @Parameter(title: "Items counted")
    public var completedItemCount: Int

    /// The civil day the sitting belongs to. Defaults to today.
    @Parameter(title: "Day")
    public var sessionDate: Date?

    private static let logger = Logger(
        subsystem: "com.sameerstudios.ihsan.intents",
        category: "SaveAdhkarSessionIntent"
    )

    public init() {}

    public init(
        category: AdhkarCategory,
        completedItemCount: Int,
        sessionDate: Date? = nil
    ) {
        self.categoryKey = category.rawValue
        self.completedItemCount = completedItemCount
        self.sessionDate = sessionDate
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        Self.logger.info("Invoked SaveAdhkarSessionIntent")

        guard completedItemCount > 0 else {
            return .result(dialog: IntentDialog("Nothing to record."))
        }
        guard let category = AdhkarCategory(rawValue: categoryKey) else {
            return .result(dialog: IntentDialog("Nothing to record."))
        }

        let container = try await ModelContainerAccess.shared.container()
        let context = ModelContext(container)
        let clock = NowProvider.active

        context.insert(AdhkarSession(
            sessionDate: sessionDate ?? Calendar.current.startOfDay(for: clock.now()),
            category: category,
            completedItemCount: completedItemCount,
            startedAt: clock.now(),
            sourceSurface: .app
        ))
        try context.save()

        return .result(dialog: IntentDialog("Recorded."))
    }
}
