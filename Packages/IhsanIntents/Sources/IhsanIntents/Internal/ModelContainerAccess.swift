import IhsanCore
import SwiftData

/// Thin facade over the process-wide `IhsanSharedModelContainer`.
///
/// The intent funnel must write into the same container the app UI
/// reads — the app registers its container at launch, and extension
/// processes fall back to a lazily created instance of their own.
internal actor ModelContainerAccess {
    static let shared = ModelContainerAccess()

    private init() {}

    func container() throws -> ModelContainer {
        try IhsanSharedModelContainer.shared.container()
    }

    func setContainer(_ container: ModelContainer) {
        IhsanSharedModelContainer.shared.register(container)
    }

    func reset() {
        IhsanSharedModelContainer.shared.reset()
    }
}
