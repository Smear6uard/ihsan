import SwiftUI
import MapKit
import IhsanDesignSystem

#if canImport(UIKit)
import UIKit
#endif

/// Sheet-presented screen that lists masjids near the user's current
/// location. Three parallel `MKLocalSearch` queries through Apple's
/// MapKit return mosques, masjids, and Islamic centers; results are
/// merged, deduplicated, and sorted by distance. Tapping a row hands
/// off to Apple Maps for directions.
///
/// Always renders against the standard dark ground. The sheet supports
/// `.medium` and `.large` detents — drag the indicator to switch.
struct MasjidFinderScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = MasjidFinderViewModel()

    var body: some View {
        ZStack {
            IhsanColor.ground.ignoresSafeArea()

            VStack(spacing: 0) {
                MasjidSheetHeader { dismiss() }

                RadiusSelector(radius: $viewModel.radius)
                    .padding(.horizontal, IhsanSpacing.md)
                    .padding(.top, IhsanSpacing.md)
                    .padding(.bottom, IhsanSpacing.sm)

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                privacyNote
                    .padding(.horizontal, IhsanSpacing.xl)
                    .padding(.top, IhsanSpacing.sm)
                    .padding(.bottom, IhsanSpacing.lg)
            }
        }
        .task {
            await viewModel.bootstrap()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            loadingState
        case .needsLocationPermission:
            permissionState
        case .ready(let results):
            resultsList(results)
        case .empty:
            MasjidEmptyState(radiusLabel: viewModel.radius.label) {
                openMapsToCurrentArea()
            }
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
            Text(searchingText)
                .font(IhsanFont.smallCaps)
                .tracking(1.0)
                .foregroundStyle(IhsanColor.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, IhsanSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var permissionState: some View {
        VStack(spacing: IhsanSpacing.lg) {
            Image(systemName: "location.slash")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(IhsanColor.textMuted)
                .symbolRenderingMode(.hierarchical)
            Text("Location access is needed to find masjids near you")
                .font(IhsanFont.bodyEnglish)
                .foregroundStyle(IhsanColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, IhsanSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func resultsList(_ results: [MasjidResult]) -> some View {
        ScrollView {
            LazyVStack(spacing: IhsanSpacing.sm) {
                ForEach(results) { result in
                    MasjidResultRow(
                        result: result,
                        onTap: { viewModel.openInMaps(result) },
                        onCopyAddress: { copyAddress(result) },
                        onShare: { shareLocation(result) }
                    )
                }
            }
            .padding(.horizontal, IhsanSpacing.md)
            .padding(.top, IhsanSpacing.xs)
            .padding(.bottom, IhsanSpacing.lg)
        }
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: IhsanSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(IhsanColor.textMuted)
                .symbolRenderingMode(.hierarchical)
            Text(message)
                .font(IhsanFont.bodyEnglish)
                .foregroundStyle(IhsanColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, IhsanSpacing.xl)
            Button {
                Task { await viewModel.search() }
            } label: {
                Text("Try Again")
                    .font(IhsanFont.bodyEnglishBold)
                    .foregroundStyle(IhsanColor.textPrimary)
                    .padding(.horizontal, IhsanSpacing.lg)
                    .padding(.vertical, IhsanSpacing.sm)
                    .background {
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay {
                                Capsule()
                                    .strokeBorder(
                                        IhsanColor.atmospheric,
                                        lineWidth: 0.5
                                    )
                            }
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(IhsanSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var privacyNote: some View {
        Text("Search runs through Apple Maps. Your location is not stored or shared.")
            .font(IhsanFont.smallCaps)
            .tracking(0.8)
            .foregroundStyle(IhsanColor.textMuted.opacity(0.7))
            .multilineTextAlignment(.center)
            .accessibilityLabel(
                "Search runs through Apple Maps. Your location is not stored or shared."
            )
    }

    private var searchingText: String {
        if let city = viewModel.cityName {
            return "Searching for masjids near \(city)"
        }
        return "Searching for masjids nearby"
    }

    // MARK: - Side effects

    private func copyAddress(_ result: MasjidResult) {
        let toCopy = result.address ?? result.name
        #if canImport(UIKit)
        UIPasteboard.general.string = toCopy
        #endif
        Haptics.success()
    }

    private func shareLocation(_ result: MasjidResult) {
        #if canImport(UIKit)
        guard let url = result.shareURL else { return }
        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else {
            return
        }
        // Anchor for iPad popover presentation.
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = root.view
            popover.sourceRect = CGRect(
                x: root.view.bounds.midX,
                y: root.view.bounds.midY,
                width: 0, height: 0
            )
            popover.permittedArrowDirections = []
        }
        // Walk down to the topmost presented controller before presenting.
        var presenter: UIViewController = root
        while let next = presenter.presentedViewController {
            presenter = next
        }
        presenter.present(activityVC, animated: true)
        #endif
    }

    /// Open Apple Maps centered on the user's current location.
    /// `MKMapItem.forCurrentLocation()` is the documented way to launch
    /// Maps without a destination — drops the user where they are.
    private func openMapsToCurrentArea() {
        MKMapItem.forCurrentLocation().openInMaps()
    }
}

#Preview("Masjid Finder — Loading") {
    MasjidFinderScreen()
}
