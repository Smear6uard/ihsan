import SwiftUI
import IhsanDesignSystem
import IhsanLocation
import IhsanPrayerTimes

/// Sheet-presented Qibla compass for watchOS. Differs from iOS:
/// - Smaller dial (compass takes ~50% of vertical space)
/// - Compact bearing/distance row beneath
/// - Hardware-availability fallback for non-magnetometer watches
/// - Done button (top trailing) — Apple Watch's standard sheet
///   dismissal convention. Crown press goes home; that is system
///   behavior we don't override.
struct QiblaView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = QiblaViewModel()

    var body: some View {
        ZStack {
            IhsanColor.ground.ignoresSafeArea()
            content
        }
        .navigationTitle("Qibla")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("Close qibla")
            }
        }
        .task {
            await viewModel.bootstrap()
        }
        .onDisappear {
            viewModel.stop()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            loading
        case .needsLocationPermission:
            permission
        case .compassUnavailable(let snapshot):
            compassUnavailable(snapshot)
        case .ready(let snapshot):
            ready(snapshot)
        case .error(let message):
            errorView(message)
        }
    }

    // MARK: - States

    private var loading: some View {
        VStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(IhsanColor.textSecondary)
            Text("Finding location…")
                .font(.system(size: 12))
                .foregroundStyle(IhsanColor.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var permission: some View {
        VStack(spacing: 8) {
            Image(systemName: "location.slash")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(IhsanColor.textMuted)
            Text("Location is needed to compute qibla")
                .font(.system(size: 12))
                .foregroundStyle(IhsanColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(IhsanColor.textMuted)
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(IhsanColor.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(4)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func ready(_ snapshot: QiblaState.Snapshot) -> some View {
        VStack(spacing: 6) {
            CompassDial(
                qiblaBearing: snapshot.qiblaBearing,
                currentHeading: viewModel.smoothedHeading,
                isAligned: viewModel.isAligned
            )
            .padding(.horizontal, 4)

            infoRow(snapshot: snapshot)

            if showCalibrationHint {
                Text("Move wrist in figure-8 to calibrate")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(IhsanColor.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 6)
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 6)
    }

    private func compassUnavailable(_ snapshot: QiblaState.Snapshot) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "location.north.line.fill")
                .font(.system(size: 24))
                .foregroundStyle(IhsanColor.statusQada)
            Text("\(Int(snapshot.qiblaBearing.rounded()))° from north")
                .font(.system(size: 16, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(IhsanColor.textPrimary)
            Text(DistanceFormatter.format(km: snapshot.distanceToMakkahKm))
                .font(.system(size: 12, design: .rounded).monospacedDigit())
                .foregroundStyle(IhsanColor.textSecondary)
            Text("Compass not available on this watch")
                .font(.system(size: 9))
                .foregroundStyle(IhsanColor.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Subviews

    private func infoRow(snapshot: QiblaState.Snapshot) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                Text("BEARING")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(IhsanColor.textMuted)
                Text("\(Int(snapshot.qiblaBearing.rounded()))°")
                    .font(.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(IhsanColor.textPrimary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 0) {
                Text("DISTANCE")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(IhsanColor.textMuted)
                Text(DistanceFormatter.format(km: snapshot.distanceToMakkahKm))
                    .font(.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(IhsanColor.textPrimary)
            }
        }
        .padding(.horizontal, 6)
    }

    private var showCalibrationHint: Bool {
        viewModel.headingAccuracy < 0 || viewModel.headingAccuracy > 20
    }
}
