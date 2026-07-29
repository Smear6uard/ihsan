import AppIntents
import IhsanCore
import OSLog
import SwiftData

/// Logs one made-up prayer through the same `QadaLedgerWriter` funnel as
/// the in-app Repair surface, so the append-only log stays the single
/// source of truth for every surface. With no category given, the user's
/// most active category is used.
public struct LogMakeupPrayerIntent: AppIntent {
    public static let title: LocalizedStringResource = "Log Makeup Prayer"
    public static let description = IntentDescription(
        "Log one made-up prayer, at your pace."
    )
    public static let openAppWhenRun: Bool = false
    public static let isDiscoverable: Bool = true

    @Parameter(
        title: "Prayer",
        description: "Which makeup count to add to. Leave empty for your most active one.",
        requestValueDialog: "Which prayer did you make up?"
    )
    public var category: QadaCategoryEntity?

    private static let logger = Logger(
        subsystem: "com.sameerstudios.ihsan.intents",
        category: "LogMakeupPrayerIntent"
    )

    public init() {}

    public init(category: QadaCategory?) {
        self.category = category.map(QadaCategoryEntity.init(category:))
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        Self.logger.info("Invoked LogMakeupPrayerIntent")

        let container = try await ModelContainerAccess.shared.container()
        let context = ModelContext(container)
        let settings = try UserSettings.fetchOrCreate(in: context)

        guard settings.qadaTrackingEnabled else {
            return .result(dialog: IntentDialog("Makeup prayers aren't set up yet. You can begin from Settings in Ihsan."))
        }

        let writer = QadaLedgerWriter()
        let resolved = try category?.category ?? writer.mostActiveCategory(in: context)
        guard let resolved else {
            return .result(dialog: IntentDialog("There's nothing to make up right now."))
        }

        try writer.recordMadeUp(
            category: resolved,
            count: 1,
            sourceSurface: .shortcuts,
            in: context
        )

        return .result(dialog: IntentDialog("\(resolved.displayNameEnglish) made up."))
    }
}
