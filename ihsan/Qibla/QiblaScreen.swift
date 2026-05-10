import SwiftUI
import IhsanDesignSystem

/// Sheet-presented screen showing the direction to the Kaaba relative to the
/// device heading, the bearing in degrees, the great-circle distance to
/// Makkah, and the user's current city. Always renders against the standard
/// dark ground — no photographic wallpaper here, the dial carries the screen.
struct QiblaScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = QiblaViewModel()
    @State private var closeButtonDismissed = false

    var body: some View {
        ZStack {
            IhsanColor.ground.ignoresSafeArea()

            VStack(spacing: 0) {
                QiblaSheetHeader {
                    closeButtonDismissed = true
                    Haptics.impact(.light)
                    dismiss()
                }
                content
            }
        }
        .task {
            await viewModel.bootstrap()
        }
        .onDisappear {
            if !closeButtonDismissed {
                Haptics.impact(.medium)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            loadingState
        case .needsLocationPermission:
            permissionState
        case .ready(let snapshot):
            readyState(snapshot: snapshot)
        case .error(let message):
            errorState(message)
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: IhsanSpacing.md) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(IhsanColor.textSecondary)
            Text("Finding your location…")
                .font(IhsanFont.smallCaps)
                .tracking(1.0)
                .foregroundStyle(IhsanColor.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var permissionState: some View {
        VStack(spacing: IhsanSpacing.lg) {
            Image(systemName: "location.slash")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(IhsanColor.textMuted)
            Text("Location access is needed to compute qibla")
                .font(IhsanFont.bodyEnglish)
                .foregroundStyle(IhsanColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, IhsanSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func readyState(snapshot: QiblaState.Snapshot) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: IhsanSpacing.lg)

            QiblaCompassDial(
                qiblaBearing: snapshot.qiblaBearing,
                currentHeading: viewModel.smoothedHeading,
                isAligned: viewModel.isAligned
            )

            Spacer(minLength: IhsanSpacing.lg)

            VStack(spacing: IhsanSpacing.sm) {
                QiblaInfoPanel(
                    bearing: snapshot.qiblaBearing,
                    distanceKm: snapshot.distanceToMakkahKm,
                    cityName: snapshot.cityName
                )
                .padding(.horizontal, IhsanSpacing.md)

                if showCalibrationHint {
                    QiblaCalibrationHint()
                        .padding(.horizontal, IhsanSpacing.md)
                }
            }

            Spacer(minLength: IhsanSpacing.lg)

            privacyNote
                .padding(.horizontal, IhsanSpacing.xl)
                .padding(.bottom, IhsanSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: IhsanSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(IhsanColor.textMuted)
            Text(message)
                .font(IhsanFont.bodyEnglish)
                .foregroundStyle(IhsanColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(IhsanSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var privacyNote: some View {
        Text("Your location is used only for this calculation and is never stored.")
            .font(IhsanFont.smallCaps)
            .tracking(0.8)
            .foregroundStyle(IhsanColor.textMuted.opacity(0.7))
            .multilineTextAlignment(.center)
    }

    private var showCalibrationHint: Bool {
        viewModel.headingAccuracy < 0 || viewModel.headingAccuracy > 20
    }
}

#Preview("Qibla — Loading") {
    QiblaScreen()
}
