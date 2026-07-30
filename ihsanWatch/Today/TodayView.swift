import SwiftUI
import SwiftData
import IhsanCore
import IhsanDesignSystem
import IhsanLocation
import IhsanPrayerTimes

/// Watch root surface. Hero countdown + 5-prayer status row + Qibla
/// affordance. Digital Crown rotates through the 5 prayers; tapping
/// the hero (or the highlighted dot) opens the action sheet for the
/// selected prayer.
///
/// The selection is decoupled from the next-prayer countdown: the
/// countdown always references `nextPrayer` (the upcoming time),
/// while the dot highlight tracks the user's Crown-driven cursor.
/// This separation matches how watch users reason about the screen —
/// "the countdown tells me what's next; the dots are how I touch any
/// of them."
struct TodayView: View {
    let onPresentQibla: () -> Void
    let nowProvider: NowProvider

    init(
        onPresentQibla: @escaping () -> Void,
        nowProvider: NowProvider = .active
    ) {
        self.onPresentQibla = onPresentQibla
        self.nowProvider = nowProvider
    }

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: TodayViewModel?
    @State private var crownPosition: Double = 0
    @State private var sheetPrayer: Prayer?
    @State private var isRefreshingLocation = false

    var body: some View {
        ZStack {
            IhsanColor.ground.ignoresSafeArea()
            content
        }
        .containerBackground(IhsanColor.ground.gradient, for: .navigation)
        .task {
            if viewModel == nil {
                viewModel = TodayViewModel(
                    nowProvider: nowProvider,
                    modelContext: modelContext
                )
            }
            await viewModel?.bootstrap()
        }
        .sheet(item: $sheetPrayer) { prayer in
            actionSheet(for: prayer)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel?.state {
        case .loading, nil:
            loadingView
        case .needsLocationPermission:
            permissionView
        case .ready(let snapshot):
            readyView(snapshot)
        case .error(let message):
            errorView(message)
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(IhsanColor.textSecondary)
            Text("Loading…")
                .font(.system(size: 13))
                .foregroundStyle(IhsanColor.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var permissionView: some View {
        VStack(spacing: 10) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(IhsanColor.textMuted)
            Text("Location is needed to show prayer times")
                .font(.system(size: 13))
                .foregroundStyle(IhsanColor.textSecondary)
                .multilineTextAlignment(.center)
            Button("Try again") {
                Task { await viewModel?.bootstrap() }
            }
            .font(.system(size: 13, weight: .medium))
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(IhsanColor.textMuted)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(IhsanColor.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
            Button("Retry") {
                Task { await viewModel?.bootstrap() }
            }
            .font(.system(size: 12, weight: .medium))
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func readyView(_ snapshot: TodayState.Snapshot) -> some View {
        TimelineView(.periodic(from: .distantPast, by: 1)) { context in
            let now = nowProvider.resolve(context.date)
            let schedule = snapshot.scheduleWindow.resolverSchedule
            let resolution = PrayerStateResolver.resolve(
                prayerTimes: schedule,
                now: now
            )
            readyContent(snapshot, resolution: resolution, now: now)
                .onAppear {
                    PrayerResolverDiagnostics.emit(
                        prayerTimes: schedule,
                        now: now,
                        resolution: resolution,
                        surface: "watch.today"
                    )
                }
                .onChange(of: resolution) { _, newResolution in
                    PrayerResolverDiagnostics.emit(
                        prayerTimes: schedule,
                        now: now,
                        resolution: newResolution,
                        surface: "watch.today"
                    )
                }
        }
    }

    private func readyContent(
        _ snapshot: TodayState.Snapshot,
        resolution: PrayerResolution,
        now: Date
    ) -> some View {
        ScrollView {
            VStack(spacing: 10) {
                topBar(cityName: snapshot.place.cityName)

                HeroCountdown(
                    targetPrayer: resolution.nextPrayer.prayer,
                    targetTime: resolution.countdownTarget,
                    now: now
                )
                .ihsanGlassHero()
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .onTapGesture {
                    sheetPrayer = selectedPrayer
                    WatchHaptics.click()
                }

                PrayerDots(snapshot: snapshot, selectedPrayer: selectedPrayer)
                    .padding(.horizontal, 4)
                    .focusable(true)
                    .digitalCrownRotation(
                        $crownPosition,
                        from: 0,
                        through: Double(PrayerListOrder.all.count - 1),
                        by: 1,
                        sensitivity: .low,
                        isContinuous: false,
                        isHapticFeedbackEnabled: true
                    )
                    .onTapGesture {
                        sheetPrayer = selectedPrayer
                        WatchHaptics.click()
                    }
                    .accessibilityAction(named: "Log selected prayer") {
                        sheetPrayer = selectedPrayer
                    }

                selectedPrayerCaption(snapshot: snapshot)
            }
            .padding(.horizontal, 6)
            .padding(.top, 4)
            .padding(.bottom, 10)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Subviews

    private func topBar(cityName: String?) -> some View {
        HStack {
            Button(action: refreshLocation) {
                Image(systemName: isRefreshingLocation
                      ? "arrow.triangle.2.circlepath"
                      : "location.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(IhsanColor.textMuted)
                    .symbolEffect(.rotate, isActive: isRefreshingLocation)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Refresh location")

            Spacer(minLength: 4)

            Text(cityName?.uppercased() ?? "CURRENT LOCATION")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(IhsanColor.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 4)

            Button(action: onPresentQibla) {
                Image(systemName: "location.north.line.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(IhsanColor.textMuted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open qibla compass")
        }
        .padding(.horizontal, 2)
    }

    private func selectedPrayerCaption(snapshot: TodayState.Snapshot) -> some View {
        let formatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "h:mm a"
            return f
        }()
        let scheduled = snapshot.scheduleWindow.day.time(for: selectedPrayer)
        let status = snapshot.status(for: selectedPrayer)

        return VStack(spacing: 1) {
            Text(formatter.string(from: scheduled))
                .font(.system(size: 13, weight: .regular, design: .rounded).monospacedDigit())
                .foregroundStyle(IhsanColor.textSecondary)

            if let status {
                Text("Logged \(label(status))")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(IhsanColor.textMuted)
            } else {
                Text("Tap to log")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(IhsanColor.textMuted.opacity(0.7))
            }
        }
        .accessibilityLabel(captionAccessibility(snapshot: snapshot))
    }

    private func actionSheet(for prayer: Prayer) -> some View {
        guard case .ready(let snapshot) = viewModel?.state else {
            return AnyView(EmptyView())
        }
        return AnyView(
            PrayerActionSheet(
                prayer: prayer,
                currentStatus: snapshot.status(for: prayer),
                isJamaah: snapshot.isJamaah(for: prayer),
                onSelectStatus: { status in
                    Task { await viewModel?.setStatus(status, for: prayer) }
                },
                onToggleJamaah: {
                    Task { await viewModel?.toggleJamaah(for: prayer) }
                },
                onDismiss: { sheetPrayer = nil }
            )
        )
    }

    // MARK: - Helpers

    /// Resolves the currently-selected prayer from the (clamped, snapped)
    /// crown position. Crown is `low` sensitivity + `by: 1`, so the value
    /// arrives already discrete; clamping defends against off-by-one when
    /// SwiftUI overshoots at a boundary.
    private var selectedPrayer: Prayer {
        let index = max(0, min(PrayerListOrder.all.count - 1, Int(crownPosition.rounded())))
        return PrayerListOrder.all[index]
    }

    private func refreshLocation() {
        guard !isRefreshingLocation else { return }
        isRefreshingLocation = true
        WatchHaptics.click()
        Task {
            try? await viewModel?.refreshSnapshot()
            isRefreshingLocation = false
        }
    }

    private func label(_ status: PrayerStatus) -> String {
        switch status {
        case .onTime: "on time"
        case .late: "late"
        case .missed: "missed"
        case .qada: "qada"
        }
    }

    private func captionAccessibility(snapshot: TodayState.Snapshot) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        let scheduled = snapshot.scheduleWindow.day.time(for: selectedPrayer)
        let timeStr = formatter.string(from: scheduled)
        let prayerName = selectedPrayer.displayNameEnglish
        if let status = snapshot.status(for: selectedPrayer) {
            return "\(prayerName) at \(timeStr), logged \(label(status))"
        }
        return "\(prayerName) at \(timeStr), not yet logged"
    }
}

extension Prayer: @retroactive Identifiable {
    public var id: String { rawValue }
}
