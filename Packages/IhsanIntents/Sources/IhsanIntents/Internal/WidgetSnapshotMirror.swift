import Foundation
import IhsanCore
import SwiftData
#if canImport(WidgetKit)
import WidgetKit
#endif

/// The intent funnel's optimistic write-back to the widget snapshot.
///
/// Every logging path in the product runs through the intents in this
/// package — the app's sheets, widget buttons, Siri, Shortcuts, the
/// watch. After a successful write, the funnel re-reads the affected
/// day's facts from the store it just wrote and mirrors them onto the
/// published snapshot, then asks WidgetKit to re-render. A widget
/// therefore reflects its own button press on the very next render,
/// and an app-side log reaches the home screen without waiting for
/// tomorrow's natural reload.
///
/// The mirror never *creates* truth: when no snapshot exists there is
/// nothing to update, and the reload simply lets the provider render
/// its invitation state.
@MainActor
enum WidgetSnapshotMirror {

    /// Mirror today's prayer logs onto the snapshot.
    static func reflectPrayerLogs(in context: ModelContext) {
        defer { requestReload() }
        guard
            let snapshot = WidgetSnapshotStore.read(),
            let timeZone = TimeZone(identifier: snapshot.timeZoneIdentifier)
        else { return }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let dayStart = snapshot.today.civilDayStart
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return }

        let descriptor = FetchDescriptor<PrayerLog>(
            predicate: #Predicate<PrayerLog> {
                $0.prayerDate >= dayStart && $0.prayerDate < dayEnd
            }
        )
        guard let logs = try? context.fetch(descriptor) else { return }

        WidgetSnapshotStore.mirrorLogs(
            loggedStatusByPrayerRaw: logs.reduce(into: [:]) { $0[$1.prayerRaw] = $1.statusRaw },
            jamaahByPrayerRaw: logs.reduce(into: [:]) { $0[$1.prayerRaw] = $1.withJamaah }
        )
    }

    /// Mirror the fasting fact for the snapshot's covered days.
    static func reflectFastLogs(in context: ModelContext) {
        defer { requestReload() }
        guard
            let snapshot = WidgetSnapshotStore.read(),
            let timeZone = TimeZone(identifier: snapshot.timeZoneIdentifier)
        else { return }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let stamps: [WidgetSnapshot.FastingStamp] = snapshot.fasting.map { stamp in
            let dayStart = stamp.civilDayStart
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                return stamp
            }
            let descriptor = FetchDescriptor<FastLog>(
                predicate: #Predicate<FastLog> {
                    $0.fastDate >= dayStart && $0.fastDate < dayEnd
                }
            )
            let hasFast = ((try? context.fetchCount(descriptor)) ?? 0) > 0
            return WidgetSnapshot.FastingStamp(
                civilDayStart: stamp.civilDayStart,
                isFasting: hasFast,
                isRamadan: stamp.isRamadan
            )
        }
        WidgetSnapshotStore.write(snapshot.replacingFasting(stamps))
    }

    /// Mirror the qadā remaining count after a Repair write.
    static func reflectQadaLedgers(in context: ModelContext) {
        defer { requestReload() }
        guard let snapshot = WidgetSnapshotStore.read() else { return }
        guard let settings = try? UserSettings.fetchOrCreate(in: context) else { return }

        let remaining: Int?
        if settings.qadaTrackingEnabled {
            let ledgers = (try? context.fetch(FetchDescriptor<QadaLedger>())) ?? []
            remaining = ledgers.reduce(0) { $0 + $1.remainingCount }
        } else {
            remaining = nil
        }
        WidgetSnapshotStore.write(snapshot.replacingQadaRemaining(remaining))
    }

    /// Ask WidgetKit to re-render everything. Safe from any process —
    /// the app, the widget extension running an interactive intent,
    /// or the watch extension.
    static func requestReload() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
