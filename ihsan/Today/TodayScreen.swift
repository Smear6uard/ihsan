import SwiftUI
import SwiftData
import IhsanCore
import IhsanDesignSystem
import IhsanLocation
import IhsanNotifications
import IhsanPrayerTimes

struct TodayScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.nowProvider) private var nowProvider
    @State private var viewModel: TodayViewModel?

    var body: some View {
        content
            .task {
                if viewModel == nil {
                    viewModel = TodayViewModel(
                        nowProvider: nowProvider,
                        modelContext: modelContext
                    )
                    Haptics.prepareAll()
                }
                await viewModel?.bootstrap()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel?.state {
        case .loading, nil:
            TodayLoadingView()
                .ihsanManuscriptPage()
        case .needsLocationPermission:
            TodayNeedsLocationView { Task { await viewModel?.bootstrap() } }
                .ihsanManuscriptPage()
        case .ready(let snapshot):
            if let viewModel {
                TodayReadyView(
                    snapshot: snapshot,
                    viewModel: viewModel,
                    dayAnchor: nowProvider.now()
                )
            }
        case .error(let message):
            TodayErrorView(message: message) { Task { await viewModel?.bootstrap() } }
                .ihsanManuscriptPage()
        }
    }
}

// MARK: - State views

private struct TodayLoadingView: View {
    var body: some View {
        let foregroundSecondary = IhsanColor.skyForegroundSecondary()
        VStack(spacing: IhsanSpacing.md) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(foregroundSecondary)
            Text("Loading prayer times…")
                .font(IhsanFont.smallCaps)
                .foregroundStyle(foregroundSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading prayer times")
    }
}

private struct TodayNeedsLocationView: View {
    let onRetry: () -> Void

