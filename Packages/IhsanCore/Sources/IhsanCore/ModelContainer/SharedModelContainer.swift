import Foundation
import SwiftData
import Synchronization

/// The process's one `ModelContainer`.
///
/// A SwiftData store with CloudKit mirroring tolerates exactly one
/// mirroring container per process — a second one fails CloudKit
/// setup with "another instance of this persistent store is actively
/// syncing" (CoreData 134422) and, worse, writes through it are
/// invisible to the UI's `@Query`s until a remote-change notification
/// happens to arrive. Every in-process consumer (the app UI, the
/// intent funnel, the notification scheduler) must therefore share
/// one container.
///
/// The app registers its container synchronously at launch, before
/// any intent or scheduler can run. Extension processes (widgets,
/// Siri) never register; their first `container()` call lazily
/// creates and caches that process's own instance — the correct
/// behavior for a separate process.
public final class IhsanSharedModelContainer: Sendable {
    public static let shared = IhsanSharedModelContainer()

    private let state = Mutex<ModelContainer?>(nil)

    private init() {}

    /// Registers the process's container. Synchronous so the app can
    /// call it from `App.init`, closing the gap in which an intent
    /// could otherwise race ahead and create a second instance.
    public func register(_ container: ModelContainer) {
        state.withLock { $0 = container }
    }

    /// The registered container, or — in processes that never
    /// register (extensions) — a lazily created shared-store
    /// container, cached for the life of the process.
    public func container() throws -> ModelContainer {
        try state.withLock { current in
            if let current { return current }
            let created = try IhsanModelContainerFactory.makeContainer(inMemory: false)
            current = created
            return created
        }
    }

    /// Test hook: drops the cached container so each test can
    /// register its own in-memory store.
    public func reset() {
        state.withLock { $0 = nil }
    }
}
