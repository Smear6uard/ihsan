import SwiftUI
import SwiftData
import IhsanCore
import IhsanDesignSystem
import IhsanLocation
import IhsanNotifications
import IhsanPrayerTimes

struct TodayScreen: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: TodayViewModel?

    var body: some View {
        content
            .task {
                if viewModel == nil {
                    viewModel = TodayViewModel(modelContext: modelContext)
                    Haptics.prepareAll()
                }
                await viewModel?.bootstrap()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel?.state {
        case .loading, nil:
            TodayLoadingView()
                .ihsanManuscriptPage()
        case .needsLocationPermission:
            TodayNeedsLocationView { Task { await viewModel?.bootstrap() } }
                .ihsanManuscriptPage()
        case .ready(let snapshot):
            if let viewModel {
                TodayReadyView(
                    snapshot: snapshot,
                    viewModel: viewModel
                )
            }
        case .error(let message):
            TodayErrorView(message: message) { Task { await viewModel?.bootstrap() } }
                .ihsanManuscriptPage()
        }
    }
}

// MARK: - State views

private struct TodayLoadingView: View {
    var body: some View {
        let foregroundSecondary = IhsanColor.skyForegroundSecondary()
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
    let onRetry: () -> Void

    var body: some View {
        let foreground = IhsanColor.skyForegroundPrimary()
        let foregroundSecondary = IhsanColor.skyForegroundSecondary()
        let foregroundMuted = IhsanColor.skyForegroundMuted()
        let accent = IhsanColor.accentWarm()
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
    let message: String
    let onRetry: () -> Void

    var body: some View {
        let foreground = IhsanColor.skyForegroundPrimary()
        let foregroundSecondary = IhsanColor.skyForegroundSecondary()
        let foregroundMuted = IhsanColor.skyForegroundMuted()
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
// New layout per the celestial redesign:
//
//   ┌─────────────────────────────┐
//   │ Zone 1 — refined header     │   ~10% of screen
//   │ Zone 2 — celestial scene    │   ~65% (sky, sun, moon, markers)
//   │ Zone 3 — focused-prayer card│   ~25% (single illuminated panel)
//   └─────────────────────────────┘
//
// The legacy hero countdown, prayer arc, and prayer list are folded
// into the celestial scene's prayer markers and the focused card's
// inline expansion. The full PrayerLogSheet remains accessible from
// the card's chevron and "More options" link for edge cases (qadā,
// retroactive missed, edit).

private struct TodayReadyView: View {
    let snapshot: TodayState.Snapshot
    let viewModel: TodayViewModel

    @Environment(\.modelContext) private var modelContext

    @Query private var todaysLogs: [PrayerLog]
    @Query private var settingsRows: [UserSettings]
    @Query(sort: \PauseInterval.startDate, order: .reverse) private var pauses: [PauseInterval]

    private var activePause: PauseInterval? {
        pauses.first(where: \.isActive)
    }

    @State private var focusedPrayer: Prayer?
    @State private var sheetSelection: LogSheetSelection?
    @State private var revertFocusTask: Task<Void, Never>?
    @State private var isCelestialReferencePresented = false

    /// Time the focused-prayer card stays on a marker-tapped prayer
    /// before reverting to the next-upcoming prayer per spec.
    private static let focusRevertInterval: TimeInterval = 8

    /// Vertical room the header occupies below the safe area. The plate
    /// keeps its arc, markers, and labels clear of this band; the
    /// atmosphere still fills the frame behind it.
    private static let headerZoneHeight: CGFloat = 92

    init(
        snapshot: TodayState.Snapshot,
        viewModel: TodayViewModel
    ) {
        self.snapshot = snapshot
        self.viewModel = viewModel

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: .now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        let predicate = #Predicate<PrayerLog> { log in
            log.prayerDate >= startOfDay && log.prayerDate < endOfDay
        }
        self._todaysLogs = Query(filter: predicate, sort: \PrayerLog.prayerDate)
    }

    var body: some View {
        GeometryReader { proxy in
            // `markerZoneBottomInset` reserves enough vertical space for
            // the focused card + the 8pt gap above it. Reading the
            // bottom safe-area inset keeps the gap consistent across
            // devices — the value picks up both the device's home
            // indicator inset and the tab-bar inset that RootTabView
            // adds to this view's parent.
            let cardBottomPadding: CGFloat = IhsanSpacing.md
            let sceneToCardGap: CGFloat = 8
            let markerZoneBottomInset = proxy.safeAreaInsets.bottom
                + cardBottomPadding
                + FocusedPrayerCard.cardHeight
                + sceneToCardGap

            ZStack(alignment: .bottom) {
                CelestialPlateScene(
                    markers: plateMarkers,
                    solarEvents: solarEvents,
                    latitude: snapshot.place.coordinates.latitude,
                    longitude: snapshot.place.coordinates.longitude,
                    timeZone: snapshot.place.timeZone,
                    topInset: proxy.safeAreaInsets.top + Self.headerZoneHeight,
                    bottomInset: markerZoneBottomInset,
                    night: snapshot.night,
                    onMarkerTap: handleMarkerTap
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    TodayHeader(
                        cityName: snapshot.place.cityName ?? "Current Location",
                        date: .now,
                        dayTimes: snapshot.dayTimes,
                        onMoonPhaseTap: { isCelestialReferencePresented = true }
                    )
                    .padding(.horizontal, IhsanSpacing.md)
                    .padding(.top, IhsanSpacing.md)

                    Spacer(minLength: 0)
                }

                VStack(spacing: IhsanSpacing.sm) {
                    if let activePause {
                        RepairPausedCard(
                            expectedEndDate: activePause.expectedEndDate,
                            tokens: PaletteState.resolved(
                                for: SkyPhase.resolve(at: .now, events: solarEvents)
                            ),
                            onEndPause: { togglePause() }
                        )
                    } else {
                        FocusedPrayerCard(
                            prayer: effectiveFocusedPrayer,
                            scheduledTime: scheduledTime(for: effectiveFocusedPrayer),
                            windowEndTime: windowEndTime(for: effectiveFocusedPrayer),
                            currentStatus: log(for: effectiveFocusedPrayer)?.status,
                            isJamaah: log(for: effectiveFocusedPrayer)?.withJamaah ?? false,
                            isInWindow: snapshot.activePrayer == effectiveFocusedPrayer,
                            onCommit: { status, isJamaah in
                                commit(status: status, isJamaah: isJamaah, for: effectiveFocusedPrayer)
                            },
                            onMoreOptions: {
                                sheetSelection = LogSheetSelection(prayer: effectiveFocusedPrayer)
                            }
                        )
                    }
                }
                .padding(.bottom, IhsanSpacing.md)
            }
            .sheet(item: $sheetSelection) { selection in
                logSheet(for: selection.prayer)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.thinMaterial)
            }
            .fullScreenCover(isPresented: $isCelestialReferencePresented) {
                CelestialReferenceView(
                    latitude: snapshot.place.coordinates.latitude,
                    longitude: snapshot.place.coordinates.longitude,
                    onDismiss: { isCelestialReferencePresented = false }
                )
            }
        }
    }

    // MARK: - Plate inputs

    /// The four solar events that anchor the palette phase, taken from
    /// the day's real schedule. Dhuhr stands in for solar noon — it is
    /// defined as the moment just after the sun's upper transit, which
    /// is exactly the anchor `SkyPhase` wants.
    private var solarEvents: SolarDayEvents {
        SolarDayEvents(
            sunrise: snapshot.dayTimes.sunrise,
            solarNoon: snapshot.dayTimes.dhuhr.scheduledTime,
            maghrib: snapshot.dayTimes.maghrib.scheduledTime,
            isha: snapshot.dayTimes.isha.scheduledTime
        )
    }

    private var plateMarkers: [CelestialPlateScene.Marker] {
        snapshot.dayTimes.allFardh.map { time in
            CelestialPlateScene.Marker(
                prayer: time.prayer,
                time: time.scheduledTime,
                state: markerState(for: time.prayer, scheduledTime: time.scheduledTime)
            )
        }
    }

    /// The luminous marker is always the prayer the card is about, so
    /// the plate and the card never disagree about where "now" is. A
    /// logged prayer only reads as logged once its window has moved on.
    private func markerState(
        for prayer: Prayer,
        scheduledTime: Date
    ) -> PrayerMarkerState {
        // During an excused pause every marker rests in the neutral outline
        // state — no glow, no passed-unlogged ink. Times stay readable;
        // nothing is asked.
        if activePause != nil { return .upcoming }
        if prayer == currentPlatePrayer { return .current }
        if log(for: prayer) != nil { return .logged }
        return scheduledTime > .now ? .upcoming : .passedUnlogged
    }

    private var currentPlatePrayer: Prayer {
        snapshot.activePrayer ?? snapshot.nextPrayerTime.prayer
    }

    // MARK: - Focused prayer resolution

    /// The prayer the focused card is currently displaying. The user
    /// can override the default by tapping a marker on the scene; the
    /// override reverts to the next-upcoming after 8 sec per spec.
    private var effectiveFocusedPrayer: Prayer {
        focusedPrayer
            ?? snapshot.activePrayer
            ?? snapshot.nextPrayerTime.prayer
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

    private func scheduledTime(for prayer: Prayer) -> Date {
        snapshot.dayTimes.allFardh.first { $0.prayer == prayer }?.scheduledTime
            ?? snapshot.nextPrayerTime.scheduledTime
    }

    /// End of `prayer`'s window. Fajr ends at sunrise, Dhuhr–Maghrib
    /// at the next prayer, Isha returns `nil` (the window extends
    /// past midnight and the card drops the "WINDOW ENDS" clause).
    private func windowEndTime(for prayer: Prayer) -> Date? {
        switch prayer {
        case .fajr:
            return snapshot.dayTimes.sunrise
        case .dhuhr:
            return snapshot.dayTimes.asr.scheduledTime
        case .asr:
            return snapshot.dayTimes.maghrib.scheduledTime
        case .maghrib:
            return snapshot.dayTimes.isha.scheduledTime
        case .isha:
            return nil
        }
    }

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

    // MARK: - Edge-case log sheet (still used for qadā, missed, edit)

    @ViewBuilder
    private func logSheet(for prayer: Prayer) -> some View {
        let prayerTime = snapshot.dayTimes.allFardh.first { $0.prayer == prayer }
        let log = log(for: prayer)
        let adhanEnabled = settingsRows.first?.adhanEnabled(for: prayer) ?? true

        if let prayerTime {
            PrayerLogSheet(
                prayer: prayer,
                scheduledTime: prayerTime.scheduledTime,
                windowEndTime: windowEndTime(for: prayer),
                currentStatus: log?.status,
                isJamaah: log?.withJamaah ?? false,
                adhanEnabled: adhanEnabled,
                isPaused: activePause != nil,
                onSelect: { choice in handleSheetChoice(choice, for: prayer) },
                onToggleAdhan: { Task { await viewModel.toggleAdhanEnabled(for: prayer) } },
                onTogglePause: { togglePause() },
                onCancel: {}
            )
        }
    }

    /// One tap begins an excused pause; the same control ends it. The
    /// notification schedule rebuilds either way, so suppression tracks the
    /// pause without touching any stored preference.
    private func togglePause() {
        Haptics.impact(.medium)
        let now = Date.now
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
        Haptics.notification(.success)
        Task {
            try? await NotificationScheduler.shared.rebuildSchedule()
        }
    }

    private func handleSheetChoice(_ choice: PrayerLogSheet.Choice, for prayer: Prayer) {
        let currentJamaah = log(for: prayer)?.withJamaah ?? false
        Task {
            switch choice {
            case .inJamaah:
                await viewModel.setStatus(.onTime, for: prayer)
                if !currentJamaah { await viewModel.toggleJamaah(for: prayer) }
            case .onTime:
                await viewModel.setStatus(.onTime, for: prayer)
                if currentJamaah { await viewModel.toggleJamaah(for: prayer) }
            case .late:
                await viewModel.setStatus(.late, for: prayer)
            case .qada:
                await viewModel.setStatus(.qada, for: prayer)
            case .missed:
                await viewModel.setStatus(.missed, for: prayer)
            }
        }
    }
}

/// Identifies which prayer's log sheet is currently presented.
/// Hashable so it works as `sheet(item:)`'s identifier.
private struct LogSheetSelection: Identifiable, Hashable {
    let prayer: Prayer
    var id: Prayer { prayer }
}