    var body: some View {
        let foreground = IhsanColor.skyForegroundPrimary()
        let foregroundSecondary = IhsanColor.skyForegroundSecondary()
        let foregroundMuted = IhsanColor.skyForegroundMuted()
        let accent = IhsanColor.accentWarm()
        VStack(spacing: IhsanSpacing.lg) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 48))
                .foregroundStyle(foregroundMuted)
            Text("Location access is needed")
                .font(IhsanFont.subtitle)
                .foregroundStyle(foreground)
            Text("Ihsan calculates prayer times from your current location. Coordinates are never stored or shared.")
                .font(IhsanFont.bodyEnglish)
                .foregroundStyle(foregroundSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, IhsanSpacing.xl)
            Button("Continue") {
                Haptics.impact(.light)
                onRetry()
            }
                .buttonStyle(.borderedProminent)
                .tint(accent.opacity(0.30))
                .foregroundStyle(foreground)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct TodayErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        let foreground = IhsanColor.skyForegroundPrimary()
        let foregroundSecondary = IhsanColor.skyForegroundSecondary()
        let foregroundMuted = IhsanColor.skyForegroundMuted()
        VStack(spacing: IhsanSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(foregroundMuted)
            Text(message)
                .font(IhsanFont.bodyEnglish)
                .foregroundStyle(foregroundSecondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Haptics.impact(.light)
                onRetry()
            }
                .buttonStyle(.bordered)
                .tint(foreground)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Ready state: the celestial Today screen
//
//   ┌─────────────────────────────┐
//   │ Zone 1 — refined header     │   ~10% of screen
//   │ Zone 2 — celestial scene    │   sky, sun, moon, markers
//   │ Zone 3 — focused-prayer card│   single illuminated panel
//   └─────────────────────────────┘
//
// One clock: a single one-second TimelineView at this level resolves
// the moment through NowProvider and hands the same `now` — and the
// same derived `PrayerMoment` and palette tokens — to the header, the
// scene, the markers, and the focused card. No child owns a timeline
// or reads the wall clock, so no two surfaces can disagree about what
// time it is, which prayer is current, or when the window turns.

private struct TodayReadyView: View {
    let snapshot: TodayState.Snapshot
    let viewModel: TodayViewModel
    /// Day anchor for the SwiftData queries, resolved by the caller
    /// through NowProvider at init. A snapshot refresh re-creates this
    /// view, so the anchor rolls forward with the schedule window.
    let dayAnchor: Date

    @Environment(\.modelContext) private var modelContext
    @Environment(\.nowProvider) private var nowProvider

    @Query private var todaysLogs: [PrayerLog]
    @Query private var settingsRows: [UserSettings]
    @Query(sort: \PauseInterval.startDate, order: .reverse) private var pauses: [PauseInterval]
    /// Yesterday's and today's voluntary records — yesterday's because a
    /// night act logged after midnight belongs to the night-of day.
    @Query private var recentNaflLogs: [NaflLog]

    private var activePause: PauseInterval? {
        pauses.first(where: \.isActive)
    }

    @State private var focusedPrayer: Prayer?
    @State private var sheetSelection: LogSheetSelection? = {
        // `-IhsanDebugPresentLogSheet <prayer>` — simulator screenshot
        // harness; mirrors -IhsanDebugPresentQibla.
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-IhsanDebugPresentLogSheet"),
              index + 1 < arguments.count,
              let prayer = Prayer(rawValue: arguments[index + 1])
        else { return nil }
        return LogSheetSelection(prayer: prayer)
    }()
    @State private var revertFocusTask: Task<Void, Never>?
    @State private var isCelestialReferencePresented = ProcessInfo.processInfo
        .arguments.contains("-IhsanDebugPresentQibla")
    /// Entrance choreography target — 0 until the first frame has a
    /// chance to render at rest-zero, then 1; the scene's layers
    /// animate toward it on their staggered clocks. Replays after a
    /// long absence from the foreground.
    @State private var entranceProgress: Double = 0
    @State private var lastActiveAt: Date?
    @Environment(\.scenePhase) private var scenePhase
    /// A nafl waiting on the rak'ah dialog — only ever set when the user
    /// opted into counts.
    @State private var pendingRakahNafl: PendingNafl?

    /// Time the focused-prayer card stays on a marker-tapped prayer
    /// before reverting to the next-upcoming prayer per spec.
    private static let focusRevertInterval: TimeInterval = 8
    /// Absence long enough that returning replays the entrance.
    private static let entranceReplayInterval: TimeInterval = 30 * 60

    init(
        snapshot: TodayState.Snapshot,
        viewModel: TodayViewModel,
        dayAnchor: Date
    ) {
        self.snapshot = snapshot
        self.viewModel = viewModel
        self.dayAnchor = dayAnchor

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: dayAnchor)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        let predicate = #Predicate<PrayerLog> { log in
            log.prayerDate >= startOfDay && log.prayerDate < endOfDay
        }
        self._todaysLogs = Query(filter: predicate, sort: \PrayerLog.prayerDate)

        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfDay) ?? startOfDay
        let naflPredicate = #Predicate<NaflLog> { log in
            log.naflDate >= startOfYesterday && log.naflDate < endOfDay
        }
        self._recentNaflLogs = Query(filter: naflPredicate, sort: \NaflLog.naflDate)
    }

    var body: some View {
        // `.distantPast` is a pure phase anchor for the periodic
        // schedule — the tick dates arrive in real time and are mapped
        // through NowProvider below. No wall-clock read happens here.
        TimelineView(.periodic(from: .distantPast, by: 1)) { context in
            let now = nowProvider.resolve(context.date)
            let moment = snapshot.scheduleWindow.moment(at: now)
            let tokens = PaletteState.resolved(
                for: SkyPhase.resolve(at: now, events: solarEvents)
            )
            readyContent(now: now, moment: moment, tokens: tokens)
        }
    }

    @ViewBuilder
    private func readyContent(
        now: Date,
        moment: PrayerMoment,
        tokens: SkyPaletteTokens
    ) -> some View {
        let windowExhausted = now >= snapshot.scheduleWindow.tomorrowFajr.scheduledTime

        GeometryReader { proxy in
            // The proxy is safe-area-bounded (the tab bar adds a
            // bottom inset); the metrics live in full-screen
            // coordinates, matching the edge-to-edge plate scene.
            let metrics = TodayCompositionMetrics(
                size: CGSize(
                    width: proxy.size.width,
                    height: proxy.size.height
                        + proxy.safeAreaInsets.top
                        + proxy.safeAreaInsets.bottom
                ),
                safeAreaTop: proxy.safeAreaInsets.top,
                safeAreaBottom: proxy.safeAreaInsets.bottom,
                cardHeight: FocusedPrayerCard.cardHeight,
                hasDuhaCard: activeDuhaWindow(at: now) != nil && activePause == nil
            )

            ZStack(alignment: .bottom) {
                CelestialPlateScene(
                    markers: plateMarkers(now: now, moment: moment),
                    solarEvents: solarEvents,
                    latitude: snapshot.place.coordinates.latitude,
                    longitude: snapshot.place.coordinates.longitude,
                    timeZone: snapshot.place.timeZone,
                    now: now,
                    topInset: metrics.plateTopInset,
                    bottomInset: metrics.plateBottomInset,
                    horizonFraction: metrics.plateHorizonFraction,
                    night: snapshot.night,
                    onMarkerTap: handleMarkerTap,
                    entrance: entranceProgress
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    TodayHeader(
                        cityName: snapshot.place.cityName ?? "Current Location",
                        now: now,
                        moment: moment,
                        timeZone: snapshot.place.timeZone,
                        onMoonPhaseTap: { isCelestialReferencePresented = true }
                    )
                    .padding(.horizontal, IhsanSpacing.md)
                    .padding(.top, IhsanSpacing.md)

                    Spacer(minLength: 0)
                }

                VStack(spacing: IhsanSpacing.sm) {
                    if let activePause {
                        RepairPausedCard(
                            expectedEndDate: activePause.expectedEndDate,
                            tokens: tokens,
                            onEndPause: { togglePause() }
                        )
                    } else {
                        focusedCard(now: now, moment: moment, tokens: tokens)

                        if let duhaWindow = activeDuhaWindow(at: now) {
                            DuhaQuietCard(
                                window: duhaWindow,
                                isLogged: naflLogged(.duha, on: todayDay(at: now)),
                                timeZone: snapshot.place.timeZone,
                                onToggle: { handleNaflTap(.duha) }
                            )
                        }
                    }
                }
                .padding(.bottom, IhsanSpacing.md)
            }
            // The log sheet owns its presentation: a content-sized
            // medium detent, drag indicator, and SkyPhase-backed glass
            // are applied inside `PrayerLogSheet`.
            .sheet(item: $sheetSelection) { selection in
                logSheet(for: selection.prayer)
            }
            .sheet(isPresented: $isCelestialReferencePresented) {
                QiblaScreen(
                    latitude: snapshot.place.coordinates.latitude,
                    longitude: snapshot.place.coordinates.longitude,
                    solarEvents: solarEvents
                )
                .presentationDragIndicator(.visible)
                .presentationBackground(.thinMaterial)
            }
            .confirmationDialog(
                "How many rak'ah?",
                isPresented: Binding(
                    get: { pendingRakahNafl != nil },
                    set: { if !$0 { pendingRakahNafl = nil } }
                ),
                titleVisibility: .visible,
                presenting: pendingRakahNafl
            ) { pending in
                ForEach(rakahOptions(for: pending.kind), id: \.self) { count in
                    Button("\(count) rak'ah") {
                        performNafl(pending.kind, rakahCount: count)
                    }
                }
                Button("Just record") {
                    performNafl(pending.kind, rakahCount: nil)
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        // Once the clock crosses tomorrow's Fajr the schedule window is
        // exhausted — refresh the snapshot exactly once so a fresh
        // bracketed window (and fresh day queries) takes over.
        .task(id: windowExhausted) {
            if windowExhausted {
                try? await viewModel.refreshSnapshot()
            }
        }
        // The entrance: fire once after first appearance (the state
        // starts at 0 so the first frame composes at rest-zero, then
        // the layers animate in on their staggered clocks), and again
        // when returning to the foreground after a long absence.
        .task {
            if entranceProgress == 0 {
                entranceProgress = 1
            }
            lastActiveAt = nowProvider.now()
        }
        .onChange(of: scenePhase) { _, phase in
            let now = nowProvider.now()
            if phase == .active {
                if let last = lastActiveAt,
                   now.timeIntervalSince(last) > Self.entranceReplayInterval {
                    entranceProgress = 0
                    Task { @MainActor in
                        // One runloop turn at rest-zero, then enter.
                        entranceProgress = 1
                    }
                }
                lastActiveAt = now
            } else {
                lastActiveAt = now
            }
        }
    }

    @ViewBuilder
    private func focusedCard(
        now: Date,
        moment: PrayerMoment,
        tokens: SkyPaletteTokens
    ) -> some View {
        let prayer = effectiveFocusedPrayer(moment: moment)
        // A rolled prayer is tomorrow's instance: today's log no
        // longer attaches to it and its window end is not tonight's
        // business — the card shows a pure upcoming state.
        let rolled = TodayDisplaySchedule.isRolledToTomorrow(
            prayer, window: snapshot.scheduleWindow, now: now
        )
        let log = rolled ? nil : log(for: prayer)
        FocusedPrayerCard(
            prayer: prayer,
            scheduledTime: TodayDisplaySchedule.displayTime(
                for: prayer, window: snapshot.scheduleWindow, now: now
            ),
            windowEndTime: rolled ? nil : windowEndTime(for: prayer),
            now: now,
            timeZone: snapshot.place.timeZone,
            tokens: tokens,
            currentStatus: log?.status,
            loggedAt: log?.loggedAt,
            isJamaah: log?.withJamaah ?? false,
            isInWindow: displayCurrentPrayer(moment: moment) == prayer,
            rawatib: rawatibChips(for: prayer, now: now),
            nightSet: nightChips(now: now),
            onToggleNafl: { kind in handleNaflTap(kind) },
            onCommit: { status, isJamaah in
                commit(status: status, isJamaah: isJamaah, for: prayer)
            },
            onMoreOptions: {
                sheetSelection = LogSheetSelection(prayer: prayer)
            }
        )
    }

    // MARK: - Sunnah layer

    private var sunnahSettings: UserSettings? {
        settingsRows.first
    }

    private func todayDay(at now: Date) -> Date {
        Calendar.current.startOfDay(for: now)
    }

    /// The civil day tonight's night acts belong to: before today's Fajr
    /// the night began yesterday evening.
    private func nightOfDay(at now: Date) -> Date {
        let today = todayDay(at: now)
        if now < snapshot.dayTimes.fajr.scheduledTime {
            return Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today
        }
        return today
    }

    private func naflLogged(_ kind: NaflKind, on day: Date) -> Bool {
        let key = NaflLog.makeDedupKey(kind: kind, naflDate: day)
        return recentNaflLogs.contains { $0.dedupKey == key }
    }

    private func rawatibChips(
        for prayer: Prayer,
        now: Date
    ) -> FocusedPrayerCard.RawatibChips? {
        guard let settings = sunnahSettings,
              settings.sunnahLayerEnabled,
              settings.sunnahRawatibEnabled
        else { return nil }

        let config = settings.rawatibConfig(for: prayer)
        guard config.beforeCount > 0 || config.afterCount > 0 else { return nil }

        let today = todayDay(at: now)
        return FocusedPrayerCard.RawatibChips(
            beforeCount: config.beforeCount,
            afterCount: config.afterCount,
            beforeLogged: naflLogged(.rawatibBefore(prayer), on: today),
            afterLogged: naflLogged(.rawatibAfter(prayer), on: today)
        )
    }

    /// The night set appears once the night is in progress and Isha is
    /// either logged or its emphasis has passed (nisf al-layl). It rides
    /// whichever card is focused — Isha in the evening, Fajr before dawn.
    private func nightChips(now: Date) -> FocusedPrayerCard.NightChips? {
        guard let settings = sunnahSettings,
              settings.sunnahLayerEnabled,
              settings.sunnahNightEnabled,
              let night = snapshot.night,
              night.contains(now)
        else { return nil }

        let ishaLogged = log(for: .isha) != nil
        guard ishaLogged || now >= night.nisfAlLayl else { return nil }

        let nightDay = nightOfDay(at: now)
        let witrLogs = recentNaflLogs.filter { $0.kind == .witr }
        return FocusedPrayerCard.NightChips(
            qiyamLogged: naflLogged(.qiyam, on: nightDay),
            witrLogged: naflLogged(.witr, on: nightDay),
            witrBridge: NaflWitrBridge.state(
                forNightOf: nightDay,
                witrLogs: witrLogs,
                tracksWitrQada: settings.qadaTrackingEnabled && settings.qadaTracksWitr
            )
        )
    }

    private func activeDuhaWindow(at now: Date) -> DuhaWindow? {
        guard let settings = sunnahSettings,
              settings.sunnahLayerEnabled,
              settings.sunnahDuhaEnabled,
              let window = DuhaWindow(
                  sunrise: snapshot.dayTimes.sunrise,
                  dhuhr: snapshot.dayTimes.dhuhr.scheduledTime,
                  sunriseOffset: TimeInterval(settings.duhaSunriseOffsetMinutes * 60),
                  dhuhrMargin: TimeInterval(settings.duhaDhuhrMarginMinutes * 60)
              ),
              window.interval.contains(now)
        else { return nil }
        return window
    }

    private func naflDay(for kind: NaflKind, at now: Date) -> Date {
        switch kind {
        case .qiyam, .witr:
            return nightOfDay(at: now)
        case .duha, .rawatibBefore, .rawatibAfter:
            return todayDay(at: now)
        }
    }

    /// The chip already fired its haptic. Removal and count-free logging
    /// go straight through; the rak'ah dialog appears only when the user
    /// opted into counts and this tap would record something new.
    private func handleNaflTap(_ kind: NaflKind) {
        let day = naflDay(for: kind, at: nowProvider.now())
        let isRemoval = naflLogged(kind, on: day)
        if !isRemoval, sunnahSettings?.sunnahRakahCountsEnabled == true {
            pendingRakahNafl = PendingNafl(kind: kind)
            return
        }
        performNafl(kind, rakahCount: nil)
    }

    private func performNafl(_ kind: NaflKind, rakahCount: Int?) {
        let day = naflDay(for: kind, at: nowProvider.now())
        Task {
            await viewModel.toggleNafl(kind: kind, naflDate: day, rakahCount: rakahCount)
        }
    }

    private func rakahOptions(for kind: NaflKind) -> [Int] {
        switch kind {
        case .rawatibBefore(let prayer):
            let configured = sunnahSettings?.rawatibConfig(for: prayer).beforeCount ?? 2
            return Array(Set([configured, 2, 4]).subtracting([0])).sorted()
        case .rawatibAfter(let prayer):
            let configured = sunnahSettings?.rawatibConfig(for: prayer).afterCount ?? 2
            return Array(Set([configured, 2, 4]).subtracting([0])).sorted()
        case .duha:
            return [2, 4, 6, 8]
        case .qiyam:
            return [2, 4, 8, 12]
        case .witr:
            return [1, 3, 5, 7, 9, 11]
        }
    }

    // MARK: - Plate inputs

    /// The four solar events that anchor the palette phase, taken from
    /// the day's real schedule. Dhuhr stands in for solar noon — it is
    /// defined as the moment just after the sun's upper transit, which
    /// is exactly the anchor `SkyPhase` wants.
    private var solarEvents: SolarDayEvents {
        SolarDayEvents(
            sunrise: snapshot.dayTimes.sunrise,
            solarNoon: snapshot.dayTimes.dhuhr.scheduledTime,
            maghrib: snapshot.dayTimes.maghrib.scheduledTime,
            isha: snapshot.dayTimes.isha.scheduledTime
        )
    }

    private func plateMarkers(
        now: Date,
        moment: PrayerMoment
    ) -> [CelestialPlateScene.Marker] {
        snapshot.dayTimes.allFardh.map { time in
            CelestialPlateScene.Marker(
                prayer: time.prayer,
                time: time.scheduledTime,
                displayTime: TodayDisplaySchedule.displayTime(
                    for: time.prayer, window: snapshot.scheduleWindow, now: now
                ),
                state: markerState(
                    for: time.prayer,
                    now: now,
                    moment: moment
                )
            )
        }
    }

    /// A marker is luminous only while its own window contains the
    /// moment — a prayer that has not begun is never presented as
    /// current, on the plate or anywhere else. When no window is open
    /// (the forenoon gap, the pre-dawn hours) no marker is luminous;
    /// the focused card still carries the next prayer's upcoming
    /// state, and at night the bowl's cursor carries "now."
    private func markerState(
        for prayer: Prayer,
        now: Date,
        moment: PrayerMoment
    ) -> PrayerMarkerState {
        // During an excused pause every marker rests in the neutral outline
        // state — no glow, no passed-unlogged ink. Times stay readable;
        // nothing is asked.
        if activePause != nil { return .upcoming }
        if prayer == displayCurrentPrayer(moment: moment) { return .current }
        // A rolled marker represents tomorrow's instance — upcoming by
        // definition, today's log no longer speaks for it.
        if TodayDisplaySchedule.isRolledToTomorrow(
            prayer, window: snapshot.scheduleWindow, now: now
        ) {
            return .upcoming
        }
        if log(for: prayer) != nil { return .logged }
        let displayTime = TodayDisplaySchedule.displayTime(
            for: prayer, window: snapshot.scheduleWindow, now: now
        )
        return displayTime > now ? .upcoming : .passedUnlogged
    }

    /// The moment's current prayer projected onto *today's* plate: nil
    /// when the open window belongs to yesterday's Isha (pre-dawn),
    /// whose place on this plate is the night bowl, not the markers.
    private func displayCurrentPrayer(moment: PrayerMoment) -> Prayer? {
        guard let current = moment.current else { return nil }
        guard snapshot.dayTimes.time(for: current.prayer) == current.scheduledTime else {
            return nil
        }
        return current.prayer
    }

    /// The card's default focus: the open window's prayer, or the
    /// next prayer when no window is open. Focus is not a "current"
    /// claim — the card renders the upcoming state for a prayer whose
    /// window hasn't opened, and only `displayCurrentPrayer` can make
    /// a marker luminous.
    private func defaultFocusPrayer(moment: PrayerMoment) -> Prayer {
        displayCurrentPrayer(moment: moment) ?? moment.next.prayer
    }

    // MARK: - Focused prayer resolution

    /// The prayer the focused card is currently displaying. The user
    /// can override the default by tapping a marker on the scene; the
    /// override reverts to the next-upcoming after 8 sec per spec.
    private func effectiveFocusedPrayer(moment: PrayerMoment) -> Prayer {
        focusedPrayer ?? defaultFocusPrayer(moment: moment)
    }

    private func handleMarkerTap(_ prayer: Prayer) {
        Haptics.impact(.light)
        focusedPrayer = prayer
        scheduleFocusRevert()
    }

    private func scheduleFocusRevert() {
        revertFocusTask?.cancel()
        revertFocusTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(Self.focusRevertInterval * 1_000_000_000))
            if !Task.isCancelled {
                focusedPrayer = nil
            }
        }
    }

    // MARK: - Prayer time / log lookups

    /// End of `prayer`'s window — the one rule, shared with the sheet
    /// and pinned against `moment(at:)` by `PrayerWindowSemanticsTests`.
    private func windowEndTime(for prayer: Prayer) -> Date? {
        PrayerWindowRule.windowEnd(for: prayer, in: snapshot.scheduleWindow)
    }

    private func log(for prayer: Prayer) -> PrayerLog? {
        todaysLogs.first { $0.prayer == prayer }
    }

    // MARK: - Commit

    /// Translate the orthogonal `(timing, jamaʿah)` commit into the
    /// existing `setStatus` + `toggleJamaah` view-model methods.
    private func commit(status: PrayerStatus, isJamaah: Bool, for prayer: Prayer) {
        let existingJamaah = log(for: prayer)?.withJamaah ?? false
        Task {
            await viewModel.setStatus(status, for: prayer)
            if isJamaah != existingJamaah {
                await viewModel.toggleJamaah(for: prayer)
            }
        }
    }

    // MARK: - Log sheet (the long tail: qadā, missed, edit)

    @ViewBuilder
    private func logSheet(for prayer: Prayer) -> some View {
        let prayerTime = snapshot.dayTimes.allFardh.first { $0.prayer == prayer }
        let log = log(for: prayer)
        // Presentation-time palette — the sheet lives on the same
        // SkyPhase as the plate behind it.
        let now = nowProvider.now()
        let tokens = PaletteState.resolved(
            for: SkyPhase.resolve(at: now, events: solarEvents)
        )

        if prayerTime != nil {
            PrayerLogSheet(
                prayer: prayer,
                // The same display instant the plate label, header,
                // and card show — one source, one formatter.
                scheduledTime: TodayDisplaySchedule.displayTime(
                    for: prayer, window: snapshot.scheduleWindow, now: now
                ),
                windowEndTime: windowEndTime(for: prayer),
                timeZone: snapshot.place.timeZone,
                tokens: tokens,
                currentStatus: log?.status,
                isJamaah: log?.withJamaah ?? false,
                isPaused: activePause != nil,
                onCommit: { status, jamaah in
                    commit(status: status, isJamaah: jamaah, for: prayer)
                },
                onTogglePause: { togglePause() },
                onCancel: {}
            )
        }
    }

    /// One tap begins an excused pause; the same control ends it. The
    /// notification schedule rebuilds either way, so suppression tracks the
    /// pause without touching any stored preference.
    private func togglePause() {
        Haptics.impact(.medium)
        let now = nowProvider.now()
        if let activePause {
            activePause.endDate = now
            activePause.modifiedAt = now
        } else {
            modelContext.insert(PauseInterval(
                startDate: now,
                loggedTimeZoneIdentifier: TimeZone.current.identifier,
                createdAt: now,
                modifiedAt: now
            ))
        }
        Haptics.notification(.success)
        Task {
            try? await NotificationScheduler.shared.rebuildSchedule()
            await NightWakeService.shared.refresh(using: modelContext)
        }
    }

}

/// Identifies which prayer's log sheet is currently presented.
/// Hashable so it works as `sheet(item:)`'s identifier.
private struct LogSheetSelection: Identifiable, Hashable {
    let prayer: Prayer
    var id: Prayer { prayer }
}

/// A nafl waiting on the rak'ah-count dialog.
private struct PendingNafl: Identifiable {
    let kind: NaflKind
    var id: String { kind.storageKey }
}
