import SwiftUI
import SwiftData
import IhsanCore
import IhsanDesignSystem
import IhsanIntents

/// The app's four surfaces.
enum AppTab: Int, CaseIterable, Hashable {
    case today
    case trajectory
    case reflection
    case settings
}

/// The root tab scaffold — the NATIVE iOS 26 tab bar, exactly as the
/// system ships it: a floating Liquid Glass capsule with real content
/// lensing beneath, the system's own selection treatment, and
/// `.tabBarMinimizeBehavior(.onScrollDown)` so the bar recedes while
/// the user reads and returns on scroll-up or tap.
///
/// Customization discipline: the linework glyphs and labels, plus one
/// warm tint through the sanctioned `.tint` API. No custom
/// backgrounds, shadows, or materials on or behind the bar; no custom
/// selection indicator — the old sliding underline died with the
/// custom bar and must not be recreated. Reduce Motion / Reduce
/// Transparency behavior now comes from the system.
struct RootTabView: View {
    @State private var selectedTab: AppTab = {
        // `-IhsanDebugTab trajectory|reflection|settings` — screenshot
        // harness; opens directly on a secondary page.
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-IhsanDebugTab"),
           index + 1 < arguments.count {
            switch arguments[index + 1] {
            case "trajectory": return .trajectory
            case "reflection": return .reflection
            case "settings": return .settings
            default: break
            }
        }
        #endif
        return .today
    }()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    /// The tasbīḥ instrument rides over whichever tab is up — entered
    /// from the logged card's quiet link or the Siri/Shortcut intent.
    @State private var isDhikrPresented = ProcessInfo.processInfo
        .arguments.contains("-IhsanDebugPresentDhikr")

    #if DEBUG
    /// `-IhsanDebugWidgetGallery` — the widget faces at their real
    /// sizes, so the phase gate has a picture of a surface no test
    /// harness can place on a home screen.
    @State private var isWidgetGalleryPresented = ProcessInfo.processInfo
        .arguments.contains("-IhsanDebugWidgetGallery")
    #endif

    var body: some View {
        // The glyphs are the app's own linework set (`TabGlyphs`),
        // rendered as template images — never SF Symbols.
        TabView(selection: $selectedTab) {
            SwiftUI.Tab(value: AppTab.today) {
                TodayScreen()
            } label: {
                Label { Text("Today") } icon: { Image(uiImage: TabGlyphs.today) }
            }
            SwiftUI.Tab(value: AppTab.trajectory) {
                TrajectoryScreen()
            } label: {
                Label { Text("Path") } icon: { Image(uiImage: TabGlyphs.path) }
            }
            SwiftUI.Tab(value: AppTab.reflection) {
                ReflectionScreen()
            } label: {
                Label { Text("Reflect") } icon: { Image(uiImage: TabGlyphs.reflect) }
            }
            SwiftUI.Tab(value: AppTab.settings) {
                SettingsScreen()
            } label: {
                Label { Text("Set") } icon: { Image(uiImage: TabGlyphs.set) }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        // The one sanctioned accent: the manuscript's warm gold on the
        // selected item; everything else is the system's own glass.
        .tint(IhsanColor.gold)
        .onChange(of: selectedTab) { _, _ in
            Haptics.impact(.medium)
        }
        .task {
            Haptics.prepareAll()
            // Cold-launch: the OpenReflectionIntent has already written
            // a flag into App Group UserDefaults; switch to Reflection
            // before the user sees the default Today tab.
            if hasFreshReflectionDeeplink() {
                selectedTab = .reflection
            }
            if hasFreshDeeplink(forKey: StartTasbihIntent.deeplinkUserDefaultsKey) {
                isDhikrPresented = true
            }
            runMissedFlowSweep()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: OpenReflectionIntent.inAppNotificationName
            )
        ) { _ in
            // Warm in-app: the user tapped "Begin" on the Today screen,
            // the intent ran inline, and the notification fires here.
            selectedTab = .reflection
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: StartTasbihIntent.inAppNotificationName
            )
        ) { _ in
            isDhikrPresented = true
        }
        .onChange(of: scenePhase) { _, newPhase in
            // If the app comes back to foreground because of a Siri /
            // Shortcut invocation, the flag is already set; re-check.
            if newPhase == .active {
                if hasFreshReflectionDeeplink() {
                    selectedTab = .reflection
                }
                if hasFreshDeeplink(forKey: StartTasbihIntent.deeplinkUserDefaultsKey) {
                    isDhikrPresented = true
                }
                runMissedFlowSweep()
            }
        }
        .fullScreenCover(isPresented: $isDhikrPresented) {
            DhikrScreen(onDismiss: {
                isDhikrPresented = false
                clearDeeplink(forKey: StartTasbihIntent.deeplinkUserDefaultsKey)
            })
        }
        #if DEBUG
        .fullScreenCover(isPresented: $isWidgetGalleryPresented) {
            WidgetFaceGallery()
        }
        #endif
    }

    /// Foreground reconciliation for the makeup ledger: first heal any
    /// drift from widget or intent writes made while backgrounded (the log
    /// is the source of truth), then flow silent prayers from ended days if
    /// the user chose that at setup. Both are idempotent and pause-aware,
    /// so calling on every foreground is safe.
    private func runMissedFlowSweep() {
        // Both are best-effort and idempotent: a failure here is
        // retried on the next foreground, and neither has a result the
        // caller can act on.
        _ = try? QadaLedgerWriter().reconcile(in: modelContext)
        _ = try? QadaMissedFlowSweep().sweep(in: modelContext)
    }

    /// Reads the App Group UserDefaults flag without clearing it. The
    /// Reflection screen is the consumer that clears the flag once it
    /// has applied input focus; this lets both views observe the same
    /// signal from their respective lifecycles.
    private func hasFreshReflectionDeeplink() -> Bool {
        hasFreshDeeplink(forKey: OpenReflectionIntent.deeplinkUserDefaultsKey)
    }

    private func hasFreshDeeplink(forKey key: String) -> Bool {
        guard let defaults = UserDefaults(
            suiteName: IhsanModelContainerFactory.appGroupIdentifier
        ),
        let stored = defaults.object(forKey: key) as? Double
        else {
            return false
        }
        let age = Date.now.timeIntervalSince1970 - stored
        return age >= 0 && age <= 60
    }

    private func clearDeeplink(forKey key: String) {
        UserDefaults(suiteName: IhsanModelContainerFactory.appGroupIdentifier)?
            .removeObject(forKey: key)
    }
}
