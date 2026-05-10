import SwiftUI
import IhsanCore
import IhsanDesignSystem
import IhsanIntents

struct RootTabView: View {
    @State private var selectedTab: Tab = .today
    @Environment(\.scenePhase) private var scenePhase

    enum Tab: Hashable {
        case today, trajectory, reflection, settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayScreen()
                .tabItem { Label("Today", systemImage: "calendar") }
                .tag(Tab.today)

            TrajectoryScreen()
                .tabItem { Label("Trajectory", systemImage: "chart.dots.scatter") }
                .tag(Tab.trajectory)

            ReflectionScreen()
                .tabItem { Label("Reflection", systemImage: "book.closed") }
                .tag(Tab.reflection)

            ComingSoonScreen(title: "Settings")
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .tint(IhsanColor.textPrimary)
        .task {
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
            // Shortcut invocation, the flag is already set — re-check.
            if newPhase == .active, hasFreshReflectionDeeplink() {
                selectedTab = .reflection
            }
        }
    }

    /// Reads the App Group UserDefaults flag without clearing it. The
    /// Reflection screen is the consumer that clears the flag once it
    /// has applied input focus — this lets both views observe the same
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

private struct ComingSoonScreen: View {
    let title: String

    var body: some View {
        VStack(spacing: IhsanSpacing.sm) {
            Text(title)
                .font(IhsanFont.title)
                .foregroundStyle(IhsanColor.textPrimary)
            Text("Coming soon")
                .font(IhsanFont.smallCaps)
                .foregroundStyle(IhsanColor.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ihsanBackground()
    }
}
