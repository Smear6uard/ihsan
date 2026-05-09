import SwiftUI
import SwiftData
import IhsanCore
import IhsanDesignSystem

/// The Trajectory tab. Reads `PrayerLog`, `PauseInterval`, and
/// `TravelInterval` directly from SwiftData via `@Query`, hands them to a
/// `TrajectoryViewModel` for aggregation, and presents the heatmap, factual
/// summary line, per-prayer rows, and conditional insight card.
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
        ZStack {
            IhsanColor.ground.ignoresSafeArea()

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
        }
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
                .presentationBackground(IhsanColor.ground)
        }
    }

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Trajectory")
                .font(IhsanFont.title)
                .foregroundStyle(IhsanColor.textPrimary)

            if case .ready(let snapshot) = viewModel.state {
                Text(snapshot.period.formattedRange())
                    .font(IhsanFont.smallCaps)
                    .tracking(0.8)
                    .foregroundStyle(IhsanColor.textMuted)
                    .accessibilityLabel(snapshot.period.formattedRange())
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .tint(IhsanColor.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.top, IhsanSpacing.xxl)

        case .empty:
            TrajectoryEmptyState()
                .padding(.top, IhsanSpacing.xxl)

        case .ready(let snapshot):
            VStack(spacing: IhsanSpacing.lg) {
                HeatmapHero(snapshot: snapshot) { day in
                    selectedDay = day
                }
                .padding(.horizontal, IhsanSpacing.md)

                FactualSummaryLine(aggregate: snapshot.aggregate)

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
        .preferredColorScheme(.dark)
}
