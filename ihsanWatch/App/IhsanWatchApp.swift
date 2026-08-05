import SwiftUI
import SwiftData
import IhsanCore
import IhsanLocation

/// Standalone watchOS 26 app entry. Mirrors the iOS app's container
/// bring-up exactly: same app group, same CloudKit container, so any
/// log written on the phone arrives via CloudKit and any log written
/// here propagates back. No companion-RPC, no WatchConnectivity.
@main
struct IhsanWatchApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try IhsanModelContainerFactory.makeContainer()
        } catch {
            print("Falling back to in-memory ModelContainer on watch: \(error)")
            do {
                modelContainer = try IhsanModelContainerFactory.makeContainer(inMemory: true)
            } catch {
                fatalError("Failed to create in-memory ModelContainer on watch: \(error)")
            }
        }
        // Register with the process-wide holder exactly as the iOS
        // app does, so a Siri/complication intent on the watch shares
        // this container instead of lazily creating a second one over
        // the same store.
        IhsanSharedModelContainer.shared.register(modelContainer)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .task {
                    _ = CoreLocationCoordinator.shared
                }
        }
        .modelContainer(modelContainer)
    }
}
