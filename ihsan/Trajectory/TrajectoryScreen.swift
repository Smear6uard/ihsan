import SwiftUI
import SwiftData
import IhsanCore
import IhsanDesignSystem
import IhsanFiqhConfig
import IhsanInsights
import IhsanIntents
import IhsanNotifications

/// The Path tab.
///
/// Reads `PrayerLog`, `PauseInterval`, and `TravelInterval` directly
/// from SwiftData via `@Query`, hands them to a `TrajectoryViewModel`
/// for aggregation, and presents — top to bottom, data first:
///
/// 1. The title, the dates, and the period.
/// 2. The pattern: one row per prayer, one column per day, with its key
///    and its counts in the same panel. Tap or drag across it to choose
///    a day.
/// 3. That day, in words, with the one-tap way to change it.
/// 4. What stands out in the period, and one thing to do about it.
/// 5. At most one offer, and the panels for anything already underway.
struct TrajectoryScreen: View {
    @Query(sort: \PrayerLog.prayerDate, order: .reverse)
    private var logs: [PrayerLog]

    @Query(sort: \PauseInterval.startDate, order: .reverse)
    private var pauses: [PauseInterval]

    @Query(sort: \TravelInterval.startDate, order: .reverse)
    private var travels: [TravelInterval]

    @Query private var settingsRows: [UserSettings]
    @Query(sort: \KhatamPlan.createdAt, order: .reverse)
    private var khatamPlans: [KhatamPlan]

    /// Whether the sunnah invitation has been answered. Presentation
    /// state, like the other one-time cards — never worship data.
    @AppStorage("IhsanSunnahCardDismissed")
    private var sunnahInviteDismissed: Bool = false

