import SwiftUI
import MapKit
import IhsanCore
import IhsanDesignSystem
import SwiftData

#if canImport(UIKit)
import UIKit
#endif

/// A sheet-scoped, privacy-preserving Apple Maps search. Results and
/// coordinates live only in this view's state and leave memory when the
/// sheet closes; nothing is written to the model, preferences, or disk.
struct MasjidFinderScreen: View {
    let locationName: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.nowProvider) private var nowProvider
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = MasjidFinderViewModel()

    /// The row awaiting a decision, when choosing it would displace a
    /// masjid the user already set.
    @State private var pendingReplacement: MasjidResult?
    /// True while the times editor is up, after a venue has been chosen.
    @State private var isEditingTimes = false

    var body: some View {
        TimelineView(.periodic(from: .distantPast, by: 60)) { context in
            let now = nowProvider.resolve(context.date)
            let tokens = IhsanPageChrome.tokens(at: now)

            sheet(tokens: tokens)
                .environment(\.timeOfDayOverride, now)
        }
        .ihsanManuscriptPage()
        .task {
            #if DEBUG
            guard stagedState == nil else { return }
            #endif
            await viewModel.bootstrap()
        }
        .confirmationDialog(
            "Replace your masjid?",
            isPresented: replacementPrompt,
            titleVisibility: .visible
        ) {
            Button("Replace", role: .destructive) {
                if let pendingReplacement { adopt(pendingReplacement) }
                pendingReplacement = nil
            }
            Button("Keep", role: .cancel) { pendingReplacement = nil }
        } message: {
            Text(replacementMessage)
        }
        .sheet(isPresented: $isEditingTimes) {
            if let masjid = MyMasjid.fetchExisting(in: modelContext),
               let settings = try? UserSettings.fetchOrCreate(in: modelContext) {
                NavigationStack {
                    MyMasjidEditorScreen(masjid: masjid, settings: settings)
                }
            }
        }
    }

    // MARK: - Choosing a masjid

    private var currentMasjid: MyMasjid? {
        MyMasjid.fetchExisting(in: modelContext)
    }

    private func isMyMasjid(_ result: MasjidResult) -> Bool {
        currentMasjid?.matches(
            name: result.name,
            latitude: result.coordinate.latitude,
            longitude: result.coordinate.longitude
        ) ?? false
    }

    private var replacementPrompt: Binding<Bool> {
        Binding(
            get: { pendingReplacement != nil },
            set: { if !$0 { pendingReplacement = nil } }
        )
    }

    /// Says what will be lost before it is lost. The times described the
    /// other congregation's schedule, so they cannot come along.
    private var replacementMessage: String {
        let existing = currentMasjid?.name ?? "your current masjid"
        return "The times you entered for \(existing) will be cleared."
    }

    /// Choosing a venue: adopt it outright when nothing is set or nothing
    /// would be lost, and ask first when times would be discarded.
    private func chooseAsMine(_ result: MasjidResult) {
        guard let existing = currentMasjid, existing.hasAnyIqamah else {
            adopt(result)
            return
        }
        pendingReplacement = result
    }

    /// The one deliberate write of a venue's coordinate. The search path
    /// itself still stores nothing.
    private func adopt(_ result: MasjidResult) {
        guard let masjid = try? MyMasjid.fetchOrCreate(in: modelContext) else { return }
        masjid.replaceVenue(
            name: result.name,
            streetLabel: result.street,
            latitude: result.coordinate.latitude,
            longitude: result.coordinate.longitude
        )
        try? modelContext.save()
        isEditingTimes = true
    }

    /// Verification-only staging for the four non-result branches.
    /// The live ready-state travel check still runs the real location
    /// coordinator and MKLocalSearch stack.
    #if DEBUG
    private var stagedState: MasjidFinderState? {
        switch DebugLaunch.value(after: "-IhsanDebugMasjidState") {
        case "loading": .loading
        case "permission": .needsLocationPermission
        case "empty": .empty
        case "offline": .failure
        default: nil
        }
    }
    #endif

    private var displayedState: MasjidFinderState {
        #if DEBUG
        stagedState ?? viewModel.state
        #else
        viewModel.state
        #endif
    }

    private func sheet(tokens: SkyPaletteTokens) -> some View {
        VStack(spacing: 0) {
            MasjidSheetHeader(
                locationName: viewModel.cityName ?? locationName,
                tokens: tokens,
                onClose: { dismiss() }
            )

            OrnamentalDivider(tint: tokens.metal, opacity: 0.45)
                .padding(.horizontal, IhsanSpacing.md)
                .padding(.top, IhsanSpacing.sm)

            content(tokens: tokens)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            privacyNote(tokens: tokens)
                .padding(.horizontal, IhsanSpacing.xl)
                .padding(.vertical, IhsanSpacing.md)
        }
    }

    @ViewBuilder
    private func content(tokens: SkyPaletteTokens) -> some View {
        switch displayedState {
        case .loading:
            ScrollView {
                MasjidLoadingState(tokens: tokens)
                    .padding(.horizontal, IhsanSpacing.md)
                    .padding(.vertical, IhsanSpacing.sm)
            }

        case .needsLocationPermission:
            ScrollView {
                permissionState(tokens: tokens)
                    .padding(.horizontal, IhsanSpacing.md)
                    .padding(.vertical, IhsanSpacing.sm)
            }

        case .ready(let results):
            resultsList(results, tokens: tokens)

        case .empty:
            ScrollView {
                MasjidEmptyState(tokens: tokens) {
                    openMapsToCurrentArea()
                }
                .padding(.horizontal, IhsanSpacing.md)
                .padding(.vertical, IhsanSpacing.sm)
            }

        case .failure:
            ScrollView {
                failureState(tokens: tokens)
                    .padding(.horizontal, IhsanSpacing.md)
                    .padding(.vertical, IhsanSpacing.sm)
            }
        }
    }

    private func resultsList(
        _ results: [MasjidResult],
        tokens: SkyPaletteTokens
    ) -> some View {
        ScrollView {
            LazyVStack(spacing: IhsanSpacing.sm) {
                ForEach(results) { result in
                    MasjidResultRow(
                        result: result,
                        tokens: tokens,
                        isMyMasjid: isMyMasjid(result),
                        onTap: { viewModel.openInMaps(result) },
                        onSetAsMine: { chooseAsMine(result) }
                    )
                }
            }
            .padding(IhsanSpacing.md)
        }
    }

    private func permissionState(tokens: SkyPaletteTokens) -> some View {
        VStack(spacing: IhsanSpacing.lg) {
            SettingsGlyphView(.location, color: tokens.metal.opacity(0.65))
                .frame(width: IhsanSpacing.xxl, height: IhsanSpacing.xxl)

            VStack(spacing: IhsanSpacing.sm) {
                Text("Location access is needed")
                    .font(IhsanFont.subtitle)
                    .foregroundStyle(tokens.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Allow location access in Settings to look nearby.")
                    .font(IhsanFont.bodyEnglish)
                    .foregroundStyle(tokens.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            #if canImport(UIKit)
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                Link(destination: settingsURL) {
                    Text("ALLOW IN SETTINGS")
                        .font(IhsanFont.inscription)
                        .tracking(1.6)
                        .foregroundStyle(tokens.leafGold)
                        .padding(.vertical, IhsanSpacing.sm)
                }
                .accessibilityHint("Opens Ihsan's location settings")
            }
            #endif
        }
        .padding(.horizontal, IhsanSpacing.xl)
        .padding(.vertical, IhsanSpacing.lg)
        .frame(maxWidth: .infinity)
        .celestialPanel(tokens: tokens, cornerRadius: 18)
    }

    private func failureState(tokens: SkyPaletteTokens) -> some View {
        VStack(spacing: IhsanSpacing.lg) {
            SettingsGlyphView(.location, color: tokens.metal.opacity(0.65))
                .frame(width: IhsanSpacing.xxl, height: IhsanSpacing.xxl)

            VStack(spacing: IhsanSpacing.sm) {
                Text("Apple Maps could not be reached")
                    .font(IhsanFont.subtitle)
                    .foregroundStyle(tokens.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Check your internet connection, then try again.")
                    .font(IhsanFont.bodyEnglish)
                    .foregroundStyle(tokens.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                Haptics.impact(.light)
                Task { await viewModel.retry() }
            } label: {
                Text("TRY AGAIN")
                    .font(IhsanFont.inscription)
                    .tracking(1.6)
                    .foregroundStyle(tokens.ink)
                    .padding(.horizontal, IhsanSpacing.lg)
                    .padding(.vertical, IhsanSpacing.md)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Repeats the nearby Apple Maps search")
        }
        .padding(.horizontal, IhsanSpacing.xl)
        .padding(.vertical, IhsanSpacing.lg)
        .frame(maxWidth: .infinity)
        .celestialPanel(tokens: tokens, cornerRadius: 18)
    }

    private func privacyNote(tokens: SkyPaletteTokens) -> some View {
        Text("SEARCHED IN APPLE MAPS · NOTHING SAVED")
            .font(IhsanFont.inscription)
            .tracking(1.4)
            .foregroundStyle(tokens.inkSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel("Search runs through Apple Maps. Results and location are not saved.")
    }

    private func openMapsToCurrentArea() {
        MKMapItem.forCurrentLocation().openInMaps()
    }
}

/// A quiet row-shaped placeholder. Reduce Motion keeps it static;
/// otherwise the panel breathes once per second without moving layout.
private struct MasjidLoadingState: View {
    let tokens: SkyPaletteTokens

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isLit = false

    var body: some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.md) {
            Text("SEARCHING APPLE MAPS")
                .font(IhsanFont.inscription)
                .tracking(1.6)
                .foregroundStyle(tokens.inkSecondary)

            ForEach(0..<4, id: \.self) { _ in
                VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
                    Capsule()
                        .fill(tokens.ink.opacity(0.16))
                        .frame(maxWidth: 220)
                        .frame(height: IhsanSpacing.sm)
                    Capsule()
                        .fill(tokens.inkSecondary.opacity(0.12))
                        .frame(maxWidth: 150)
                        .frame(height: IhsanSpacing.xs)
                }
                .padding(IhsanSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(reduceMotion ? 0.72 : (isLit ? 0.9 : 0.5))
                .celestialPanel(
                    tokens: tokens,
                    cornerRadius: IhsanSpacing.smallCardRadius
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isLit = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Searching Apple Maps for nearby masjids")
    }
}

#Preview("Nearby masjids") {
    MasjidFinderScreen(locationName: "Chicago")
}
