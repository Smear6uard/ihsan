import SwiftUI
import SwiftData
import IhsanCore
import IhsanDesignSystem

/// The Trajectory tab.
///
/// Reads `PrayerLog`, `PauseInterval`, and `TravelInterval` directly
/// from SwiftData via `@Query`, hands them to a `TrajectoryViewModel`
/// for aggregation, and presents:
///
/// - A manuscript-style page header ("A pattern of days") with the
///   period inscription as subtitle.
/// - The summary stats panel (overall on-time %, jamaʿah count, and
///   secondary on-time / missed / qadā tallies).
/// - The Daily Practice grid — five-prayer × N-day matrix of
///   illuminated cells, the central visualization of the screen.
/// - A small legend strip decoding the cell types.
/// - Per-prayer aggregate rows beneath the grid for users who want
///   to see one prayer's pattern at a glance.
/// - Optional Apple Intelligence insight card.
struct TrajectoryScreen: View {
    @Query(sort: \PrayerLog.prayerDate, order: .reverse)
    private var logs: [PrayerLog]

    @Query(sort: \PauseInterval.startDate, order: .reverse)
    private var pauses: [PauseInterval]

    @Query(sort: \TravelInterval.startDate, order: .reverse)
    private var travels: [TravelInterval]

    @State private var viewModel = TrajectoryViewModel()
    @State private var selectedDay: DayCompletion?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: IhsanSpacing.lg) {
                header
                    .padding(.horizontal, IhsanSpacing.md)

                PeriodSelector(period: $viewModel.period)
                    .padding(.horizontal, IhsanSpacing.md)

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
                SummaryStatsPanel(aggregate: snapshot.aggregate)
                    .padding(.horizontal, IhsanSpacing.md)

                DailyPracticeGrid(
                    days: snapshot.days,
                    onDayTap: { day in
                        selectedDay = day
                    }
                )
                .padding(.horizontal, IhsanSpacing.md)

                GridLegend()
                    .padding(.horizontal, IhsanSpacing.lg)

                PerPrayerList(aggregate: snapshot.aggregate)
                    .padding(.horizontal, IhsanSpacing.md)

                InsightCard(aggregate: snapshot.aggregate)
                    .padding(.horizontal, IhsanSpacing.md)
            }
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
