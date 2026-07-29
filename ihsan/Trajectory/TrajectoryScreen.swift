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

    @Query(sort: \NaflLog.naflDate, order: .reverse)
    private var naflLogs: [NaflLog]

    @State private var viewModel = TrajectoryViewModel()
    @State private var selectedDay: DayCompletion?
    @State private var showingRepairSetup = false
    @State private var showingRepairDetail = false

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
        .sheet(isPresented: $showingRepairDetail) {
            RepairDetailScreen()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
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
                if settings?.sunnahLayerEnabled == true {
                    HStack {
                        Spacer()
                        naflOverlayToggle
                    }
                    .padding(.horizontal, IhsanSpacing.md)
                }

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
        GestaltGrid(
            days: snapshot.days,
            period: snapshot.period,
            naflDays: overlayNaflDays
        )
        .padding(IhsanSpacing.lg)
        .frame(maxWidth: .infinity)
        .ihsanIlluminatedPanel(intensity: .regular)
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

    /// The quiet in-Path switch for the overlay: a small outlined chip,
    /// filled while the sixth row shows. Visible only when the sunnah
    /// layer itself is on.
    private var naflOverlayToggle: some View {
        let isOn = settings?.pathNaflOverlayEnabled == true
        return Button {
            Haptics.impact(.light)
            settings?.pathNaflOverlayEnabled.toggle()
            settings?.modifiedAt = .now
        } label: {
            HStack(spacing: 5) {
                FourPointedStar()
                    .stroke(IhsanColor.brass.opacity(isOn ? 0.9 : 0.5), lineWidth: 0.9)
                    .frame(width: 9, height: 9)
                Text("NAFL")
                    .font(IhsanFont.inscription)
                    .tracking(1.6)
                    .foregroundStyle(IhsanColor.brass.opacity(isOn ? 0.95 : 0.6))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .overlay {
                Capsule()
                    .strokeBorder(IhsanColor.brass.opacity(isOn ? 0.6 : 0.3), lineWidth: 0.8)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Voluntary prayer overlay")
        .accessibilityValue(isOn ? "on" : "off")
        .accessibilityHint("Adds a quieter sixth row to the pattern.")
    }
}

#Preview {
    TrajectoryScreen()
        .modelContainer(
            for: [PrayerLog.self, PauseInterval.self, TravelInterval.self],
            inMemory: true
        )
}
