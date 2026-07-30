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

    @Query(sort: \NaflLog.naflDate, order: .reverse)
    private var naflLogs: [NaflLog]

    @State private var viewModel = TrajectoryViewModel()
    @State private var selectedDay: DayCompletion?
    @State private var showingRepairSetup = false
    @State private var showingRepairDetail = false
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
        .sheet(item: $selectedDay) { day in
            HeatmapDayPopover(day: day)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(.thinMaterial)
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
                if settings?.sunnahLayerEnabled == true {
                    HStack {
                        Spacer()
                        naflOverlayToggle(tokens: tokens)
                    }
                    .padding(.horizontal, IhsanSpacing.md)
                }

                gestaltPanel(snapshot: snapshot, tokens: tokens)
                    .padding(.horizontal, IhsanSpacing.md)

                QuietSummaryRow(aggregate: snapshot.aggregate, tokens: tokens)
                    .padding(.horizontal, IhsanSpacing.md)

                DailyPracticeGrid(
                    days: snapshot.days,
                    tokens: tokens,
                    onDayTap: { day in
                        selectedDay = day
                    },
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
            naflDays: overlayNaflDays
        )
        .padding(IhsanSpacing.lg)
        .frame(maxWidth: .infinity)
        .celestialPanel(tokens: tokens, cornerRadius: 18)
    }

    // MARK: - Nafl overlay

    /// Days with any voluntary record, when the overlay is on. Presence
    /// only — the overlay never carries a count or a share.
    private var overlayNaflDays: Set<Date>? {
        guard let settings,
              settings.sunnahLayerEnabled,
              settings.pathNaflOverlayEnabled
        else { return nil }
        let calendar = Calendar.current
        return Set(naflLogs.map { calendar.startOfDay(for: $0.naflDate) })
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
                now: now,
                dayBeingLogged: selection.day,
                scheduledTime: nil,
                windowEndTime: nil,
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

    /// The quiet in-Path switch for the overlay: a small outlined chip,
    /// filled while the sixth row shows. Visible only when the sunnah
    /// layer itself is on.
    private func naflOverlayToggle(tokens: SkyPaletteTokens) -> some View {
        let isOn = settings?.pathNaflOverlayEnabled == true
        return Button {
            Haptics.impact(.light)
            settings?.pathNaflOverlayEnabled.toggle()
            settings?.modifiedAt = .now
        } label: {
            HStack(spacing: 5) {
                FourPointedStar()
                    .stroke(tokens.metal.opacity(isOn ? 0.9 : 0.5), lineWidth: 0.9)
                    .frame(width: 9, height: 9)
                Text("NAFL")
                    .font(IhsanFont.inscription)
                    .tracking(1.6)
                    .foregroundStyle(isOn ? tokens.ink : tokens.inkSecondary.opacity(0.8))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .overlay {
                Capsule()
                    .strokeBorder(tokens.metal.opacity(isOn ? 0.6 : 0.3), lineWidth: 0.8)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Voluntary prayer overlay")
        .accessibilityValue(isOn ? "on" : "off")
        .accessibilityHint("Adds a quieter sixth row to the pattern.")
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
