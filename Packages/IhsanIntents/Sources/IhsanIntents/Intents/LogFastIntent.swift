import AppIntents
import Foundation
import IhsanCore
import OSLog
import SwiftData

/// Records (or, on a repeated tap, removes) the day's fast through the
/// same funnel every surface uses. Deliberately not discoverable and
/// absent from App Shortcuts: fasting is offered quietly in the app,
/// never pushed.
public struct LogFastIntent: AppIntent {
    public static let title: LocalizedStringResource = "Log Fast"
    public static let description = IntentDescription(
        "Record a fast for the day."
    )
    public static let openAppWhenRun: Bool = false
    public static let isDiscoverable: Bool = false

    /// `FastKind.rawValue`, e.g. `"ramadan"`, `"whiteDay"`.
    @Parameter(title: "Kind")
    public var kindKey: String

    /// `FastState.rawValue`: `"intended"` or `"kept"`.
    @Parameter(title: "State")
    public var stateKey: String

    /// The civil day of the fast. Defaults to today.
    @Parameter(title: "Day")
    public var fastDate: Date?

    private static let logger = Logger(
        subsystem: "com.sameerstudios.ihsan.intents",
        category: "LogFastIntent"
    )

    public init() {}

    public init(kind: FastKind, state: FastState, fastDate: Date? = nil) {
        self.kindKey = kind.rawValue
        self.stateKey = state.rawValue
        self.fastDate = fastDate
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        Self.logger.info("Invoked LogFastIntent")

        guard let kind = FastKind(rawValue: kindKey) else {
            throw IntentError.invalidFastKind(kindKey)
        }
        guard let state = FastState(rawValue: stateKey) else {
            throw IntentError.invalidFastKind(stateKey)
        }

        let container = try await ModelContainerAccess.shared.container()
        let context = ModelContext(container)

        let log = try FastLogService().recordFast(
            kind: kind,
            state: state,
            fastDate: fastDate ?? Calendar.current.startOfDay(for: NowProvider.active.now()),
            sourceSurface: .app,
            in: context
        )

        WidgetSnapshotMirror.reflectFastLogs(in: context)

        let dialog: String
        if let log {
            dialog = log.state == .intended
                ? "Fasting intention recorded."
                : "Fast recorded."
        } else {
            dialog = "Fast removed."
        }
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}
