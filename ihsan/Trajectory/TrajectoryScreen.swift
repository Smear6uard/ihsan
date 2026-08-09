import SwiftUI
import SwiftData
import IhsanCore
import IhsanDesignSystem
import IhsanFiqhConfig
import IhsanInsights
import IhsanIntents
import IhsanNotifications

/// The Trajectory tab.
///
/// Reads `PrayerLog`, `PauseInterval`, and `TravelInterval` directly
/// from SwiftData via `@Query`, hands them to a `TrajectoryViewModel`
/// for aggregation, and presents — top to bottom:
///
/// 1. A manuscript-style page header ("A pattern of days") with the
///    period inscription as subtitle.
/// 2. The 7D / 30D / 90D / YEAR range selector pill.
/// 3. The gestalt dot pattern — a single illuminated panel containing a
///    5×N matrix of small dots, one row per prayer, one column per day
///    (or per week in YEAR mode). The visual heart of the screen — the
///    user reads their pattern at a glance before any number is shown.
/// 4. A quiet inscriptional row of counts (ON TIME · N, JAMAʿAH · N,
///    DELAYED · N, MISSED · N, QADĀ · N). Replaces the previous giant
///    "% on-time" panel.
/// 5. The day-by-day detail grid — same five-prayer × N-day matrix as
///    before, scaled down so the gestalt above is the headline and this
///    is the drill-down.
struct TrajectoryScreen: View {
    @Query(sort: \PrayerLog.prayerDate, order: .reverse)
    private var logs: [PrayerLog]

    @Query(sort: \PauseInterval.startDate, order: .reverse)
    private var pauses: [PauseInterval]

    @Query(sort: \TravelInterval.startDate, order: .reverse)
    private var travels: [TravelInterval]

