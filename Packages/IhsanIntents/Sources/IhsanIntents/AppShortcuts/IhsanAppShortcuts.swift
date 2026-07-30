import AppIntents

/// The consuming app target should import IhsanIntents from its @main file so
/// this AppShortcutsProvider is loaded and registered by the system.
public struct IhsanAppShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogPrayerIntent(),
            phrases: [
                "Log my \(\.$prayer) in \(.applicationName)",
                "Mark \(\.$prayer) as prayed in \(.applicationName)",
                "I prayed \(\.$prayer) in \(.applicationName)"
            ],
            shortTitle: "Log Prayer",
            systemImageName: "checkmark.circle.fill"
        )
        AppShortcut(
            intent: ToggleJamaahIntent(),
            phrases: [
                "Toggle jamāʿah for \(\.$prayer) in \(.applicationName)",
                "Mark \(\.$prayer) as jamāʿah in \(.applicationName)"
            ],
            shortTitle: "Toggle Jamāʿah",
            systemImageName: "person.3.fill"
        )
        AppShortcut(
            intent: OpenReflectionIntent(),
            phrases: [
                "Begin reflection in \(.applicationName)",
                "Start a reflection in \(.applicationName)",
                "Open my reflection in \(.applicationName)"
            ],
            shortTitle: "Begin Reflection",
            systemImageName: "book.closed.fill"
        )
        AppShortcut(
            intent: LogMakeupPrayerIntent(),
            phrases: [
                "Log a makeup prayer in \(.applicationName)",
                "I made up a prayer in \(.applicationName)",
                "Log \(\.$category) made up in \(.applicationName)"
            ],
            shortTitle: "Log Makeup Prayer",
            systemImageName: "arrow.uturn.backward"
        )
    }

    public static let shortcutTileColor: ShortcutTileColor = .grayBlue
}
