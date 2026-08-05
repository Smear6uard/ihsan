import Foundation
import IhsanCore
import IhsanLocation
import IhsanPrayerTimes
import OSLog
import SwiftData
import WidgetKit

/// The host app's side of the widget data spine.
///
/// One publisher, called from every path that changes what a widget
/// should show: the Today snapshot refresh, the log/fast/qadā intent
/// funnel (via `WidgetSnapshotMirror` in IhsanIntents for the states,
/// then a reload here), pause transitions, and every settings change
/// that moves a prayer time. Widgets never compute — they render the
/// last truth published here, and a truth that goes 36 hours
/// unrefreshed becomes the quiet "Open Ihsan" invitation rather than
/// a guess.
@MainActor
enum WidgetSnapshotService {
    private static let logger = Logger(
        subsystem: "com.sameerstudios.ihsan",
        category: "WidgetSnapshotService"
    )

    /// Publish from facts the Today refresh already has in hand —
    /// no second location fix, no second calculation.
    static func publish(
        place: LocatedPlace,
        provider: any PrayerTimesProviding,
        settings: UserSettings,
        modelContext: ModelContext,
        now: Date
    ) {
        do {
            let facts = try facts(
                at: now,
                timeZone: place.timeZone,
                settings: settings,
                modelContext: modelContext,
                provider: provider,
                coordinates: place.coordinates
            )
            let snapshot = try WidgetSnapshotBuilder.build(
                at: now,
                cityName: place.cityName,
                qiblaBearingDegrees: QiblaEngine(
                    latitude: place.coordinates.latitude,
                    longitude: place.coordinates.longitude
                ).qiblaBearing,
                provider: provider,
                coordinates: place.coordinates,
                timeZone: place.timeZone,
                calculationMethod: settings.calculationMethod,
                madhab: settings.madhab,
                highLatitudeRule: settings.highLatitudeRule,
                tuning: settings.calculationTuning,
                facts: facts
            )
            WidgetSnapshotStore.write(snapshot)
        } catch {
            // A failed publish never clears the last good snapshot —
            // yesterday's truth with the 36-hour guard beats no truth.
            logger.error("Widget snapshot publish failed: \(String(describing: error))")
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Publish after a mutation that changes prayer times or day
    /// facts (calculation settings, pause transitions, Hijri offset,
    /// travel). Fetches its own location the same way the
    /// notification rebuild does; quietly keeps the previous snapshot
    /// when no fix is available.
    static func republish(using modelContext: ModelContext, now: Date = NowProvider.active.now()) {
        Task {
            guard let place = try? await CoreLocationCoordinator.shared.currentPlace() else {
                // Times cannot move without a place; day facts might
                // have (pause, fast, Hijri offset) — refresh those on
                // the existing snapshot so the truth stays whole.
                refreshFacts(using: modelContext, now: now)
                return
            }
            guard let settings = try? UserSettings.fetchOrCreate(in: modelContext) else {
                WidgetCenter.shared.reloadAllTimelines()
                return
            }
            publish(
                place: place,
                provider: AdhanPrayerTimesProvider(),
                settings: settings,
                modelContext: modelContext,
                now: now
            )
        }
    }

    /// Replace the day facts on the stored snapshot without touching
    /// its times — the pause/fast/log mirrors ride this when no
    /// location fix is available.
    static func refreshFacts(using modelContext: ModelContext, now: Date = NowProvider.active.now()) {
        defer { WidgetCenter.shared.reloadAllTimelines() }
        guard
            let snapshot = WidgetSnapshotStore.read(),
            let timeZone = TimeZone(identifier: snapshot.timeZoneIdentifier),
            let settings = try? UserSettings.fetchOrCreate(in: modelContext)
        else { return }
        guard let facts = try? facts(
            coveringDays: [snapshot.today.civilDayStart, snapshot.tomorrow.civilDayStart],
            timeZone: timeZone,
            settings: settings,
            modelContext: modelContext
        ) else { return }
        WidgetSnapshotStore.write(
            snapshot
                .replacingFasting(facts.fasting)
                .replacingLogs(
                    loggedStatusByPrayerRaw: facts.loggedStatusByPrayerRaw,
                    jamaahByPrayerRaw: facts.jamaahByPrayerRaw
                )
                .replacingQadaRemaining(facts.qadaRemaining)
        )
    }

    // MARK: - Facts

    private static func facts(
        at now: Date,
        timeZone: TimeZone,
        settings: UserSettings,
        modelContext: ModelContext,
        provider: any PrayerTimesProviding,
        coordinates: Coordinates
    ) throws -> WidgetSnapshotBuilder.Facts {
        let covered = try WidgetSnapshotBuilder.coveredDays(
            at: now,
            provider: provider,
            coordinates: coordinates,
            timeZone: timeZone,
            calculationMethod: settings.calculationMethod,
            madhab: settings.madhab,
            highLatitudeRule: settings.highLatitudeRule,
            tuning: settings.calculationTuning
        )
        return try facts(
            coveringDays: [covered.today, covered.tomorrow],
            timeZone: timeZone,
            settings: settings,
            modelContext: modelContext
        )
    }

    private static func facts(
        coveringDays days: [Date],
        timeZone: TimeZone,
        settings: UserSettings,
        modelContext: ModelContext
    ) throws -> WidgetSnapshotBuilder.Facts {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let offset = settings.hijriCalendarOffsetDays

        let hijri: [WidgetSnapshot.HijriStamp] = days.map { day in
            // Noon avoids any edge behavior at the civil boundary.
            let reference = calendar.date(byAdding: .hour, value: 12, to: day) ?? day
            let components = HijriConverter.components(
                for: reference, offsetDays: offset, timeZone: timeZone
            )
            let significance = HijriConverter.significance(of: components).first
            return WidgetSnapshot.HijriStamp(
                civilDayStart: day,
                day: components.day,
                monthName: components.monthName,
                year: components.year,
                significantLine: significance?.inscription(for: components),
                isRamadan: components.month == RamadanContext.ramadanMonth
            )
        }

        let fasting: [WidgetSnapshot.FastingStamp] = try days.enumerated().map { index, day in
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            let descriptor = FetchDescriptor<FastLog>(
                predicate: #Predicate<FastLog> {
                    $0.fastDate >= day && $0.fastDate < dayEnd
                }
            )
            let hasFast = try modelContext.fetchCount(descriptor) > 0
            return WidgetSnapshot.FastingStamp(
                civilDayStart: day,
                isFasting: hasFast,
                isRamadan: hijri[index].isRamadan
            )
        }

        // Logs belong to the first covered day — "today" in the
        // snapshot's bracket sense.
        var logged: [String: String] = [:]
        var jamaah: [String: Bool] = [:]
        if let today = days.first {
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: today) ?? today
            let descriptor = FetchDescriptor<PrayerLog>(
                predicate: #Predicate<PrayerLog> {
                    $0.prayerDate >= today && $0.prayerDate < dayEnd
                }
            )
            for log in try modelContext.fetch(descriptor) {
                logged[log.prayerRaw] = log.statusRaw
                jamaah[log.prayerRaw] = log.withJamaah
            }
        }

        let pauses = try modelContext.fetch(FetchDescriptor<PauseInterval>())
        let activePause = pauses.first(where: \.isActive)

        let qadaRemaining: Int?
        if settings.qadaTrackingEnabled {
            let ledgers = try modelContext.fetch(FetchDescriptor<QadaLedger>())
            qadaRemaining = ledgers.reduce(0) { $0 + $1.remainingCount }
        } else {
            qadaRemaining = nil
        }

        return WidgetSnapshotBuilder.Facts(
            hijri: hijri,
            fasting: fasting,
            loggedStatusByPrayerRaw: logged,
            jamaahByPrayerRaw: jamaah,
            isPaused: activePause != nil,
            pauseExpectedEnd: activePause?.expectedEndDate,
            qadaRemaining: qadaRemaining
        )
    }
}
