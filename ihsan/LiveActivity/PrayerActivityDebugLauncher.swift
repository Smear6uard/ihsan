#if DEBUG && canImport(ActivityKit) && os(iOS)
import ActivityKit
import Foundation
import IhsanCore

/// Simulator-only capture hook for the real ActivityKit surfaces.
///
/// `-IhsanDebugLiveActivity active|preAdhan|minimal` starts a stable
/// Isha fixture. `minimal` requests a second activity so the system
/// presents one of them in its minimal Dynamic Island state.
enum PrayerActivityDebugLauncher {
    static func launchIfRequested() async {
        guard let mode = DebugLaunch.value(after: "-IhsanDebugLiveActivity") else {
            return
        }

        for activity in Activity<PrayerActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        let now = Date()
        let isPreAdhan = mode == "preAdhan"
        let scheduledTime = now.addingTimeInterval(isPreAdhan ? 20 * 60 : -20 * 60)
        let windowEnd = now.addingTimeInterval(7 * 3_600)
        let attributes = PrayerActivityAttributes(
            prayer: .isha,
            scheduledTime: scheduledTime,
            windowEnd: windowEnd,
            timeZoneIdentifier: TimeZone.current.identifier,
            arabicName: Prayer.isha.displayNameArabic,
            englishName: Prayer.isha.displayNameEnglish
        )
        let state = PrayerActivityAttributes.ContentState(
            countdownPhase: isPreAdhan ? .preAdhan : .adhanWindow
        )

        _ = try? Activity.request(
            attributes: attributes,
            content: ActivityContent(state: state, staleDate: windowEnd),
            pushType: nil
        )

        if mode == "minimal" {
            let secondAttributes = PrayerActivityAttributes(
                prayer: .fajr,
                scheduledTime: scheduledTime,
                windowEnd: windowEnd,
                timeZoneIdentifier: TimeZone.current.identifier,
                arabicName: Prayer.fajr.displayNameArabic,
                englishName: Prayer.fajr.displayNameEnglish
            )
            _ = try? Activity.request(
                attributes: secondAttributes,
                content: ActivityContent(state: state, staleDate: windowEnd),
                pushType: nil
            )
        }
    }
}
#endif