    @Query private var settingsRows: [UserSettings]

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
    /// A grid cell awaiting the retroactive log sheet.
    @State private var retroSelection: RetroLogSelection?
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
        title: "How this ledger uses timing",
        body: "The five prayers have appointed times. In Ihsan, ‘On Time’ and ‘Delayed’ both describe a prayer performed within its valid window; ‘Delayed’ is a personal tracking distinction, not a separate legal ruling. A prayer performed after its window is recorded separately as qadāʾ.",
        citation: "Qur’an 4:103 · Ṣaḥīḥ al-Bukhārī 597 · Ṣaḥīḥ Muslim 684d"
    )

    @Environment(\.nowProvider) private var nowProvider
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

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
        ScrollView {
            VStack(alignment: .leading, spacing: IhsanSpacing.lg) {
                header(tokens: tokens)
                    .padding(.horizontal, IhsanSpacing.md)

                PeriodSelector(period: $viewModel.period, tokens: tokens)
                    .padding(.horizontal, IhsanSpacing.md)

                if let settings, !settings.qadaTrackingEnabled, !settings.qadaPathCardDismissed {
                    RepairInviteCard(
                        onBegin: { showingRepairSetup = true },
                        onDismiss: {
                            settings.qadaPathCardDismissed = true
                            settings.modifiedAt = .now
                        }
                    )
                    .padding(.horizontal, IhsanSpacing.md)
                }

                // The sunnah layer is invisible until turned on, which
                // is right and also means nobody finds it. This is the
                // one time the app mentions it — after a fortnight, and
                // never again after either answer.
                if let settings, SunnahInvite.shouldOffer(
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
                    .padding(.horizontal, IhsanSpacing.md)
                }

                content(tokens: tokens)

                if settings?.qadaTrackingEnabled == true {
                    RepairSection(onOpen: { showingRepairDetail = true })
                        .padding(.horizontal, IhsanSpacing.md)
                }

                Color.clear.frame(height: IhsanSpacing.xl)
            }
            .padding(.top, IhsanSpacing.md)
        }
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
        .task(id: insightRequestID) {
            await refreshInsight()
        }
        .task {
            if let trajectoryInsight = await currentFraming()?.trajectoryInsight {
                fiqhInsight = trajectoryInsight
            }
        }
        .sheet(item: $retroSelection) { selection in
            retroLogSheet(for: selection)
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
        }
        .fullScreenCover(isPresented: $showingRepairSetup) {
            RepairSetupFlow()
        }
        .sheet(isPresented: $showingRepairDetail) {
            RepairDetailScreen()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $sharePreview) { payload in
            PatternSharePreviewSheet(payload: payload)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.thinMaterial)
        }
        .alert("The image could not be prepared", isPresented: $shareRenderError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Return to Path and try again.")
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func header(tokens: SkyPaletteTokens) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: IhsanSpacing.md) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("A pattern of days")
                        .font(.system(size: 32, weight: .medium, design: .serif))
                        .foregroundStyle(tokens.ink)

                    Text(subtitleText)
                        .font(IhsanFont.inscription)
                        .tracking(1.8)
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

            OrnamentalDivider(tint: tokens.metal, opacity: 0.5)
                .padding(.top, IhsanSpacing.xs)
        }
    }

    private func beginPatternShare(tokens: SkyPaletteTokens) {
        guard case .ready(let snapshot) = viewModel.state,
              !isRenderingPatternShare else { return }

        Haptics.impact(.light)
        isRenderingPatternShare = true
        let exportContent = PatternExportPrivacy.prepare(
            days: snapshot.days,
            aggregate: snapshot.aggregate,
            naflDays: overlayNaflDays,
            dhikrDays: overlayDhikrDays
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

    private var subtitleText: String {
        let periodCaption: String
        switch viewModel.period {
        case .sevenDays: periodCaption = "SEVEN DAYS"
        case .thirtyDays: periodCaption = "THIRTY DAYS"
        case .ninetyDays: periodCaption = "NINETY DAYS"
        case .year: periodCaption = "ONE YEAR"
        }
        return "TRAJECTORY · \(periodCaption)"
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
            VStack(spacing: IhsanSpacing.lg) {
                gestaltPanel(snapshot: snapshot, tokens: tokens)
                    .padding(.horizontal, IhsanSpacing.md)

                QuietSummaryRow(aggregate: snapshot.aggregate, tokens: tokens)
                    .padding(.horizontal, IhsanSpacing.md)

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

                DailyPracticeGrid(
                    days: snapshot.days,
                    tokens: tokens,
                    voluntary: voluntaryDetail,
                    onCellTap: { day, completion in
                        retroSelection = RetroLogSelection(
                            day: day.date,
                            prayer: completion.prayer,
                            currentStatus: completion.status,
                            isJamaah: completion.withJamaah
                        )
                    }
                )
                .padding(.horizontal, IhsanSpacing.md)
            }
        }
    }

    /// The gestalt-pattern panel — the visual headline of the screen.
    /// Wrapped here (rather than inside `GestaltGrid`) so the panel
    /// padding stays in lockstep with the other illuminated panels on
    /// the page.
    @ViewBuilder
    private func gestaltPanel(
        snapshot: TrajectoryState.Snapshot, tokens: SkyPaletteTokens
    ) -> some View {
        GestaltGrid(
            days: snapshot.days,
            period: snapshot.period,
            tokens: tokens,
            naflDays: overlayNaflDays,
            dhikrDays: overlayDhikrDays
        )
        .padding(IhsanSpacing.lg)
        .frame(maxWidth: .infinity)
        .celestialPanel(tokens: tokens, cornerRadius: 18)
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
    // `GestaltGrid` draws a row only when that row has marks in it, and
    // a key underneath names each one.

    /// What each cycle holds beyond its five fardh, for the table's
    /// day detail. The pattern card says a day carried voluntary
    /// worship; this says what, for the one day a person taps.
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
            retroSelection = RetroLogSelection(
                day: day,
                prayer: prayer,
                currentStatus: nil,
                isJamaah: false
            )

        case .openMakeupLedger:
            // The ledger has to exist before it can be opened. Somebody
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
        let resolved = PathFinding.make(
            days: snapshot.days,
            aggregate: snapshot.aggregate,
            logs: logs,
            reminders: reminderSettings,
            now: nowProvider.now(),
            calendar: .current
        )
        // Both halves of the card land in the same frame, with the
        // shipped grounding already matched to the reading. Awaiting
        // the config first would put a reading and last reading's
        // citation on screen together for as long as the load takes.
        finding = resolved
        findingGrounding = .standard(for: resolved.kind)
        insightText = TrajectoryInsightNarrative.make(
            days: snapshot.days,
            aggregate: snapshot.aggregate,
            now: nowProvider.now(),
            calendar: .current
        )

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
            if TrajectoryInsightNarrative.isUsefulGeneratedObservation(generated),
               let exactReadout = insightText {
                insightText = exactReadout + " " + generated
            }
            try modelContext.save()
        } catch {
            // Availability can change while a request is in flight
            // (model download, language, Low Power Mode). The Path
            // remains complete without an error or an upgrade prompt.
            // Keep the deterministic readout already on screen.
        }
    }

    // MARK: - Retroactive logging (the ledger's way in)

    /// The log sheet for a tapped grid cell. Prior days open with all
    /// four tiles active (the past-day rule); today's cells defer to
    /// the availability rule. The sheet inscribes the day instead of
    /// clock times — a past day has no window to describe.
    @ViewBuilder
    private func retroLogSheet(for selection: RetroLogSelection) -> some View {
        let now = nowProvider.now()
        let tokens = PaletteState.resolved(
            for: SkyPhase.approximate(at: now, timeZone: .current)
        )
        PrayerLogSheet(
            prayer: selection.prayer,
            scheduledTime: selection.day,
            windowEndTime: nil,
            timeZone: .current,
            tokens: tokens,
            currentStatus: selection.currentStatus,
            isJamaah: selection.isJamaah,
            availableStatuses: TimingAvailability.allowedStatuses(
                cycleDate: PrayerCycleClock.sharedCycleDate(at: now),
                dayBeingLogged: selection.day,
                windowState: nil,
                currentStatus: selection.currentStatus
            ),
            displayDate: selection.day,
            onCommit: { status, jamaah in
                commitRetro(selection: selection, status: status, jamaah: jamaah)
            },
            onCancel: {}
        )
    }

    /// The same single funnel every surface uses — the intents —
    /// with the cell's civil day attached. Dedup holds per
    /// (prayer, day); an edit rewrites in place.
    private func commitRetro(
        selection: RetroLogSelection, status: PrayerStatus, jamaah: Bool
    ) {
        Task {
            _ = try? await LogPrayerWithStatusIntent(
                prayer: selection.prayer, status: status, date: selection.day
            ).perform()
            if jamaah != selection.isJamaah {
                _ = try? await ToggleJamaahIntent(
                    prayer: selection.prayer, date: selection.day
                ).perform()
            }
        }
    }

}

/// Identifies the grid cell whose log sheet is presented.
private struct RetroLogSelection: Identifiable, Hashable {
    let day: Date
    let prayer: Prayer
    let currentStatus: PrayerStatus?
    let isJamaah: Bool
    var id: String { "\(prayer.rawValue)-\(day.timeIntervalSinceReferenceDate)" }
}

#Preview {
    TrajectoryScreen()
        .modelContainer(
            for: [PrayerLog.self, PauseInterval.self, TravelInterval.self],
            inMemory: true
        )
}