    /// How many distinct civil days carry a log. The invitation is for
    /// someone with a habit here, not for someone on their third day.
    private var distinctLoggedDayCount: Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return Set(logs.map { calendar.startOfDay(for: $0.prayerDate) }).count
    }

    /// Hands the person to Set when they say yes.
    var onOpenSunnahSettings: (() -> Void)?

    @Query(sort: \NaflLog.naflDate, order: .reverse)
    private var naflLogs: [NaflLog]
    @Query(sort: \DhikrSession.sessionDate)
    private var dhikrSessions: [DhikrSession]
    @Query(sort: \PeriodSummary.periodStart, order: .reverse)
    private var periodSummaries: [PeriodSummary]

    @State private var viewModel = TrajectoryViewModel()
    @State private var showingRepairSetup = false
    @State private var showingRepairDetail = DebugLaunch.flag("-IhsanDebugPresentRepair")
    @State private var showingKhatamSetup = DebugLaunch.flag("-IhsanDebugPresentKhatamSetup")
    @State private var showingKhatamDetail = false
    @AppStorage("IhsanKhatamOfferRamadanYear")
    private var khatamOfferRamadanYear: Int = 0
    /// The day the card shows. Nil follows the newest day, so the card
    /// is on today whenever a person hasn't asked for anything else, and
    /// stays on today when a new day begins.
    @State private var selectedDay: Date?
    /// The prayer whose seals are showing on the day card.
    @State private var openPrayer: Prayer?
    @State private var recordEditor = PathRecordEditor()
    /// Bumped to bring the day card into view.
    @State private var dayCardScrollRequest = 0
    @State private var insightText: String?
    @State private var isInsightLoading = false
    @State private var finding: PathFinding?
    @State private var findingGrounding = TrajectoryFindingFraming.standard(for: .steady)
    @State private var showingMasjidFinder = false
    @State private var actionConfirmation: String?
    @State private var confirmationDismissal: Task<Void, Never>?
    @State private var isRenderingPatternShare = false
    @State private var sharePreview: PatternSharePayload?
    @State private var shareRenderError = false
    @State private var fiqhInsight = TrajectoryInsightFraming(
        title: "How Ihsan records timing",
        body: "The five prayers have appointed times. In Ihsan, ‘On Time’ and ‘Delayed’ both describe a prayer performed within its valid window; ‘Delayed’ is a personal tracking distinction, not a separate legal ruling. A prayer performed after its window is recorded separately as qadāʾ.",
        citation: "Qur’an 4:103 · Ṣaḥīḥ al-Bukhārī 597 · Ṣaḥīḥ Muslim 684d"
    )

    @Environment(\.nowProvider) private var nowProvider
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var settings: UserSettings? {
        settingsRows.first
    }

    /// Change signature covering in-place edits — `logs.count` alone
    /// misses a retro edit that rewrites an existing row.
    private var logSignature: String {
        logs.map { "\($0.id.uuidString):\($0.modifiedAt.timeIntervalSince1970)" }
            .joined(separator: "|")
    }

    private var insightRequestID: String {
        let dhikrSignature = dhikrSessions.map {
            "\($0.id.uuidString):\($0.modifiedAt.timeIntervalSince1970)"
        }.joined(separator: "|")
        let stateSignature: String
        switch viewModel.state {
        case .loading: stateSignature = "loading"
        case .empty: stateSignature = "empty"
        case .ready(let snapshot):
            stateSignature = [
                snapshot.period.label,
                String(snapshot.aggregate.totalLogged),
                String(snapshot.aggregate.onTimeCount),
                String(snapshot.aggregate.lateCount),
                String(snapshot.aggregate.missedCount),
                String(snapshot.aggregate.qadaCount),
                String(snapshot.aggregate.jamaahCount)
            ].joined(separator: ":")
        }
        return [
            stateSignature,
            logSignature,
            dhikrSignature,
            String(settings?.aiInsightsEnabled ?? false),
            String(InsightAvailability.isAvailable)
        ].joined(separator: "#")
    }

    var body: some View {
        // The page's one clock: a single quiet timeline resolves the
        // moment through the injected provider; the tokens and the
        // ground follow it together. `timeOfDayOverride` pins the
        // shared page-chrome modifiers to the same instant.
        TimelineView(.periodic(from: .distantPast, by: 60)) { context in
            let now = nowProvider.resolve(context.date)
            let phase = IhsanPageChrome.phase(at: now)
            let tokens = PaletteState.resolved(for: phase)
            page(tokens: tokens)
                .environment(\.timeOfDayOverride, now)
        }
    }

    @ViewBuilder
    private func page(tokens: SkyPaletteTokens) -> some View {
        ScrollViewReader { reader in
            ScrollView {
                VStack(alignment: .leading, spacing: IhsanSpacing.md) {
                    header(tokens: tokens)
                        .padding(.horizontal, IhsanSpacing.md)

                    PeriodSelector(period: $viewModel.period, tokens: tokens)
                        .padding(.horizontal, IhsanSpacing.md)

                    content(tokens: tokens)

                    offer
                        .padding(.horizontal, IhsanSpacing.md)

                    if KhatamSurfaceModel.activePlan(in: khatamPlans) != nil {
                        KhatamSection(onOpen: { showingKhatamDetail = true })
                            .padding(.horizontal, IhsanSpacing.md)
                    }

                    if settings?.qadaTrackingEnabled == true {
                        RepairSection(onOpen: { showingRepairDetail = true })
                            .padding(.horizontal, IhsanSpacing.md)
                    }

                    Color.clear.frame(height: IhsanSpacing.xl)
                }
                .padding(.top, IhsanSpacing.md)
            }
            .onChange(of: dayCardScrollRequest) {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
                    reader.scrollTo(Self.dayCardID, anchor: .top)
                }
            }
        }
        .ihsanStatusBarEdge()
        .ihsanManuscriptPage()
        .onAppear {
            // The screen's clock is the injected provider — never the
            // wall clock — so the period window agrees with every
            // other surface about which day is "today".
            viewModel.nowProvider = nowProvider
            viewModel.refresh(
                logs: logs,
                pauseIntervals: pauses,
                travelIntervals: travels
            )
        }
        .onChange(of: logSignature) {
            viewModel.refresh(
                logs: logs,
                pauseIntervals: pauses,
                travelIntervals: travels
            )
        }
        .onChange(of: pauses.count) {
            viewModel.refresh(
                logs: logs,
                pauseIntervals: pauses,
                travelIntervals: travels
            )
        }
        .onChange(of: travels.count) {
            viewModel.refresh(
                logs: logs,
                pauseIntervals: pauses,
                travelIntervals: travels
            )
        }
        .onChange(of: viewModel.period) {
            openPrayer = nil
        }
        .onChange(of: scenePhase) {
            if scenePhase != .active { recordEditor.settle() }
        }
        .onDisappear {
            recordEditor.settle()
        }
        .task(id: insightRequestID) {
            await refreshInsight()
        }
        .task {
            if let trajectoryInsight = await currentFraming()?.trajectoryInsight {
                fiqhInsight = trajectoryInsight
            }
        }
        .task {
            guard DebugLaunch.flag("-IhsanDebugPresentKhatam") else { return }
            // Presentation state set before the host enters the hierarchy is
            // not reliably observed by SwiftUI. Yield one turn so evidence
            // launches exercise the same sheet path as a real card tap.
            await Task.yield()
            showingKhatamDetail = true
        }
        .sheet(isPresented: $showingMasjidFinder) {
            // Only the resolved city name travels here, never a
            // coordinate — the finder resolves its own location and
            // keeps it in that sheet's memory.
            MasjidFinderScreen(
                locationName: settings?.lastResolvedCityName ?? "Current Location"
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.thinMaterial)
            .preferredColorScheme(.dark)
        }
        .fullScreenCover(isPresented: $showingRepairSetup) {
            RepairSetupFlow()
                .preferredColorScheme(.dark)
        }
        .fullScreenCover(isPresented: $showingKhatamSetup) {
            KhatamSetupFlow(prefersRamadan: true)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showingRepairDetail) {
            RepairDetailScreen()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showingKhatamDetail) {
            KhatamDetailScreen()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .preferredColorScheme(.dark)
        }
        .sheet(item: $sharePreview) { payload in
            PatternSharePreviewSheet(payload: payload)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.thinMaterial)
                .preferredColorScheme(.dark)
        }
        .alert("The image could not be prepared", isPresented: $shareRenderError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Return to Path and try again.")
        }
    }

    // MARK: - The one offer

    /// Invitations wait until the person has seen their days, and speak
    /// one at a time. Two of them stacked at the top of the screen once
    /// pushed the pattern below the fold. Whichever is answered makes
    /// way for the next; Ramadan goes first because it will not wait.
    @ViewBuilder
    private var offer: some View {
        if shouldOfferRamadanKhatam {
            KhatamRamadanOfferCard(
                onBegin: {
                    khatamOfferRamadanYear = currentHijriYear
                    showingKhatamSetup = true
                },
                onDismiss: {
                    khatamOfferRamadanYear = currentHijriYear
                }
            )
        } else if let settings, !settings.qadaTrackingEnabled, !settings.qadaPathCardDismissed {
            RepairInviteCard(
                onBegin: { showingRepairSetup = true },
                onDismiss: {
                    settings.qadaPathCardDismissed = true
                    settings.modifiedAt = .now
                }
            )
        } else if let settings, SunnahInvite.shouldOffer(
            // The sunnah layer is invisible until turned on, which is
            // right and also means nobody finds it. This is the one time
            // the app mentions it — after a fortnight, and never again
            // after either answer.
            distinctLoggedDays: DebugLaunch.flag("-IhsanDebugSunnahInvite")
                ? SunnahInvite.requiredDays
                : distinctLoggedDayCount,
            sunnahLayerEnabled: settings.sunnahLayerEnabled,
            hasBeenDismissed: sunnahInviteDismissed
        ) {
            SunnahInviteCard(
                onShow: {
                    sunnahInviteDismissed = true
                    onOpenSunnahSettings?()
                },
                onDismiss: { sunnahInviteDismissed = true }
            )
        }
    }

    private var currentHijriYear: Int {
        HijriConverter.components(
            for: nowProvider.now(),
            offsetDays: settings?.hijriCalendarOffsetDays ?? 0,
            timeZone: .current
        ).year
    }

    private var shouldOfferRamadanKhatam: Bool {
        KhatamSurfaceModel.activePlan(in: khatamPlans) == nil
            && RamadanContext(
                at: nowProvider.now(),
                offsetDays: settings?.hijriCalendarOffsetDays ?? 0
            ).isCurrentlyRamadan
            && khatamOfferRamadanYear != currentHijriYear
    }

    // MARK: - Header

    @ViewBuilder
    private func header(tokens: SkyPaletteTokens) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: IhsanSpacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Path")
                        .font(.system(size: 32, weight: .medium, design: .serif))
                        .foregroundStyle(tokens.ink)

                    Text(subtitleText)
                        .font(.footnote)
                        .foregroundStyle(tokens.inkSecondary)
                }

                Spacer(minLength: IhsanSpacing.sm)

                if case .ready = viewModel.state {
                    Button {
                        beginPatternShare(tokens: tokens)
                    } label: {
                        Group {
                            if isRenderingPatternShare {
                                ProgressView()
                                    .tint(tokens.metal)
                            } else {
                                SettingsGlyphView(.share, color: tokens.metal)
                            }
                        }
                        .frame(width: IhsanSpacing.lg, height: IhsanSpacing.lg)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isRenderingPatternShare)
                    .accessibilityLabel(
                        isRenderingPatternShare
                            ? "Preparing pattern image"
                            : "Share the current pattern"
                    )
                    .accessibilityHint("Opens a preview before the system share sheet")
                }
            }

        }
    }

    private func beginPatternShare(tokens: SkyPaletteTokens) {
        guard case .ready(let snapshot) = viewModel.state,
              !isRenderingPatternShare else { return }

        Haptics.impact(.light)
        isRenderingPatternShare = true
        let exportContent = PatternExportPrivacy.prepare(
            days: snapshot.days,
            naflDays: overlayNaflDays,
            dhikrDays: overlayDhikrDays,
            recordBegan: recordBegan
        )

        Task { @MainActor in
            await Task.yield()
            let payload = PatternShareRenderer.render(
                content: exportContent,
                period: snapshot.period,
                tokens: tokens,
                reduceTransparency: reduceTransparency
            )
            isRenderingPatternShare = false
            if let payload {
                sharePreview = payload
            } else {
                shareRenderError = true
            }
        }
    }

    /// The dates the period covers, which the selector's "30 days"
    /// doesn't say.
    private var subtitleText: String {
        viewModel.period.formattedRange(
            cycleDate: PrayerCycleClock.sharedCycleDate(at: nowProvider.now())
        )
    }

    /// The day of the earliest record. Days before it aren't gaps; they
    /// are days before this person began. `logs` is newest-first.
    private var recordBegan: Date? {
        logs.last.map { Calendar.current.startOfDay(for: $0.prayerDate) }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(tokens: SkyPaletteTokens) -> some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .tint(tokens.inkSecondary)
                .frame(maxWidth: .infinity)
                .padding(.top, IhsanSpacing.xxl)

        case .empty:
            TrajectoryEmptyState(tokens: tokens)
                .padding(.top, IhsanSpacing.xxl)

        case .ready(let snapshot):
            let days = recordEditor.applying(to: snapshot.days)
            let selected = selectedDayCompletion(in: days)

            VStack(spacing: IhsanSpacing.md) {
                patternPanel(
                    days: days,
                    selected: selected,
                    period: snapshot.period,
                    tokens: tokens
                )
                .padding(.horizontal, IhsanSpacing.md)

                if let selected {
                    dayCard(for: selected, in: days, tokens: tokens)
                        .id(Self.dayCardID)
                        .padding(.horizontal, IhsanSpacing.md)
                }

                if isInsightLoading || insightText != nil || finding != nil {
                    TrajectoryInsightCard(
                        finding: finding,
                        text: insightText,
                        isLoading: isInsightLoading,
                        grounding: findingGrounding,
                        ledger: fiqhInsight,
                        confirmation: actionConfirmation,
                        tokens: tokens,
                        onAct: act(on:)
                    )
                    .padding(.horizontal, IhsanSpacing.md)
                    .transition(.opacity)
                }
            }
        }
    }

    private static let dayCardID = "path-day-card"

    /// The pattern and its key, in one panel: a mark and the word for it
    /// should never be a scroll apart.
    private func patternPanel(
        days: [DayCompletion],
        selected: DayCompletion?,
        period: TrajectoryPeriod,
        tokens: SkyPaletteTokens
    ) -> some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.md) {
            GestaltGrid(
                days: days,
                period: period,
                tokens: tokens,
                naflDays: overlayNaflDays,
                dhikrDays: overlayDhikrDays,
                recordBegan: recordBegan,
                selectedColumn: selected.flatMap {
                    GestaltAggregation.column(for: $0.date, days: days, period: period)
                },
                selectionSummary: selected.map(spokenSummary(of:)),
                onSelectColumn: { column in
                    selectColumn(column, days: days, period: period)
                },
                onStepDay: { step in
                    stepDay(by: step, days: days)
                }
            )

            PathKey(
                tally: PathTally(days: days, recordBegan: recordBegan),
                period: period,
                tokens: tokens
            )
        }
        .padding(IhsanSpacing.md)
        .frame(maxWidth: .infinity)
        .celestialPanel(tokens: tokens, cornerRadius: 18)
    }

    private func dayCard(
        for day: DayCompletion,
        in days: [DayCompletion],
        tokens: SkyPaletteTokens
    ) -> some View {
        PathDayCard(
            day: day,
            isToday: day.date == days.last?.date,
            countsBlanks: PathTally.isCounted(
                dayDate: day.date,
                newestDay: days.last?.date,
                recordBegan: recordBegan
            ),
            canStepBack: day.date != days.first?.date,
            canStepForward: day.date != days.last?.date,
            voluntary: voluntaryDetail[day.date],
            tokens: tokens,
            editor: recordEditor,
            openPrayer: $openPrayer,
            isRemovalRefused: { isRepaired($0, on: day.date) },
            onStep: { stepDay(by: $0, days: days) }
        )
    }

    // MARK: - Choosing a day

    private func selectedDayCompletion(in days: [DayCompletion]) -> DayCompletion? {
        guard let selectedDay else { return days.last }
        return days.first { $0.date == selectedDay } ?? days.last
    }

    private func selectColumn(_ column: Int, days: [DayCompletion], period: TrajectoryPeriod) {
        guard let date = GestaltAggregation.day(forColumn: column, days: days, period: period),
              date != selectedDayCompletion(in: days)?.date
        else { return }
        Haptics.tap()
        select(date, days: days)
    }

    private func stepDay(by step: Int, days: [DayCompletion]) {
        guard let current = selectedDayCompletion(in: days),
              let index = days.firstIndex(where: { $0.date == current.date }),
              days.indices.contains(index + step)
        else { return }
        select(days[index + step].date, days: days)
    }

    private func select(_ date: Date, days: [DayCompletion]) {
        recordEditor.settle()
        openPrayer = nil
        selectedDay = date == days.last?.date ? nil : date
    }

    /// The selected day read aloud, for the grid's value.
    private func spokenSummary(of day: DayCompletion) -> String {
        let date = day.date.formatted(.dateTime.weekday(.wide).month(.wide).day())
        if day.isPaused { return "\(date), paused, not counted" }
        let prayers = day.prayerCompletions.map { completion in
            let state = completion.status?.spokenLabel ?? "no record"
            return "\(completion.prayer.displayNameEnglish) \(state)"
        }
        return ([date] + prayers).joined(separator: ", ")
    }

    /// Whether a make-up points at this prayer's record for this day.
    /// `RemovePrayerLogIntent` refuses such a removal, so the card
    /// doesn't offer one it would only have to take back.
    private func isRepaired(_ prayer: Prayer, on day: Date) -> Bool {
        let repaired = Set(logs.compactMap(\.qadaForPrayerLogID))
        guard !repaired.isEmpty else { return false }
        let calendar = Calendar.current
        return logs.contains { log in
            log.prayer == prayer
                && log.qadaForPrayerLogID == nil
                && calendar.isDate(log.prayerDate, inSameDayAs: day)
                && repaired.contains(log.id)
        }
    }

    // MARK: - Presence overlays
    //
    // There is no switch for these, and there was one until it was
    // taken out. Two chips sat above the panel toggling `Set<Date>?`
    // into and out of the grid; with no nafl or dhikr recorded — which
    // is every new account, and most accounts — pressing either one
    // changed nothing anybody could see. A control that cannot
    // demonstrate its own effect teaches nothing and asks the user to
    // trust that something happened.
    //
    // The rows now follow the data: the screen hands over what it has,
    // and `GestaltGrid` draws and names a row only when it has marks.

    /// What each cycle holds beyond its five fardh, for the day card.
    /// The pattern says a day carried voluntary worship; this says what,
    /// for the one day a person chooses.
    private var voluntaryDetail: [Date: DayVoluntaryDetail] {
        DayVoluntaryDetail.index(
            naflLogs: settings?.sunnahLayerEnabled == true ? naflLogs : [],
            dhikrSessions: dhikrSessions,
            calendar: .current
        )
    }

    /// Days with any voluntary record. Presence only — the overlay
    /// never carries a count or a share. `nil` while the sunnah layer
    /// is off, because nothing in the app records nafl until it is on.
    private var overlayNaflDays: Set<Date>? {
        guard settings?.sunnahLayerEnabled == true else { return nil }
        let calendar = Calendar.current
        return Set(naflLogs.map { calendar.startOfDay(for: $0.naflDate) })
    }

    /// Days with a recorded tasbīḥ sitting. Presence only — factual, no
    /// goal, no figure. The tasbīḥ instrument needs no opt-in, so this
    /// is never gated.
    private var overlayDhikrDays: Set<Date>? {
        let calendar = Calendar.current
        return Set(dhikrSessions.map { calendar.startOfDay(for: $0.sessionDate) })
    }

    // MARK: - The finding's one action

    /// Every prayer's reminder as the user actually experiences it: a
    /// per-prayer toggle under a global switch counts as off when the
    /// global switch is off.
    private var reminderSettings: [PathReminderSetting] {
        guard let settings else {
            return Prayer.allCases.map { PathReminderSetting(prayer: $0, isEnabled: false) }
        }
        return Prayer.allCases.map { prayer in
            PathReminderSetting(
                prayer: prayer,
                isEnabled: settings.notificationsEnabled && settings.notificationEnabled(for: prayer)
            )
        }
    }

    private func currentFraming() async -> FiqhFraming? {
        try? await FiqhConfigService.shared.currentConfig().framing
    }

    private func act(on action: PathFindingAction) {
        switch action {
        case .logSlot(let day, let prayer):
            // Straight to the empty prayer, with its seals already open.
            recordEditor.settle()
            selectedDay = day
            openPrayer = prayer
            dayCardScrollRequest += 1

        case .openMakeupLedger:
            // Repair has to exist before it can be opened. Somebody
            // who never set qadāʾ tracking up gets the setup flow, which
            // is the same door from the invite card above.
            if settings?.qadaTrackingEnabled == true {
                showingRepairDetail = true
            } else {
                showingRepairSetup = true
            }

        case .enableReminder(let prayer):
            guard let settings else { return }
            settings.notificationsEnabled = true
            settings.setNotificationEnabled(true, for: prayer)
            settings.modifiedAt = .now
            Task {
                // Authorization may never have been asked for, and the
                // toggle means nothing until it is. The card reports
                // what actually happened rather than claiming a
                // reminder that iOS will never deliver — the button
                // itself is about to change to the next rung, so
                // without this there is no evidence either way.
                let granted = (try? await NotificationScheduler.shared.requestAuthorization()) ?? false
                if granted {
                    try? await NotificationScheduler.shared.rebuildSchedule()
                    confirm("\(prayer.displayNameEnglish) reminder is on.")
                } else {
                    confirm("Allow notifications in iOS Settings to receive it.")
                }
                // The reminder state feeds the next reading.
                await refreshInsight()
            }

        case .findCongregation:
            showingMasjidFinder = true
        }
    }

    /// A short-lived receipt for the one action that changes something
    /// without opening a sheet. The other three are their own evidence.
    private func confirm(_ message: String) {
        actionConfirmation = message
        confirmationDismissal?.cancel()
        confirmationDismissal = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            actionConfirmation = nil
        }
    }

    // MARK: - On-device insight

    /// A useful deterministic readout is always available when insights
    /// are enabled. Foundation Models may refine the observation for a
    /// supported week or month, but never owns the card's availability.
    private func refreshInsight() async {
        insightText = nil
        isInsightLoading = false
        finding = nil

        guard case .ready(let snapshot) = viewModel.state else { return }

        // The finding is the card's point, so it is derived first and
        // from the ledger alone. It does not wait on Foundation Models,
        // does not depend on the insights toggle, and is identical on a
        // device where Apple Intelligence never becomes available.
        //
        // "Now" here is the cycle in progress, like the grid's newest
        // column: at 2 AM the evening's blanks are not yet gaps.
        let cycleNow = PrayerCycleClock.sharedCycleDate(at: nowProvider.now())
        let resolved = PathFinding.make(
            days: snapshot.days,
            aggregate: snapshot.aggregate,
            logs: logs,
            reminders: reminderSettings,
            now: cycleNow,
            recordBegan: recordBegan,
            calendar: .current
        )
        // Both halves of the card land in the same frame, with the
        // shipped grounding already matched to the reading. Awaiting
        // the config first would put a reading and last reading's
        // citation on screen together for as long as the load takes.
        finding = resolved
        findingGrounding = .standard(for: resolved.kind)
        let narrative = TrajectoryInsightNarrative.make(
            days: snapshot.days,
            aggregate: snapshot.aggregate,
            now: cycleNow,
            recordBegan: recordBegan,
            calendar: .current
        )
        insightText = narrative.isEmpty ? nil : narrative

        if let configured = await currentFraming()?.findingFraming(for: resolved.kind) {
            findingGrounding = configured
        }

        #if DEBUG
        // `-IhsanDebugInsight` makes the real presentation surface
        // inspectable on Simulator, where Foundation Models is
        // intentionally unavailable. It never bypasses the production
        // availability or privacy gates.
        if DebugLaunch.flag("-IhsanDebugInsight") {
            insightText = "Fajr and Maghrib were the most consistent points in this period, while the middle of the day varied more."
            return
        }
        #endif

        guard settings?.aiInsightsEnabled == true,
              InsightAvailability.isAvailable,
              let materialized = TrajectoryInsightMaterializer.makeSummary(
                  snapshot: snapshot,
                  dhikrSessions: dhikrSessions,
                  calendar: .current,
                  now: nowProvider.now()
              ),
              let kind = materialized.periodKind
        else { return }

        isInsightLoading = true
        defer { isInsightLoading = false }

        let summary: PeriodSummary
        if let existing = periodSummaries.first(where: { $0.periodKind == kind }) {
            TrajectoryInsightMaterializer.refresh(
                existing,
                from: materialized,
                now: nowProvider.now()
            )
            summary = existing
        } else {
            modelContext.insert(materialized)
            summary = materialized
        }

        do {
            try modelContext.save()
            let generated: String
            switch kind {
            case .week:
                generated = try await InsightGenerator.shared
                    .generateWeeklyInsight(from: summary)
                    .summarySentence
            case .month:
                generated = try await InsightGenerator.shared
                    .generateMonthlyInsight(from: summary)
                    .summarySentence
            }
            if TrajectoryInsightNarrative.isUsefulGeneratedObservation(generated) {
                insightText = [insightText, generated].compactMap(\.self).joined(separator: " ")
            }
            try modelContext.save()
        } catch {
            // Availability can change while a request is in flight
            // (model download, language, Low Power Mode). The Path
            // remains complete without an error or an upgrade prompt.
            // Keep the deterministic readout already on screen.
        }
    }
}

#Preview {
    TrajectoryScreen()
        .modelContainer(
            for: [PrayerLog.self, PauseInterval.self, TravelInterval.self],
            inMemory: true
        )
}
