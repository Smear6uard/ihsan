import SwiftUI
import IhsanCore
import IhsanDesignSystem
import IhsanIntents

struct RootTabView: View {
    @State private var selectedTab: Tab = .today
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottom) {
            tabContent
                .safeAreaInset(edge: .bottom) {
                    Color.clear
                        .frame(height: IhsanSpacing.tabBarHeight + IhsanSpacing.xl)
                        .allowsHitTesting(false)
                }

            CustomTabBar(selectedTab: $selectedTab)
                .padding(.horizontal, IhsanSpacing.md)
                .padding(.bottom, IhsanSpacing.sm)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: selectedTab)
        .task {
            Haptics.prepareAll()
            // Cold-launch: the OpenReflectionIntent has already written
            // a flag into App Group UserDefaults; switch to Reflection
            // before the user sees the default Today tab.
            if hasFreshReflectionDeeplink() {
                selectedTab = .reflection
            }
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
        .onChange(of: scenePhase) { _, newPhase in
            // If the app comes back to foreground because of a Siri /
            // Shortcut invocation, the flag is already set; re-check.
            if newPhase == .active, hasFreshReflectionDeeplink() {
                selectedTab = .reflection
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .today:
            TodayScreen()
        case .trajectory:
            TrajectoryScreen()
        case .reflection:
            ReflectionScreen()
        case .settings:
            SettingsScreen()
        }
    }

    /// Reads the App Group UserDefaults flag without clearing it. The
    /// Reflection screen is the consumer that clears the flag once it
    /// has applied input focus; this lets both views observe the same
    /// signal from their respective lifecycles.
    private func hasFreshReflectionDeeplink() -> Bool {
        guard let defaults = UserDefaults(
            suiteName: IhsanModelContainerFactory.appGroupIdentifier
        ),
        let stored = defaults.object(forKey: OpenReflectionIntent.deeplinkUserDefaultsKey) as? Double
        else {
            return false
        }
        let age = Date.now.timeIntervalSince1970 - stored
        return age >= 0 && age <= 60
    }
}
