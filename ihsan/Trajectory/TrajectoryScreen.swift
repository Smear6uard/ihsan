import SwiftUI
import SwiftData
import IhsanCore
import IhsanDesignSystem
import IhsanIntents

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
///    LATE · N, MISSED · N, QADĀ · N). Replaces the previous giant
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

    @State private var viewModel = TrajectoryViewModel()
    @State private var showingRepairSetup = false
    @State private var showingRepairDetail = DebugLaunch.flag("-IhsanDebugPresentRepair")
    /// A grid cell awaiting the retroactive log sheet.
    @State private var retroSelection: RetroLogSelection?

    @Environment(\.nowProvider) private var nowProvider

    private var settings: UserSettings? {
        settingsRows.first
    }

    /// Change signature covering in-place edits — `logs.count` alone
    /// misses a retro edit that rewrites an existing row.
    private var logSignature: String {
        logs.map { "\($0.id.uuidString):\($0.modifiedAt.timeIntervalSince1970)" }
            .joined(separator: "|")
    }

    var body: some View {
        // The page's one clock: a single quiet timeline resolves the
        // moment through the injected provider; the tokens and the
        // ground follow it together. `timeOfDayOverride` pins the
        // shared page-chrome modifiers to the same instant.
        TimelineView(.periodic(from: .distantPast, by: 60)) { context in
            let now = nowProvider.resolve(context.date)
            let tokens = IhsanPageChrome.tokens(at: now)
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
        .sheet(item: $retroSelection) { selection in
            retroLogSheet(for: selection)
        }
        .fullScreenCover(isPresented: $showingRepairSetup) {
            RepairSetupFlow()
        }
        .sheet(isPresented: $showingRepairDetail) {
            RepairDetailScreen()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func header(tokens: SkyPaletteTokens) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("A pattern of days")
                .font(.system(size: 32, weight: .medium, design: .serif))
                .foregroundStyle(tokens.ink)

            Text(subtitleText)
                .font(IhsanFont.inscription)
                .tracking(1.8)
                .foregroundStyle(tokens.inkSecondary)

            OrnamentalDivider(tint: tokens.metal, opacity: 0.5)
                .padding(.top, IhsanSpacing.xs)
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
