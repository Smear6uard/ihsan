import SwiftUI
import SwiftData
import IhsanCore
import IhsanIntents
import IhsanLocation
import IhsanNotifications

@main
struct IhsanApp: App {
    let modelContainer: ModelContainer

    /// Resolved once at launch; `.system` unless a debug run passed
    /// `-IhsanNowOverride <ISO8601>`.
    private let nowProvider = NowProvider.fromLaunchArguments()

    init() {
        // Try the shared App-Group store first; fall back to in-memory
        // when the app group entitlement isn't yet wired (e.g. early development).
        // CloudKit mirroring follows the account gate's cached answer, so a
        // device with no iCloud account runs local-only instead of spinning.
        do {
            modelContainer = try IhsanModelContainerFactory.makeContainer(
                cloudSync: CloudAccountGate.shouldEnableCloudSync()
            )
        } catch {
            print("Falling back to in-memory ModelContainer: \(error)")
            do {
                modelContainer = try IhsanModelContainerFactory.makeContainer(inMemory: true)
            } catch {
                fatalError("Failed to create in-memory ModelContainer: \(error)")
            }
        }

        #if canImport(ActivityKit) && os(iOS)
        Task {
            await NotificationScheduler.shared.setPrayerActivityScheduler(PrayerActivityScheduler.shared)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootGate()
                .environment(\.nowProvider, nowProvider)
                .preferredColorScheme(.dark)
                .task {
                    // Pre-warm the location coordinator so authorization and
                    // significant-change monitoring are ready by the time Today appears.
                    _ = CoreLocationCoordinator.shared
                    // One account-status query per launch; afterwards only
                    // CKAccountChanged re-checks. No retry loops.
                    await CloudAccountGate.refreshAccountStatus()
                    await CloudAccountGate.observeAccountChanges()
                }
        }
        .modelContainer(modelContainer)
    }
}

/// Decides which top-level scene to present based on whether the user
/// has completed the first-launch flow. The OnboardingFlow is shown
/// as a full-screen cover over the RootTabView so:
///   - the gate flips automatically when SwiftData publishes the
///     `hasCompletedOnboarding = true` write at the end of step 5,
///   - the user cannot dismiss the cover by gesture (onboarding is
///     non-skippable as a whole; only individual permission rationale
///     screens within it are skippable),
///   - cold-launching mid-flow lands on the welcome step every time
///     because the OnboardingFlow owns its own view model.
private struct RootGate: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allSettings: [UserSettings]
    @Query(sort: \PrayerLog.loggedAt) private var prayerLogs: [PrayerLog]

    /// True until SwiftData publishes the singleton settings row. Used
    /// to suppress a one-frame flash of onboarding on cold launches
    /// where the existing user already finished setup.
    @State private var didResolveInitialSettings = false
    @State private var observedLiveActivityLogIDs: Set<UUID> = []

    var body: some View {
        ZStack {
            RootTabView()
                .opacity(didResolveInitialSettings ? 1 : 0)
        }
        .fullScreenCover(isPresented: shouldPresentOnboarding) {
            OnboardingFlow()
                .interactiveDismissDisabled(true)
        }
        .task {
            ensureSingletonExists()
            applyDebugLaunchArguments()
            sweepOrphanReflectionAudio()
            didResolveInitialSettings = true
        }
        #if canImport(ActivityKit) && os(iOS)
        .task(id: liveActivityLogSignature) {
            await endLiveActivitiesForNewLogs()
        }
        #endif
    }

    /// Driven by the persisted flag. Setter is a no-op because the
    /// flag flips only via OnboardingViewModel.commit(...). Without
    /// the no-op the system would try to dismiss the cover when the
    /// user swipes down, which we don't want for a non-skippable
    /// flow.
    private var shouldPresentOnboarding: Binding<Bool> {
        Binding(
            get: { didResolveInitialSettings && !hasCompletedOnboarding },
            set: { _ in }
        )
    }

    private var hasCompletedOnboarding: Bool {
        allSettings.first?.hasCompletedOnboarding ?? false
    }

    private var liveActivityLogSignature: String {
        prayerLogs
            .map { "\($0.id.uuidString):\($0.modifiedAt.timeIntervalSince1970)" }
            .joined(separator: "|")
    }

    /// SwiftData lazily creates the UserSettings singleton when first
    /// fetched. We force that read on launch so the `@Query` above
    /// resolves before we make a gate decision; otherwise the empty
    /// array on first frame would briefly look like "onboarding not
    /// completed" for an existing user who has it completed.
    private func ensureSingletonExists() {
        do {
            _ = try UserSettings.fetchOrCreate(in: modelContext)
            try modelContext.save()
        } catch {
            // If we can't resolve the singleton, the gate falls open
            // to onboarding, which is the safer default — better to
            // re-show setup once than to hide it from a brand new
            // install.
        }
    }

    /// Debug-only verification hooks, driven by launch arguments so a
    /// screenshot run can reach the Today screen without walking
    /// onboarding, and can show the logged card state:
    ///
    /// - `-IhsanDebugCompletedOnboarding` marks onboarding complete.
    /// - `-IhsanDebugLogPrayer dhuhr:onTime` logs one prayer through
    ///   the standard intent funnel (dedup and idempotency hold).
    ///
    /// Release builds compile this to a no-op.
    private func applyDebugLaunchArguments() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-IhsanDebugCompletedOnboarding") {
            if let settings = try? UserSettings.fetchOrCreate(in: modelContext),
               !settings.hasCompletedOnboarding {
                settings.hasCompletedOnboarding = true
                try? modelContext.save()
            }
        }
        if let flagIndex = arguments.firstIndex(of: "-IhsanDebugLogPrayer"),
           arguments.indices.contains(flagIndex + 1) {
            let parts = arguments[flagIndex + 1].split(separator: ":")
            if parts.count == 2,
               let prayer = Prayer(rawValue: String(parts[0])),
               let status = PrayerStatus(rawValue: String(parts[1])) {
                Task {
                    _ = try? await LogPrayerWithStatusIntent(
                        prayer: prayer, status: status
                    ).perform()
                }
            }
        }
        #endif
    }

    /// Force-quit during a recording leaves an .m4a in the App Group
    /// container with no Reflection pointing to it. Sweep those at
    /// launch — best-effort, age-guarded so we never touch a file
    /// from an in-flight recording.
    private func sweepOrphanReflectionAudio() {
        let descriptor = FetchDescriptor<Reflection>()
        let known: Set<UUID>
        if let reflections = try? modelContext.fetch(descriptor) {
            known = Set(reflections.compactMap(\.voiceMemoID))
        } else {
            // Couldn't query — be safe and leave files alone rather
            // than risk deleting a record's audio because of a
            // transient fetch error.
            return
        }
        ReflectionAudioPaths.cleanupOrphans(knownMemoIDs: known)
    }

    #if canImport(ActivityKit) && os(iOS)
    private func endLiveActivitiesForNewLogs() async {
        for log in prayerLogs where !observedLiveActivityLogIDs.contains(log.id) {
            observedLiveActivityLogIDs.insert(log.id)
            guard let prayer = log.prayer else {
                continue
            }
            await PrayerActivityScheduler.shared.endActivity(
                for: prayer,
                on: log.prayerDate,
                reason: .logged
            )
        }
    }
    #endif
}
