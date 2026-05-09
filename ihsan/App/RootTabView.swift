import SwiftUI
import IhsanDesignSystem

struct RootTabView: View {
    @State private var selectedTab: Tab = .today

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

            ComingSoonScreen(title: "Reflection")
                .tabItem { Label("Reflection", systemImage: "book.closed") }
                .tag(Tab.reflection)

            ComingSoonScreen(title: "Settings")
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .tint(IhsanColor.textPrimary)
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
