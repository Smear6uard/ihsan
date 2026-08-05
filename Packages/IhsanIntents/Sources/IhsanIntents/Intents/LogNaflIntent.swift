import AppIntents
import Foundation
import IhsanCore
import OSLog
import SwiftData

/// Records (or, on a second tap, removes) one voluntary act for a day,
/// through the same funnel every surface uses. Deliberately not
/// discoverable and absent from App Shortcuts: the sunnah layer is opt-in,
/// and nothing outside it may hint that it exists.
public struct LogNaflIntent: AppIntent {
    public static let title: LocalizedStringResource = "Log Voluntary Prayer"
    public static let description = IntentDescription(
        "Record a voluntary prayer for the day."
    )
    public static let openAppWhenRun: Bool = false
    public static let isDiscoverable: Bool = false

    /// `NaflKind.storageKey`, e.g. `"rawatibBefore.fajr"`, `"duha"`.
    @Parameter(title: "Kind")
    public var kindKey: String

    /// The prayer cycle this act belongs to. Defaults to the cycle in
    /// progress, which is what makes qiyam and witr file under the
    /// night they were offered in rather than under the morning the
    /// clock had reached.
    @Parameter(title: "Day")
    public var naflDate: Date?

    @Parameter(title: "Rak'ah count")
    public var rakahCount: Int?

    private static let logger = Logger(
        subsystem: "com.sameerstudios.ihsan.intents",
        category: "LogNaflIntent"
    )

    public init() {}

    public init(kind: NaflKind, naflDate: Date? = nil, rakahCount: Int? = nil) {
        self.kindKey = kind.storageKey
        self.naflDate = naflDate
        self.rakahCount = rakahCount
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        Self.logger.info("Invoked LogNaflIntent")

        guard let kind = NaflKind(storageKey: kindKey) else {
            throw IntentError.invalidNaflKind(kindKey)
        }

        let container = try await ModelContainerAccess.shared.container()
        let context = ModelContext(container)
        let settings = try UserSettings.fetchOrCreate(in: context)

        guard settings.sunnahLayerEnabled else {
            return .result(dialog: IntentDialog("Voluntary prayer isn't turned on in Ihsan."))
        }

        let log = try NaflLogService().toggleNafl(
            kind: kind,
            naflDate: naflDate ?? PrayerCycleClock.sharedCycleDate(at: .now),
            rakahCount: rakahCount,
            sourceSurface: .app,
            in: context
        )

        let dialog = log == nil
            ? "\(kind.displayNameEnglish) removed."
            : "\(kind.displayNameEnglish) recorded."
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}
