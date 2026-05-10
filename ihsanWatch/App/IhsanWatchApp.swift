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
