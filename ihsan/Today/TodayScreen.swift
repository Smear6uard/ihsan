import SwiftUI
import SwiftData
import IhsanCore
import IhsanDesignSystem
import IhsanIntents
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

    /// Chrome tokens for the pre-ready states, resolved through the
    /// injected clock — the same quiet page system the secondary
    /// pages ride.
    private var chromeTokens: SkyPaletteTokens {
        IhsanPageChrome.tokens(at: nowProvider.now())
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel?.state {
        case .loading, nil:
            TodayLoadingView(tokens: chromeTokens)
                .ihsanManuscriptPage()
        case .needsLocationPermission:
            TodayNeedsLocationView(tokens: chromeTokens) { Task { await viewModel?.bootstrap() } }
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
            TodayErrorView(tokens: chromeTokens, message: message) { Task { await viewModel?.bootstrap() } }
                .ihsanManuscriptPage()
        }
    }
}

// MARK: - State views

private struct TodayLoadingView: View {
    let tokens: SkyPaletteTokens

    var body: some View {
        let foregroundSecondary = tokens.inkSecondary
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
    let tokens: SkyPaletteTokens
    let onRetry: () -> Void

    var body: some View {
        let foreground = tokens.ink
        let foregroundSecondary = tokens.inkSecondary
        let foregroundMuted = tokens.inkSecondary.opacity(0.7)
        let accent = tokens.leafGold
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
    let tokens: SkyPaletteTokens
    let message: String
    let onRetry: () -> Void

    var body: some View {
        let foreground = tokens.ink
        let foregroundSecondary = tokens.inkSecondary
        let foregroundMuted = tokens.inkSecondary.opacity(0.7)
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
// same derived `PrayerResolution` and palette tokens — to the header, the
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
    /// Today's fast, if one is recorded (intended or kept).
    @Query private var todaysFasts: [FastLog]
    /// Yesterday's prayer logs — the only day the account line ever
    /// speaks about.
    @Query private var yesterdaysLogs: [PrayerLog]

    private var activePause: PauseInterval? {
        pauses.first(where: \.isActive)
    }

    @State private var focusedPrayer: Prayer?
    @State private var sheetSelection: LogSheetSelection? = {
        // `-IhsanDebugPresentLogSheet <prayer>` — the screenshot
        // harness. Every debug affordance compiles out of release; a
        // shipped binary must not read launch arguments an attacker
        // or a curious user could set.
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-IhsanDebugPresentLogSheet"),
              index + 1 < arguments.count,
              let prayer = Prayer(rawValue: arguments[index + 1])
        else { return nil }
        return LogSheetSelection(prayer: prayer)
        #else
        return nil
        #endif
    }()
    @State private var revertFocusTask: Task<Void, Never>?
    @State private var isCelestialReferencePresented = DebugLaunch.flag("-IhsanDebugPresentQibla")
    @State private var isHijriSheetPresented = DebugLaunch.flag("-IhsanDebugPresentHijriSheet")
    /// Civil-day key ("2026-07-30") of the day the user dismissed the
    /// significant-day line — presentation state, not worship data.
    @AppStorage("IhsanSignificantDayDismissedDay")
    private var significantDayDismissedDay: String = ""
    /// Civil day the person last dismissed the yesterday line on.
    /// Presentation state, like the line above it — never worship data.
    @AppStorage("IhsanYesterdayOfferDismissedDay")
    private var yesterdayOfferDismissedDay: String = ""
    @State private var isYesterdaySheetPresented = DebugLaunch.flag("-IhsanDebugPresentYesterday")
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
    /// The remembrance set being read, if one is open.
    /// `-IhsanDebugPresentAdhkar morning|evening|postPrayer|sleep`
    /// opens one directly for the capture harness.
    @State private var adhkarSelection: AdhkarSelection? = {
        guard let raw = DebugLaunch.value(after: "-IhsanDebugPresentAdhkar"),
              let category = AdhkarCategory(rawValue: raw)
        else { return nil }
        return AdhkarSelection(category: category)
    }()
    /// Which remembrance offers have been put away today. Presentation
    /// state, like the significant-day and yesterday lines above it —
    /// never worship data, and a new day clears it without anything
    /// having to run at midnight.
    @AppStorage("IhsanAdhkarDismissedDay")
    private var adhkarDismissedDay: String = ""
    /// The tasbīḥ link asked which one; waiting on the answer.
    @State private var isChoosingPostPrayer = false

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

        let fastPredicate = #Predicate<FastLog> { log in
            log.fastDate >= startOfDay && log.fastDate < endOfDay
        }
        self._todaysFasts = Query(filter: fastPredicate, sort: \FastLog.fastDate)

        let yesterdayPredicate = #Predicate<PrayerLog> { log in
            log.prayerDate >= startOfYesterday && log.prayerDate < startOfDay
        }
        self._yesterdaysLogs = Query(filter: yesterdayPredicate, sort: \PrayerLog.prayerDate)
    }

