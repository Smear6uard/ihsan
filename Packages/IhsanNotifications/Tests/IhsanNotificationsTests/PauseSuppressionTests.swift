import Foundation
import IhsanCore
import Testing
@testable import IhsanNotifications

@Test
func activePauseSuppressesAllPrayerNotifications() {
    let userSettings = UserSettings()
    userSettings.notificationsEnabled = true

    let settings = NotificationScheduleSettings(userSettings: userSettings, isPaused: true)

    #expect(settings.notificationsEnabled == true)
    #expect(settings.prayerNotificationsSuppressed == true)
}

@Test
func withoutAPauseTheUsersChoiceStands() {
    let enabled = UserSettings()
    enabled.notificationsEnabled = true
    #expect(NotificationScheduleSettings(userSettings: enabled, isPaused: false).notificationsEnabled == true)
    #expect(NotificationScheduleSettings(userSettings: enabled, isPaused: false).prayerNotificationsSuppressed == false)

    let disabled = UserSettings()
    disabled.notificationsEnabled = false
    #expect(NotificationScheduleSettings(userSettings: disabled, isPaused: false).notificationsEnabled == false)
}

/// Per-prayer overrides survive a pause untouched — suppression works at
/// the schedule level, so ending the pause restores exactly the user's
/// prior per-prayer configuration.
@Test
func perPrayerPreferencesAreUntouchedByAPause() {
    let userSettings = UserSettings()
    var configs = Prayer.allCases.map { PrayerNotificationConfig(prayer: $0) }
    configs[0].isEnabled = false
    let data = (try? JSONEncoder().encode(configs)) ?? Data()
    userSettings.prayerNotificationsConfigJSON = String(decoding: data, as: UTF8.self)

    let paused = NotificationScheduleSettings(userSettings: userSettings, isPaused: true)
    let resumed = NotificationScheduleSettings(userSettings: userSettings, isPaused: false)

    #expect(paused.preference(for: .fajr).isEnabled == false)
    #expect(paused.preference(for: .dhuhr).isEnabled == true)
    #expect(paused.prayerPreferences == resumed.prayerPreferences)
}
