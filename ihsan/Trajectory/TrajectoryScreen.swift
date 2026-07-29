import SwiftUI
import SwiftData
import IhsanCore
import IhsanDesignSystem

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

    @State private var viewModel = TrajectoryViewModel()
    @State private var selectedDay: DayCompletion?
    @State private var showingRepairSetup = false

    private var settings: UserSettings? {
        settingsRows.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: IhsanSpacing.lg) {
                header
                    .padding(.horizontal, IhsanSpacing.md)

                PeriodSelector(period: $viewModel.period)
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

                content

                Color.clear.frame(height: IhsanSpacing.xl)
            }
            .padding(.top, IhsanSpacing.md)
        }
        .ihsanManuscriptPage()
        .onAppear {
            viewModel.refresh(
                logs: logs,
                pauseIntervals: pauses,
                travelIntervals: travels
            )
        }
        .onChange(of: logs.count) {
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
        .fullScreenCover(isPresented: $showingRepairSetup) {
            RepairSetupFlow()
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("A pattern of days")
                .font(.system(size: 32, weight: .medium, design: .serif))
                .foregroundStyle(IhsanColor.skyForegroundPrimary())

            Text(subtitleText)
                .font(IhsanFont.inscription)
                .tracking(1.8)
                .foregroundStyle(IhsanColor.brass)

            OrnamentalDivider()
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
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .tint(IhsanColor.brass)
                .frame(maxWidth: .infinity)
                .padding(.top, IhsanSpacing.xxl)

        case .empty:
            TrajectoryEmptyState()
                .padding(.top, IhsanSpacing.xxl)

        case .ready(let snapshot):
            VStack(spacing: IhsanSpacing.lg) {
                gestaltPanel(snapshot: snapshot)
                    .padding(.horizontal, IhsanSpacing.md)

                QuietSummaryRow(aggregate: snapshot.aggregate)
                    .padding(.horizontal, IhsanSpacing.md)

                DailyPracticeGrid(
                    days: snapshot.days,
                    onDayTap: { day in
                        selectedDay = day
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
    private func gestaltPanel(snapshot: TrajectoryState.Snapshot) -> some View {
        GestaltGrid(days: snapshot.days, period: snapshot.period)
            .padding(IhsanSpacing.lg)
            .frame(maxWidth: .infinity)
            .ihsanIlluminatedPanel(intensity: .regular)
    }
}

#Preview {
    TrajectoryScreen()
        .modelContainer(
            for: [PrayerLog.self, PauseInterval.self, TravelInterval.self],
            inMemory: true
        )
}