    var body: some View {
        // `.distantPast` is a pure phase anchor for the periodic
        // schedule — the tick dates arrive in real time and are mapped
        // through NowProvider below. No wall-clock read happens here.
        TimelineView(.periodic(from: .distantPast, by: 1)) { context in
            let now = nowProvider.resolve(context.date)
            let resolverSchedule = snapshot.scheduleWindow.resolverSchedule
            let resolution = PrayerStateResolver.resolve(
                prayerTimes: resolverSchedule,
                now: now
            )
            let tokens = PaletteState.resolved(
                for: SkyPhase.resolve(at: now, events: solarEvents)
            )
            readyContent(now: now, resolution: resolution, tokens: tokens)
                .onAppear {
                    PrayerResolverDiagnostics.emit(
                        prayerTimes: resolverSchedule,
                        now: now,
                        resolution: resolution,
                        surface: "ios.today"
                    )
                }
                .onChange(of: resolution) { _, newResolution in
                    PrayerResolverDiagnostics.emit(
                        prayerTimes: resolverSchedule,
                        now: now,
                        resolution: newResolution,
                        surface: "ios.today"
                    )
                }
        }
    }

    @ViewBuilder
    private func readyContent(
        now: Date,
        resolution: PrayerResolution,
        tokens: SkyPaletteTokens
    ) -> some View {
        let windowExhausted = resolution.isScheduleExhausted

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
                hasDuhaCard: activeDuhaWindow(at: now) != nil && activePause == nil,
                hasAdhkarCard: adhkarOffer(at: now) != nil
            )

