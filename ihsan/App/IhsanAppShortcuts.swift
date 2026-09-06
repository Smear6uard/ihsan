import AppIntents
import IhsanIntents

/// The app's App Shortcuts — the phrases Siri and the Shortcuts app
/// offer without setup.
///
/// This lives in the app target on purpose. The intents themselves are
/// defined in `IhsanIntents` and are extracted from that package just
/// fine, but App Shortcut phrases are read from the app's own binary
/// at build time: a provider that lives only in a package yields a
/// metadata file with no phrases at all, and nothing warns. Every
/// intent named here is one of the package's single-funnel intents.
struct IhsanAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
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
            intent: StartTasbihIntent(),
            phrases: [
                "Start tasbīḥ in \(.applicationName)",
                "Begin tasbīḥ in \(.applicationName)",
                "Start dhikr in \(.applicationName)"
            ],
            shortTitle: "Start Tasbīḥ",
            systemImageName: "circle.grid.cross"
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

    static let shortcutTileColor: ShortcutTileColor = .grayBlue
}
