import Foundation
import IhsanCore

// The one way to read or write a prayer's sound.
//
// Three stores could disagree about whether a prayer makes a noise: the
// per-prayer JSON blob, the older per-prayer mute column, and the
// notification-enabled flag. Every surface goes through the accessors
// here, which keep the first two in step, so "silent" means the same
// thing whether it was set today or two builds ago.

public extension UserSettings {
    /// Every prayer's notification configuration, in prayer order, with
    /// the neutral defaults filled in for anything missing.
    var prayerNotificationConfigs: [PrayerNotificationConfig] {
        let decoded = (try? JSONDecoder().decode(
            [PrayerNotificationConfig].self,
            from: Data(prayerNotificationsConfigJSON.utf8)
        )) ?? []

        return Prayer.allCases.map { prayer in
            decoded.first { $0.prayer == prayer } ?? PrayerNotificationConfig(prayer: prayer)
        }
    }

    func notificationConfig(for prayer: Prayer) -> PrayerNotificationConfig {
        prayerNotificationConfigs.first { $0.prayer == prayer }
            ?? PrayerNotificationConfig(prayer: prayer)
    }

    func setNotificationConfig(_ config: PrayerNotificationConfig) {
        var configs = prayerNotificationConfigs
        if let index = configs.firstIndex(where: { $0.prayer == config.prayer }) {
            configs[index] = config
        } else {
            configs.append(config)
        }
        // Sorted keys so a round trip is byte-stable across processes.
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        if let data = try? encoder.encode(configs),
           let json = String(data: data, encoding: .utf8) {
            prayerNotificationsConfigJSON = json
        }
    }

    /// What this prayer sounds like. The legacy mute column wins when
    /// it is off, so a preference set before the vocabulary changed is
    /// still honoured.
    func sound(for prayer: Prayer) -> AdhanSoundCatalog {
        guard adhanEnabled(for: prayer) else { return .silent }
        return AdhanSoundCatalog(userChoice: notificationConfig(for: prayer).athanSoundName)
    }

    /// Sets the sound, writing the legacy mute column alongside it so
    /// the two can never disagree.
    func setSound(_ sound: AdhanSoundCatalog, for prayer: Prayer) {
        var config = notificationConfig(for: prayer)
        config.athanSoundName = sound.rawValue
        setNotificationConfig(config)
        setAdhanEnabled(sound != .silent, for: prayer)
    }

    func isTimeSensitive(_ prayer: Prayer) -> Bool {
        notificationConfig(for: prayer).isTimeSensitive
    }

    func setTimeSensitive(_ isTimeSensitive: Bool, for prayer: Prayer) {
        var config = notificationConfig(for: prayer)
        config.isTimeSensitive = isTimeSensitive
        setNotificationConfig(config)
    }

    func notificationEnabled(for prayer: Prayer) -> Bool {
        notificationConfig(for: prayer).isEnabled
    }

    func setNotificationEnabled(_ isEnabled: Bool, for prayer: Prayer) {
        var config = notificationConfig(for: prayer)
        config.isEnabled = isEnabled
        setNotificationConfig(config)
    }
}
