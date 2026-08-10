import SwiftUI
import SwiftData
import IhsanCore
import IhsanDesignSystem
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

        // Register while the process is launching; BGTaskScheduler
        // rejects late registration. The task keeps the rolling
        // fourteen-day prayer schedule fresh after this launch.
        _ = BackgroundRefreshTask.register()

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

/// Decides which top-level scene to present based on whether the person
/// has completed the first launch.
///
/// The two are exclusive, not stacked. Onboarding used to be a cover
/// over a live `RootTabView`, which meant Today was running underneath
/// it — and Today asks for location the moment it appears. The system
/// permission dialog therefore arrived on its own at launch, in front
/// of the screen that exists to ask for location in place. A first
/// screen whose question has already been asked by something else is
/// not asking anything.
///
/// The gate still flips by itself when SwiftData publishes
/// `hasCompletedOnboarding = true`, and cold-launching mid-flow still
/// starts over, because the flow owns its own view model.
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
            if !didResolveInitialSettings {
                // Neither, yet. Building RootTabView here — even at
                // zero opacity — starts Today, and Today asks for
                // location the moment it appears; the system dialog
                // then arrives before the screen that exists to ask.
                Color.clear.ihsanManuscriptPage().ignoresSafeArea()
            } else if hasCompletedOnboarding {
                RootTabView()
            } else {
                OnboardingFlow()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: hasCompletedOnboarding)
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
        .task(id: hasCompletedOnboarding) {
            guard hasCompletedOnboarding else { return }
            // Covers first completion and ordinary cold launches. It
            // is safe when permission or location is unavailable and
            // ensures onboarding's notification choice has an actual
            // pending schedule immediately, not at the next BG refresh.
            try? await NotificationScheduler.shared.rebuildSchedule()
        }
        #if DEBUG && canImport(ActivityKit) && os(iOS)
        .task {
            await PrayerActivityDebugLauncher.launchIfRequested()
        }
        #endif
        #if canImport(ActivityKit) && os(iOS)
        .task(id: liveActivityLogSignature) {
            await endLiveActivitiesForNewLogs()
        }
        #endif
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
    /// - `-IhsanDebugSeedVoluntary 30` fills the last 30 cycles with
    ///   voluntary prayers and tasbīḥ sittings.
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

            // Presentation state lives in UserDefaults, not the store,
            // and leaks between runs just as readily: a line dismissed
            // by one test is still dismissed for the next.
            for key in [
                "IhsanSignificantDayDismissedDay",
                "IhsanYesterdayOfferDismissedDay",
                "IhsanSunnahCardDismissed",
                "IhsanAdhkarDismissedDay",
                "IhsanWeatherDuaDismissedEpisodes",
                "IhsanLivingSkyEnabled"
            ] {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        // `-IhsanDebugPauseSince N` opens an excused pause N days ago
        // and leaves it running — the state every "must stay silent"
        // suppression test needs.
        if let flagIndex = arguments.firstIndex(of: "-IhsanDebugPauseSince"),
           arguments.indices.contains(flagIndex + 1),
           let days = Int(arguments[flagIndex + 1]) {
            let start = Calendar.current.date(
                byAdding: .day, value: -days, to: NowProvider.active.now()
            ) ?? NowProvider.active.now()
            modelContext.insert(PauseInterval(
                startDate: start,
                loggedTimeZoneIdentifier: TimeZone.current.identifier
            ))
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
        // `-IhsanDebugLivingSky` switches the living sky on — the
        // per-condition gate review and screenshot harness, composed
        // with `-IhsanDebugSkyConditions <kind>` to stand under each
        // treatment.
        if arguments.contains("-IhsanDebugLivingSky") {
            UserDefaults.standard.set(true, forKey: "IhsanLivingSkyEnabled")
        }
        // `-IhsanDebugEnableAdhkar` turns the remembrance layer and all
        // four sets on — including sleep, which remains opt-in in the
        // normal defaults — for the offer-card and reading-surface
        // screenshot harnesses.
        if arguments.contains("-IhsanDebugEnableAdhkar") {
            if let settings = try? UserSettings.fetchOrCreate(in: modelContext) {
                settings.adhkarLayerEnabled = true
                settings.adhkarMorningEnabled = true
                settings.adhkarEveningEnabled = true
                settings.adhkarPostPrayerEnabled = true
                settings.adhkarSleepEnabled = true
                try? modelContext.save()
            }
        }
        // `-IhsanDebugSeedVoluntary N` turns the sunnah layer on and
        // fills the last N cycles with a plausible mixture of
        // voluntary prayers and tasbīḥ sittings — the harness for
        // Path's presence rows and its day detail. Deterministic, so
        // two runs produce the same picture.
        if let flagIndex = arguments.firstIndex(of: "-IhsanDebugSeedVoluntary"),
           arguments.indices.contains(flagIndex + 1),
           let span = Int(arguments[flagIndex + 1]) {
            if let settings = try? UserSettings.fetchOrCreate(in: modelContext) {
                settings.sunnahLayerEnabled = true
                settings.sunnahRawatibEnabled = true
                settings.sunnahDuhaEnabled = true
                settings.sunnahNightEnabled = true
            }
            let today = PrayerCycleClock.sharedCycleDate(at: NowProvider.active.now())
            let kinds: [[NaflKind]] = [
                [.rawatibBefore(.fajr), .duha],
                [],
                [.witr],
                [.rawatibBefore(.fajr), .rawatibAfter(.dhuhr), .qiyam, .witr],
                [.duha],
                [],
                [.rawatibAfter(.maghrib)]
            ]
            let phrases: [(DhikrPhrase, Int)] = [
                (.subhanallah, 33), (.alhamdulillah, 33), (.astaghfirullah, 100)
            ]
            for index in 0..<max(0, span) {
                guard let day = Calendar.current.date(
                    byAdding: .day, value: -index, to: today
                ) else { continue }
                for kind in kinds[index % kinds.count] {
                    modelContext.insert(NaflLog(
                        kind: kind,
                        naflDate: day,
                        loggedAt: day,
                        createdAt: day,
                        modifiedAt: day
                    ))
                }
                if index % 3 != 1 {
                    let (phrase, count) = phrases[index % phrases.count]
                    modelContext.insert(DhikrSession(
                        sessionDate: day,
                        count: count,
                        phrase: phrase,
                        startedAt: day,
                        createdAt: day,
                        modifiedAt: day
                    ))
                }
            }
            try? modelContext.save()
        }
        // `-IhsanDebugLogFast ramadan:kept` seeds today's fast through
        // the standard funnel; composes with -IhsanNowOverride.
        if let flagIndex = arguments.firstIndex(of: "-IhsanDebugLogFast"),
           arguments.indices.contains(flagIndex + 1) {
            let parts = arguments[flagIndex + 1].split(separator: ":")
            if parts.count == 2,
               let kind = FastKind(rawValue: String(parts[0])),
               let state = FastState(rawValue: String(parts[1])) {
                let day = HijriConverter.daytimeCivilDay(at: NowProvider.active.now())
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
            _ = try? QadaLedgerWriter().recordEstimate(
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
                    // Offsets count CYCLES, not civil days, so a
                    // staged screenshot at 1 AM seeds the evenings a
                    // person would actually see on the pattern.
                    let dayOffset = parts.count >= 3 ? Int(parts[2]) ?? 0 : 0
                    let date: Date? = dayOffset == 0 ? nil : Calendar.current.date(
                        byAdding: .day,
                        value: dayOffset,
                        to: PrayerCycleClock.sharedCycleDate(at: NowProvider.active.now())
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
