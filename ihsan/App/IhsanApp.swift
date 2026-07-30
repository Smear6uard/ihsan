import SwiftUI
import SwiftData
import IhsanCore
import IhsanIntents
import IhsanLocation
import IhsanNotifications

@main
struct IhsanApp: App {
    let modelContainer: ModelContainer

    /// The process's one clock — `.system` unless a debug run passed
    /// `-IhsanNowOverride <ISO8601>`. The same instance the intent
    /// layer stamps `loggedAt` from, so the environment clock and the
    /// commit clock can never disagree.
    private let nowProvider = NowProvider.active

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
        // Register the app's container as the process's one shared
        // instance BEFORE any intent or scheduler can run. Without
        // this, the intent funnel lazily creates a second
        // CloudKit-mirrored container over the same store — CloudKit
        // setup fails (CoreData 134422) and commits from the log
        // sheet never reach the container the UI's @Querys observe.
        IhsanSharedModelContainer.shared.register(modelContainer)

        // Before any notification can be delivered, so a cold launch
        // from a tapped banner behaves exactly like a warm one.
        Task { @MainActor in
            PrayerNotificationResponder.shared.install()
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
        // One Hijri mapping everywhere: the user's moonsighting
        // adjustment is published for every formatter the moment
        // settings resolve, and re-published when the row changes.
        .onChange(of: allSettings.first?.hijriCalendarOffsetDays, initial: true) { _, offset in
            HijriDisplay.publish(offsetDays: offset ?? 0)
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
    /// - `-IhsanDebugResetStore` empties the prayer/nafl/pause tables
    ///   so UI tests start hermetic regardless of prior runs.
    ///
    /// Release builds compile this to a no-op.
    private func applyDebugLaunchArguments() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-IhsanDebugResetStore") {
            try? modelContext.delete(model: PrayerLog.self)
            try? modelContext.delete(model: NaflLog.self)
            try? modelContext.delete(model: PauseInterval.self)
            try? modelContext.delete(model: Reflection.self)
            try? modelContext.delete(model: FastLog.self)
            try? modelContext.delete(model: DhikrSession.self)
            try? modelContext.delete(model: QadaEntry.self)
            try? modelContext.delete(model: QadaLedger.self)
            // Preferences leak between runs too — a custom angle set by
            // one test is still there for the next one, and a test that
            // silently inherits state is not a test. The settings row
            // goes with the records; `fetchOrCreate` rebuilds it with
            // stock defaults, and the flags below re-apply on top.
            try? modelContext.delete(model: UserSettings.self)
            try? modelContext.save()
        }
        // `-IhsanDebugSoundProbe chime,chime-dawn,takbirat,silent`
        // schedules one prayer notification per named sound a few
        // seconds out, through the same content builder the real
        // schedule uses. The timed device test watches them arrive and
        // reads the sound each one carries — the only way to prove the
        // whole path, since a bundled tone iOS rejects still delivers a
        // notification, just a silent one.
        if let flagIndex = arguments.firstIndex(of: "-IhsanDebugSoundProbe"),
           arguments.indices.contains(flagIndex + 1) {
            let names = arguments[flagIndex + 1].split(separator: ",").map(String.init)
            Task { await AdhanSoundProbe.fire(names: names) }
        }
        // `-IhsanDebugSeedReflections N` inserts N typed reflections
        // across recent days — the screenshot harness for the feed's
        // populated state.
        if let flagIndex = arguments.firstIndex(of: "-IhsanDebugSeedReflections"),
           arguments.indices.contains(flagIndex + 1),
           let count = Int(arguments[flagIndex + 1]) {
            let now = NowProvider.active.now()
            let samples = [
                "Gratitude came easier today than it has in weeks.",
                "The pause before Maghrib was the stillest moment of the day.",
                "I noticed how much lighter the evening felt after Isha.",
                "A slow morning, but Fajr held it together.",
            ]
            for index in 0..<count {
                let day = Calendar.current.date(byAdding: .day, value: -index * 2, to: now) ?? now
                modelContext.insert(Reflection(
                    kind: .daily,
                    forDate: Calendar.current.startOfDay(for: day),
                    loggedTimeZoneIdentifier: TimeZone.current.identifier,
                    promptText: "What moment today felt closest to stillness?",
                    promptCitation: "Surah Ar-Ra'd 13:28",
                    typedText: samples[index % samples.count],
                    createdAt: day,
                    modifiedAt: day
                ))
            }
            try? modelContext.save()
        }
        if arguments.contains("-IhsanDebugCompletedOnboarding") {
            if let settings = try? UserSettings.fetchOrCreate(in: modelContext),
               !settings.hasCompletedOnboarding {
                settings.hasCompletedOnboarding = true
                try? modelContext.save()
            }
        }
        // `-IhsanDebugEnableFastingRhythms` turns both voluntary
        // rhythm offers on — the screenshot harness for the offer
        // line.
        if arguments.contains("-IhsanDebugEnableFastingRhythms") {
            if let settings = try? UserSettings.fetchOrCreate(in: modelContext) {
                settings.fastingMonThuOfferEnabled = true
                settings.fastingWhiteDaysOfferEnabled = true
                try? modelContext.save()
            }
        }
        // `-IhsanDebugLogFast ramadan:kept` seeds today's fast through
        // the standard funnel; composes with -IhsanNowOverride.
        if let flagIndex = arguments.firstIndex(of: "-IhsanDebugLogFast"),
           arguments.indices.contains(flagIndex + 1) {
            let parts = arguments[flagIndex + 1].split(separator: ":")
            if parts.count == 2,
               let kind = FastKind(rawValue: String(parts[0])),
               let state = FastState(rawValue: String(parts[1])) {
                let day = Calendar.current.startOfDay(for: NowProvider.active.now())
                Task {
                    _ = try? await LogFastIntent(kind: kind, state: state, fastDate: day).perform()
                }
            }
        }
        // `-IhsanDebugSeedFastingLedger N` opens the fasting thread
        // with a manual count, as the estimator sheet would.
        if let flagIndex = arguments.firstIndex(of: "-IhsanDebugSeedFastingLedger"),
           arguments.indices.contains(flagIndex + 1),
           let count = Int(arguments[flagIndex + 1]), count > 0 {
            if let settings = try? UserSettings.fetchOrCreate(in: modelContext) {
                settings.qadaTrackingEnabled = true
                settings.qadaSetupCompletedAt = NowProvider.active.now()
            }
            try? QadaLedgerWriter().recordEstimate(
                [.fasting: count, .isha: 24],
                sourceSurface: .app,
                in: modelContext
            )
            try? modelContext.save()
        }
        // `-IhsanDebugLogPrayer dhuhr:late` seeds today; an optional
        // third component is a day offset — `dhuhr:late:-1` seeds
        // yesterday (relative to the NowProvider clock, so it
        // composes with -IhsanNowOverride). Multiple specs join with
        // ";" so a screenshot run can stage a whole month:
        // `fajr:onTime:0;dhuhr:qada:-1;asr:missed:-2`.
        if let flagIndex = arguments.firstIndex(of: "-IhsanDebugLogPrayer"),
           arguments.indices.contains(flagIndex + 1) {
            let specs = arguments[flagIndex + 1].split(separator: ";")
            Task {
                for spec in specs {
                    let parts = spec.split(separator: ":")
                    guard parts.count >= 2,
                          let prayer = Prayer(rawValue: String(parts[0])),
                          let status = PrayerStatus(rawValue: String(parts[1]))
                    else { continue }
                    let dayOffset = parts.count >= 3 ? Int(parts[2]) ?? 0 : 0
                    let date: Date? = dayOffset == 0 ? nil : Calendar.current.date(
                        byAdding: .day, value: dayOffset, to: NowProvider.active.now()
                    )
                    _ = try? await LogPrayerWithStatusIntent(
                        prayer: prayer, status: status, date: date
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
