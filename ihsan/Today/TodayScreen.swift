import SwiftUI
import SwiftData
import IhsanCore
import IhsanDesignSystem
import IhsanLocation
import IhsanPrayerTimes

struct TodayScreen: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: TodayViewModel?
    @State private var presentingQibla = false
    @State private var presentingMasjids = false

    var body: some View {
        content
            // Time-adaptive sky. The gradient endpoints drift through
            // the day so the screen reads as morning, afternoon, or
            // night without the user having to check a clock. The
            // photographic sunrise / maghrib assets live INSIDE the
            // hero countdown card now (see `TodayHeroSection`), not
            // across the whole background — keeps the warmth focused
            // where the user's eye lands.
            .ihsanSkyBackground()
            .task {
                if viewModel == nil {
                    viewModel = TodayViewModel(modelContext: modelContext)
                    Haptics.prepareAll()
                }
                await viewModel?.bootstrap()
            }
            .sheet(isPresented: $presentingQibla) {
                QiblaScreen()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $presentingMasjids) {
                MasjidFinderScreen()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel?.state {
        case .loading, nil:
            TodayLoadingView()
        case .needsLocationPermission:
            TodayNeedsLocationView { Task { await viewModel?.bootstrap() } }
        case .ready(let snapshot):
            if let viewModel {
                TodayReadyView(
                    snapshot: snapshot,
                    viewModel: viewModel,
                    onQibla: { presentingQibla = true },
                    onMasjids: { presentingMasjids = true }
                )
            }
        case .error(let message):
            TodayErrorView(message: message) { Task { await viewModel?.bootstrap() } }
        }
    }
}

// MARK: - State views

private struct TodayLoadingView: View {
    var body: some View {
        VStack(spacing: IhsanSpacing.md) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(IhsanColor.textSecondary)
            Text("Loading prayer times…")
                .font(IhsanFont.smallCaps)
                .foregroundStyle(IhsanColor.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct TodayNeedsLocationView: View {
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: IhsanSpacing.lg) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 48))
                .foregroundStyle(IhsanColor.textMuted)
            Text("Location access is needed")
                .font(IhsanFont.subtitle)
                .foregroundStyle(IhsanColor.textPrimary)
            Text("Ihsan calculates prayer times from your current location. Coordinates are never stored or shared.")
                .font(IhsanFont.bodyEnglish)
                .foregroundStyle(IhsanColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, IhsanSpacing.xl)
            Button("Continue") {
                Haptics.impact(.light)
                onRetry()
            }
                .buttonStyle(.borderedProminent)
                .tint(IhsanColor.textPrimary.opacity(0.18))
                .foregroundStyle(IhsanColor.textPrimary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct TodayErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: IhsanSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(IhsanColor.textMuted)
            Text(message)
                .font(IhsanFont.bodyEnglish)
                .foregroundStyle(IhsanColor.textSecondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Haptics.impact(.light)
                onRetry()
            }
                .buttonStyle(.bordered)
                .tint(IhsanColor.textPrimary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct TodayReadyView: View {
    let snapshot: TodayState.Snapshot
    let viewModel: TodayViewModel
    let onQibla: () -> Void
    let onMasjids: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: IhsanSpacing.lg) {
                TodayHeader(
                    cityName: snapshot.place.cityName ?? "Current Location",
                    date: .now,
                    qiblaAction: onQibla,
                    masjidAction: onMasjids
                )

                if snapshot.isWithinSuhoorWindow {
                    SuhoorIftarBanner(suhoorEnd: snapshot.nextPrayerTime.scheduledTime)
                }

                TodayHeroSection(snapshot: snapshot)

                DayArc(
                    prayerMarks: snapshot.dayTimes.allFardh.map {
                        DayArc.PrayerMark(prayer: $0.prayer, time: $0.scheduledTime)
                    }
                )

                TodayPrayerList(
                    snapshot: snapshot,
                    onSetStatus: { prayer, status in
                        Task { await viewModel.setStatus(status, for: prayer) }
                    },
                    onToggleJamaah: { prayer in
                        Task { await viewModel.toggleJamaah(for: prayer) }
                    },
                    onToggleAdhan: { prayer in
                        Task { await viewModel.toggleAdhanEnabled(for: prayer) }
                    }
                )

                if shouldShowReflectionEntry {
                    EveningReflectionEntry()
                }

                Color.clear.frame(height: IhsanSpacing.xl)
            }
            .padding(.horizontal, IhsanSpacing.md)
            .padding(.top, IhsanSpacing.md)
        }
    }

    private var shouldShowReflectionEntry: Bool {
        Date.now >= snapshot.dayTimes.isha.scheduledTime
    }
}
