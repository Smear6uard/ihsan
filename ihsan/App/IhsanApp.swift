import SwiftUI
import SwiftData
import IhsanCore
import IhsanIntents
import IhsanLocation

@main
struct IhsanApp: App {
    let modelContainer: ModelContainer

    init() {
        // Try the shared App-Group + CloudKit store first; fall back to in-memory
        // when the app group entitlement isn't yet wired (e.g. early development).
        do {
            modelContainer = try IhsanModelContainerFactory.makeContainer()
        } catch {
            print("Falling back to in-memory ModelContainer: \(error)")
            do {
                modelContainer = try IhsanModelContainerFactory.makeContainer(inMemory: true)
            } catch {
                fatalError("Failed to create in-memory ModelContainer: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .preferredColorScheme(.dark)
                .task {
                    // Pre-warm the location coordinator so authorization and
                    // significant-change monitoring are ready by the time Today appears.
                    _ = CoreLocationCoordinator.shared
                }
        }
        .modelContainer(modelContainer)
    }
}
