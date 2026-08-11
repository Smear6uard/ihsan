import Foundation
import IhsanCore
import IhsanNotifications
import SwiftData
import UIKit
import UserNotifications

/// What happens when a prayer notification arrives, and when someone
/// acts on one.
///
/// Two jobs:
///
///   * register the prayer category so every prayer notification
///     carries a "Play the adhan" action — the full recording is longer
///     than a notification tone may be, so hearing it always means the
///     app running;
///   * honour the person's per-prayer sound choice when a notification
///     lands while the app is already open, instead of letting iOS
///     decide.
@MainActor
final class PrayerNotificationResponder: NSObject {
    static let shared = PrayerNotificationResponder()

    override private init() { super.init() }

    /// Called once at launch. Registering the delegate before any
    /// notification can be delivered is what makes a cold launch from a
    /// tapped banner behave the same as a warm one.
    func install() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        let play = UNNotificationAction(
            identifier: NotificationCategory.playAdhanAction,
            title: "Play the adhan",
            options: [.foreground]
        )
        let prayer = UNNotificationCategory(
            identifier: NotificationCategory.prayer,
            actions: [play],
            intentIdentifiers: [],
            options: []
        )
        let adhkar = UNNotificationCategory(
            identifier: NotificationCategory.adhkar,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([prayer, adhkar])
    }

    private var settings: UserSettings? {
        guard let container = try? IhsanSharedModelContainer.shared.container() else { return nil }
        return try? UserSettings.fetchOrCreate(in: ModelContext(container))
    }

    private var playsInSilentMode: Bool {
        settings?.adhanPlaysInSilentMode ?? false
    }

    private func soundChoice(for prayer: Prayer) -> AdhanSoundCatalog {
        settings?.sound(for: prayer) ?? .chime
    }

    nonisolated private func prayer(from userInfo: [AnyHashable: Any]) -> Prayer? {
        (userInfo[ScheduledNotificationUserInfoKey.prayer] as? String)
            .flatMap(Prayer.init(rawValue:))
    }

    nonisolated private func adhkarCategory(from userInfo: [AnyHashable: Any]) -> AdhkarCategory? {
        (userInfo[ScheduledNotificationUserInfoKey.adhkarCategory] as? String)
            .flatMap(AdhkarCategory.init(rawValue:))
    }
}

extension PrayerNotificationResponder: UNUserNotificationCenterDelegate {
    /// A prayer arriving while the app is open still shows its banner.
    /// Whether it also makes a sound is the person's per-prayer choice,
    /// not a default: a prayer set to silent stays silent even here.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let userInfo = notification.request.content.userInfo
        guard let prayer = prayer(from: userInfo) else {
            return [.banner, .list]
        }
        let choice = await soundChoice(for: prayer)
        return choice == .silent ? [.banner, .list] : [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        if let category = adhkarCategory(from: userInfo) {
            guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }
            await MainActor.run {
                AdhkarNotificationRoute.shared.pendingCategory = category
            }
            return
        }
        guard let prayer = prayer(from: userInfo) else { return }

        switch response.actionIdentifier {
        case NotificationCategory.playAdhanAction:
            await MainActor.run {
                AdhanPlayer.shared.play(overridesSilentSwitch: playsInSilentMode)
            }
        case UNNotificationDefaultActionIdentifier:
            // A plain tap opens Today on this prayer. It does not start
            // audio on its own — hearing the adhan is something a
            // person asks for, not something a tap does to a room.
            await MainActor.run {
                PrayerNotificationRoute.shared.pendingPrayer = prayer
            }
        default:
            break
        }
    }
}

/// Where a tapped notification wants the app to go. Today reads and
/// clears this; nothing else writes it.
@MainActor
@Observable
final class PrayerNotificationRoute {
    static let shared = PrayerNotificationRoute()
    var pendingPrayer: Prayer?

    private init() {}

    func consume() -> Prayer? {
        defer { pendingPrayer = nil }
        return pendingPrayer
    }
}

/// Where a tapped remembrance reminder wants the app to go. Today
/// consumes this and opens the requested set directly.
@MainActor
@Observable
final class AdhkarNotificationRoute {
    static let shared = AdhkarNotificationRoute()
    var pendingCategory: AdhkarCategory?

    private init() {}

    func consume() -> AdhkarCategory? {
        defer { pendingCategory = nil }
        return pendingCategory
    }
}