            ZStack(alignment: .bottom) {
                CelestialPlateScene(
                    markers: plateMarkers(resolution: resolution),
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
                        resolution: resolution,
                        timeZone: snapshot.place.timeZone,
                        tokens: tokens,
                        onMoonPhaseTap: { isCelestialReferencePresented = true },
                        onHijriTap: { isHijriSheetPresented = true },
                        significantDayInscription: headerLineText(at: now),
                        significantDayHint: headerLineHint(at: now),
                        onSignificantDayTap: { handleHeaderLineTap(at: now) },
                        yesterdayInscription: yesterdayOffer(at: now)?.inscription,
                        yesterdaySpokenLabel: yesterdayOffer(at: now)?.spokenLabel,
                        onYesterdayTap: { isYesterdaySheetPresented = true },
                        onYesterdayDismiss: {
                            yesterdayOfferDismissedDay = YesterdayAccount.civilDayKey(
                                now, calendar: placeCalendar
                            )
                        }
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
                        if let inscription = fastingInscription(at: now) {
                            fastingInscriptionRow(inscription, tokens: tokens, now: now)
                        }

                        focusedCard(now: now, resolution: resolution, tokens: tokens)

                        if let duhaWindow = activeDuhaWindow(at: now) {
                            DuhaQuietCard(
                                window: duhaWindow,
                                isLogged: naflLogged(.duha, on: todayDay(at: now)),
                                timeZone: snapshot.place.timeZone,
                                onToggle: { handleNaflTap(.duha) }
                            )
                        }
                    }

                    // OUTSIDE the pause branch, deliberately. A pause
                    // suspends salah and fasting — the things a person
                    // is excused from. It does not suspend remembrance,
                    // which is exactly what remains available to them.
                    // `AdhkarOfferTests` holds the rule; this is where
                    // it has to be true.
                    if let offer = adhkarOffer(at: now) {
                        AdhkarQuietCard(
                            category: offer.category,
                            window: offer.window,
                            timeZone: snapshot.place.timeZone,
                            tokens: tokens,
                            onOpen: { adhkarSelection = AdhkarSelection(category: offer.category) },
                            onDismiss: { dismissAdhkar(offer.category, at: now) }
                        )
                    }
                }
                .padding(.bottom, IhsanSpacing.md)
            }
            // The log sheet owns its presentation: a content-sized
            // medium detent, drag indicator, and SkyPhase-backed glass
            // are applied inside `PrayerLogSheet`.
            .sheet(item: $sheetSelection) { selection in
                logSheet(
                    for: selection.prayer,
                    now: now,
                    resolution: resolution
                )
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
            .sheet(isPresented: $isHijriSheetPresented) {
                hijriMonthSheet
            }
            .sheet(isPresented: $isYesterdaySheetPresented) {
                yesterdaySheet(at: now)
            }
            // The reading surface rides over everything, like the
            // tasbīḥ instrument it grew out of.
            .fullScreenCover(item: $adhkarSelection) { selection in
                AdhkarSetScreen(
                    category: selection.category,
                    showsTransliteration: sunnahSettings?.adhkarShowsTransliteration ?? true,
                    onDismiss: { adhkarSelection = nil }
                )
            }
            .confirmationDialog(
                "After the prayer",
                isPresented: $isChoosingPostPrayer,
                titleVisibility: .visible
            ) {
                Button("After-prayer adhkār") {
                    adhkarSelection = AdhkarSelection(category: .postPrayer)
                }
                Button("Free tasbīḥ") {
                    openFreeTasbih()
                }
                Button("Cancel", role: .cancel) {}
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
        resolution: PrayerResolution,
        tokens: SkyPaletteTokens
    ) -> some View {
        let prayer = effectiveFocusedPrayer(resolution: resolution)
        let prayerTime = TodayDisplaySchedule.prayerTime(
            for: prayer,
            window: snapshot.scheduleWindow,
            resolution: resolution
        )
        let windowState = resolution.state(for: prayerTime)
            ?? .upcoming(opensAt: prayerTime.scheduledTime)
        // A rolled prayer is tomorrow's instance: today's log no
        // longer attaches to it and its window end is not tonight's
        // business — the card shows a pure upcoming state.
        let rolled = TodayDisplaySchedule.isRolledToTomorrow(
            prayer, window: snapshot.scheduleWindow, resolution: resolution
        )
        let log = rolled ? nil : log(for: prayer)
        FocusedPrayerCard(
            prayer: prayer,
            scheduledTime: prayerTime.scheduledTime,
            windowEndTime: windowState.windowEnd,
            now: now,
            timeZone: snapshot.place.timeZone,
            tokens: tokens,
            currentStatus: log?.status,
            loggedAt: log?.loggedAt,
            isJamaah: log?.withJamaah ?? false,
            windowState: windowState,
            rawatib: rawatibChips(for: prayer, now: now),
            nightSet: nightChips(now: now),
            onToggleNafl: { kind in handleNaflTap(kind) },
            onCommit: { status, isJamaah in
                commit(status: status, isJamaah: isJamaah, for: prayer)
            },
            onMoreOptions: {
                sheetSelection = LogSheetSelection(prayer: prayer)
            },
            onTasbih: {
                // The natural post-prayer moment. With the
                // after-prayer set turned on there are two things a
                // person might mean by it, so the link asks; with it
                // off the link does exactly what it always did, and
                // nothing hints that a second option exists.
                if isPostPrayerSetOffered {
                    isChoosingPostPrayer = true
                } else {
                    openFreeTasbih()
                }
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
        let resolution = PrayerStateResolver.resolve(
            prayerTimes: snapshot.scheduleWindow.resolverSchedule,
            now: now
        )
        if resolution.currentPrayer == snapshot.scheduleWindow.yesterdayIsha {
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
            ),
            // Tarāwīḥ joins the night set for the month of Ramadan.
            tarawihLogged: snapshot.isCurrentlyRamadan
                ? naflLogged(.tarawih, on: nightDay)
                : nil
        )
    }

    private func activeDuhaWindow(at now: Date) -> DuhaWindow? {
        guard let settings = sunnahSettings,
              settings.sunnahLayerEnabled,
              settings.sunnahDuhaEnabled,
              let window = DuhaWindow(
                  sunrise: snapshot.scheduleWindow.day.sunrise,
                  dhuhr: snapshot.scheduleWindow.day.dhuhr.scheduledTime,
                  sunriseOffset: TimeInterval(settings.duhaSunriseOffsetMinutes * 60),
                  dhuhrMargin: TimeInterval(settings.duhaDhuhrMarginMinutes * 60)
              ),
              window.interval.contains(now)
        else { return nil }
        return window
    }

    // MARK: - The remembrance layer

    /// The day's remembrance windows, derived from its own solar
    /// events. The two settable bounds carry the places the schools
    /// differ; both defaults sit between the positions.
    private func adhkarWindows(at now: Date) -> AdhkarOffer.Windows {
        let day = snapshot.scheduleWindow.day
        let settings = sunnahSettings
        return AdhkarOffer.Windows(
            morning: AdhkarWindowResolver.morning(
                fajr: day.fajr.scheduledTime,
                sunrise: day.sunrise,
                dhuhr: day.dhuhr.scheduledTime,
                endsAfterSunrise: TimeInterval(
                    (settings?.adhkarMorningEndsAfterSunriseMinutes ?? 90) * 60
                )
            ),
            evening: AdhkarWindowResolver.evening(
                asr: day.asr.scheduledTime,
                maghrib: day.maghrib.scheduledTime,
                isha: day.isha.scheduledTime,
                extendsAfterMaghrib: TimeInterval(
                    (settings?.adhkarEveningExtendsAfterMaghribMinutes ?? 60) * 60
                )
            ),
            sleep: AdhkarWindowResolver.sleep(
                isha: day.isha.scheduledTime,
                nextFajr: snapshot.scheduleWindow.tomorrowFajr.scheduledTime
            )
        )
    }

    private func adhkarOffer(at now: Date) -> AdhkarOffer.Offer? {
        AdhkarOffer.offer(
            AdhkarOffer.Context(
                now: now,
                windows: adhkarWindows(at: now),
                preferences: AdhkarOffer.Preferences(settings: sunnahSettings),
                isIshaLogged: log(for: .isha) != nil,
                // Passed, and deliberately not acted on — see
                // `AdhkarOffer.pauseSuppresses`.
                isPaused: activePause != nil,
                dismissedCategories: AdhkarDismissal.decode(
                    adhkarDismissedDay,
                    dayKey: AdhkarDismissal.dayKey(now, calendar: placeCalendar)
                ),
                isContentAvailable: AdhkarAvailability.isAvailable
            )
        )
    }

    /// Whether the after-prayer set is something this person has asked
    /// for. Governs only whether the tasbīḥ link asks a question.
    private var isPostPrayerSetOffered: Bool {
        AdhkarAvailability.isAvailable
            && sunnahSettings?.adhkarLayerEnabled == true
            && sunnahSettings?.adhkarPostPrayerEnabled == true
    }

    private func openFreeTasbih() {
        // The instrument rides over the tabs; the root router presents
        // it.
        NotificationCenter.default.post(
            name: StartTasbihIntent.inAppNotificationName, object: nil
        )
    }

    private func dismissAdhkar(_ category: AdhkarCategory, at now: Date) {
        let key = AdhkarDismissal.dayKey(now, calendar: placeCalendar)
        var dismissed = AdhkarDismissal.decode(adhkarDismissedDay, dayKey: key)
        dismissed.insert(category)
        adhkarDismissedDay = AdhkarDismissal.encode(dismissed, dayKey: key)
    }

    private func naflDay(for kind: NaflKind, at now: Date) -> Date {
        switch kind {
        case .qiyam, .witr, .tarawih:
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
        case .tarawih:
            return [8, 20]
        }
    }

    // MARK: - Hijri awareness + the fasting layer

    private var hijriOffsetDays: Int {
        sunnahSettings?.hijriCalendarOffsetDays ?? 0
    }

    private var todaysFast: FastLog? {
        todaysFasts.first
    }

    /// The header's quiet line for today: a curated calendar fact
    /// (dismissible), or — when a rhythm is enabled — the same line
    /// doubling as a gentle fasting offer.
    private func headerLine(at now: Date) -> FastingDayModel.HeaderLine? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = snapshot.place.timeZone
        return FastingDayModel.headerLine(
            components: HijriConverter.components(
                for: now, offsetDays: hijriOffsetDays, timeZone: snapshot.place.timeZone
            ),
            weekday: calendar.component(.weekday, from: now),
            isRamadan: snapshot.isCurrentlyRamadan,
            monThuOfferEnabled: sunnahSettings?.fastingMonThuOfferEnabled ?? false,
            whiteDaysOfferEnabled: sunnahSettings?.fastingWhiteDaysOfferEnabled ?? false,
            isPaused: activePause != nil,
            hasFastToday: todaysFast != nil,
            dismissedForToday: significantDayDismissedDay == civilDayKey(at: now)
        )
    }

    /// The place's calendar — yesterday is a civil day where the
    /// prayers were, not where the device happens to be now.
    private var placeCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = snapshot.place.timeZone
        return calendar
    }

    /// Whether the app should mention yesterday at all. Every
    /// suppression rule lives in `YesterdayAccount`; this only asks.
    private func yesterdayOffer(at now: Date) -> YesterdayAccount.Offer? {
        YesterdayAccount.offer(
            now: now,
            logs: yesterdaysLogs,
            pauses: pauses,
            dismissedDayKey: yesterdayOfferDismissedDay,
            calendar: placeCalendar
        )
    }

    @ViewBuilder
    private func yesterdaySheet(at now: Date) -> some View {
        let calendar = placeCalendar
        let day = calendar.date(
            byAdding: .day, value: -1, to: calendar.startOfDay(for: now)
        ) ?? now
        let rows = YesterdayAccount.rows(
            for: day, logs: yesterdaysLogs, calendar: calendar
        )
        let tokens = PaletteState.resolved(
            for: SkyPhase.resolve(at: now, events: solarEvents)
        )

        YesterdaySheet(
            day: day,
            rows: rows,
            tokens: tokens,
            onCommit: { prayer, status, jamaah in
                commitYesterday(prayer, status: status, isJamaah: jamaah, on: day)
            },
            onCommitAllOnTime: {
                for prayer in Prayer.allCases {
                    commitYesterday(prayer, status: .onTime, isJamaah: false, on: day)
                }
            },
            onDone: {}
        )
        .presentationDetents([.large])
    }

    /// One retroactive commit, through the same intent funnel every
    /// other surface uses — so dedup, idempotency, and the makeup
    /// ledger all behave exactly as they do for today.
    private func commitYesterday(
        _ prayer: Prayer,
        status: PrayerStatus,
        isJamaah: Bool,
        on day: Date
    ) {
        Task {
            do {
                _ = try await LogPrayerWithStatusIntent(
                    prayer: prayer, status: status, date: day
                ).perform()
                if isJamaah, status != .missed {
                    _ = try await ToggleJamaahIntent(prayer: prayer, date: day).perform()
                }
            } catch {
                Haptics.warning()
            }
        }
    }

    private func headerLineText(at now: Date) -> String? {
        switch headerLine(at: now) {
        case .info(let text): return text
        case .offer(let text, _): return text
        case nil: return nil
        }
    }

    private func headerLineHint(at now: Date) -> String? {
        switch headerLine(at: now) {
        case .info: return "Dismisses this note for today."
        case .offer: return "Records a fasting intention for today."
        case nil: return nil
        }
    }

    private func handleHeaderLineTap(at now: Date) {
        switch headerLine(at: now) {
        case .info:
            significantDayDismissedDay = civilDayKey(at: now)
        case .offer(_, let kind):
            recordFast(kind: kind, state: .intended)
        case nil:
            break
        }
    }

    /// The quiet fasting inscription joining the focused-card region.
    private func fastingInscription(at now: Date) -> FastingDayModel.Inscription? {
        FastingDayModel.inscription(
            state: todaysFast?.state,
            isRamadan: snapshot.isCurrentlyRamadan,
            isPaused: activePause != nil,
            now: now,
            fajr: snapshot.scheduleWindow.day.fajr.scheduledTime,
            maghrib: snapshot.scheduleWindow.day.maghrib.scheduledTime,
            timeZone: snapshot.place.timeZone
        )
    }

    /// Inscription register, no countdown urgency: one small-caps
    /// line. Facts sit still; the two offers are quiet buttons.
    @ViewBuilder
    private func fastingInscriptionRow(
        _ inscription: FastingDayModel.Inscription,
        tokens: SkyPaletteTokens,
        now: Date
    ) -> some View {
        switch inscription {
        case .fact(let text):
            fastingLineLabel(text, tokens: tokens, outlined: false)
                .accessibilityLabel(text.capitalized)
        case .ramadanOffer(let text):
            Button {
                recordFast(kind: .ramadan, state: .kept)
            } label: {
                fastingLineLabel(text, tokens: tokens, outlined: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fasting today?")
            .accessibilityHint("Records today's Ramadan fast.")
        case .keptCompletion(let text):
            Button {
                recordFast(kind: todaysFast?.kind ?? .other, state: .kept)
            } label: {
                fastingLineLabel(text, tokens: tokens, outlined: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fast kept?")
            .accessibilityHint("Records the intended fast as kept.")
        }
    }

    private func fastingLineLabel(
        _ text: String, tokens: SkyPaletteTokens, outlined: Bool
    ) -> some View {
        Text(text)
            .font(IhsanFont.inscription)
            .tracking(1.4)
            .foregroundStyle(tokens.inkSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .shadow(color: tokens.inkHaloDark, radius: 1)
            .shadow(color: tokens.inkHaloLight, radius: 3)
            .padding(.horizontal, outlined ? 12 : 0)
            .padding(.vertical, outlined ? 4 : 0)
            .overlay {
                if outlined {
                    Capsule().strokeBorder(
                        tokens.metal.opacity(0.45), lineWidth: 0.8
                    )
                }
            }
            .frame(maxWidth: .infinity)
    }

    /// One funnel, instant feedback: the settle fires before the
    /// intent persists, and the @Query re-render carries the truth.
    private func recordFast(kind: FastKind, state: FastState) {
        Haptics.settle()
        let day = todayDay(at: nowProvider.now())
        Task {
            _ = try? await LogFastIntent(kind: kind, state: state, fastDate: day).perform()
        }
    }

    private func civilDayKey(at now: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = snapshot.place.timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: now)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }

    @ViewBuilder
    private var hijriMonthSheet: some View {
        let now = nowProvider.now()
        let tokens = PaletteState.resolved(
            for: SkyPhase.resolve(at: now, events: solarEvents)
        )
        HijriMonthSheet(
            days: HijriConverter.monthDays(
                containing: now,
                offsetDays: hijriOffsetDays,
                timeZone: snapshot.place.timeZone
            ),
            today: HijriConverter.components(
                for: now, offsetDays: hijriOffsetDays, timeZone: snapshot.place.timeZone
            ),
            timeZone: snapshot.place.timeZone,
            weekStartsOnSaturday: sunnahSettings?.weekStartsOnSaturday ?? true,
            tokens: tokens
        )
    }

    // MARK: - Plate inputs

    /// The five solar events that anchor the palette phase, taken from
    /// the day's real schedule. Dhuhr stands in for solar noon — it is
    /// defined as the moment just after the sun's upper transit, which
    /// is exactly the anchor `SkyPhase` wants.
    private var solarEvents: SolarDayEvents {
        SolarDayEvents(
            fajr: snapshot.scheduleWindow.day.fajr.scheduledTime,
            sunrise: snapshot.scheduleWindow.day.sunrise,
            solarNoon: snapshot.scheduleWindow.day.dhuhr.scheduledTime,
            maghrib: snapshot.scheduleWindow.day.maghrib.scheduledTime,
            isha: snapshot.scheduleWindow.day.isha.scheduledTime
        )
    }

    private func plateMarkers(
        resolution: PrayerResolution
    ) -> [CelestialPlateScene.Marker] {
        snapshot.scheduleWindow.day.allFardh.map { time in
            let displayPrayerTime = TodayDisplaySchedule.prayerTime(
                for: time.prayer,
                window: snapshot.scheduleWindow,
                resolution: resolution
            )
            return CelestialPlateScene.Marker(
                prayer: time.prayer,
                time: time.scheduledTime,
                displayTime: displayPrayerTime.scheduledTime,
                state: markerState(
                    for: time.prayer,
                    prayerTime: displayPrayerTime,
                    resolution: resolution
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
        prayerTime: PrayerTime,
        resolution: PrayerResolution
    ) -> PrayerMarkerState {
        // During an excused pause every marker rests in the neutral outline
        // state — no glow, no passed-unlogged ink. Times stay readable;
        // nothing is asked.
        if activePause != nil { return .upcoming }
        let state = resolution.state(for: prayerTime)
            ?? .upcoming(opensAt: prayerTime.scheduledTime)
        if state.isCurrent { return .current }
        let rolled = prayerTime == snapshot.scheduleWindow.tomorrowFajr
        // A rolled marker represents tomorrow's instance, so today's
        // log no longer speaks for it.
        if rolled { return .upcoming }
        if log(for: prayer) != nil { return .logged }
        switch state {
        case .upcoming: return .upcoming
        case .current: return .current
        case .closed: return .passedUnlogged
        }
    }

    /// The moment's current prayer projected onto *today's* plate: nil
    /// when the open window belongs to yesterday's Isha (pre-dawn),
    /// whose place on this plate is the night bowl, not the markers.
    private func displayCurrentPrayer(resolution: PrayerResolution) -> Prayer? {
        guard let current = resolution.currentPrayer else { return nil }
        guard snapshot.scheduleWindow.day.time(for: current.prayer) == current.scheduledTime else {
            return nil
        }
        return current.prayer
    }

    /// The card's default focus: the open window's prayer, or the
    /// next prayer when no window is open. Focus is not a "current"
    /// claim — the card renders the upcoming state for a prayer whose
    /// window hasn't opened, and only `displayCurrentPrayer` can make
    /// a marker luminous.
    private func defaultFocusPrayer(resolution: PrayerResolution) -> Prayer {
        displayCurrentPrayer(resolution: resolution) ?? resolution.nextPrayer.prayer
    }

    // MARK: - Focused prayer resolution

    /// The prayer the focused card is currently displaying. The user
    /// can override the default by tapping a marker on the scene; the
    /// override reverts to the next-upcoming after 8 sec per spec.
    private func effectiveFocusedPrayer(resolution: PrayerResolution) -> Prayer {
        focusedPrayer ?? defaultFocusPrayer(resolution: resolution)
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
    private func logSheet(
        for prayer: Prayer,
        now: Date,
        resolution: PrayerResolution
    ) -> some View {
        let prayerTime = snapshot.scheduleWindow.day.allFardh.first { $0.prayer == prayer }
        let log = log(for: prayer)
        // Presentation-time palette — the sheet lives on the same
        // SkyPhase and consumes the same per-tick resolution as the
        // plate, header, and card behind it.
        let tokens = PaletteState.resolved(
            for: SkyPhase.resolve(at: now, events: solarEvents)
        )

        if prayerTime != nil {
            let displayPrayerTime = TodayDisplaySchedule.prayerTime(
                for: prayer,
                window: snapshot.scheduleWindow,
                resolution: resolution
            )
            let windowState = resolution.state(for: displayPrayerTime)
                ?? .upcoming(opensAt: displayPrayerTime.scheduledTime)
            PrayerLogSheet(
                prayer: prayer,
                // The same display instant the plate label, header,
                // and card show — one source, one formatter.
                scheduledTime: displayPrayerTime.scheduledTime,
                windowEndTime: windowState.windowEnd,
                timeZone: snapshot.place.timeZone,
                tokens: tokens,
                currentStatus: log?.status,
                isJamaah: log?.withJamaah ?? false,
                isPaused: activePause != nil,
                // The truth rule: what can be true at this moment for
                // this prayer today decides which tiles are live.
                availableStatuses: TimingAvailability.allowedStatuses(
                    now: now,
                    dayBeingLogged: now,
                    windowState: windowState,
                    currentStatus: log?.status
                ),
                windowState: windowState,
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
        // One deliberate action, one medium impact. It used to fire a
        // success notification as well, so a single tap produced a
        // thud and then a rising double-tap — and a pause is neither
        // an achievement nor an operation that might have failed.
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

/// The remembrance set currently open, as a presentation selection.
private struct AdhkarSelection: Identifiable {
    let category: AdhkarCategory
    var id: String { category.rawValue }
}
