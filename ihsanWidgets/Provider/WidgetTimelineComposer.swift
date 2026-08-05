import Foundation
import IhsanCore
import IhsanPrayerTimes
import WidgetKit

/// Turns the published snapshot into the widget timeline.
///
/// Entries land on every boundary a face can change at: each prayer
/// window edge and sunrise for both covered days, solar midnight
/// (nisf al-layl) and the last-third start of both nights, the Hijri
/// day rollovers, and a lattice of sky keyframes between them so a
/// widget's ground drifts with the real sky instead of freezing at the
/// last prayer boundary and jump-cutting at the next. Suhoor and iftar
/// are Fajr and Maghrib — already boundaries.
///
/// The final entry is always the invitation at the moment the
/// snapshot's truth runs out (its terminal Fajr or the 36-hour age
/// rule, whichever is sooner). If every requested reload after that is
/// deferred forever, the last thing on the lock screen is still a
/// dignified face — never a stale time, never a blank.
struct WidgetTimelineComposer {
    let snapshot: WidgetSnapshot?

    init(snapshot: WidgetSnapshot? = WidgetSnapshotStore.read()) {
        self.snapshot = snapshot
    }

    /// Sky keyframe cadence. SkyPhase drifts slowly enough that 45
    /// minutes is invisible at a glance, and a two-day timeline stays
    /// under ~90 entries.
    private static let skyKeyframeInterval: TimeInterval = 45 * 60

    // MARK: - Entries

    func entry(at instant: Date) -> PrayerTimelineEntry {
        guard let snapshot else {
            return PrayerTimelineEntry(
                date: instant,
                content: .invitation(.init(reason: .neverPublished))
            )
        }
        guard
            snapshot.freshness(at: instant) == .fresh,
            let schedule = snapshot.resolverSchedule(containing: instant)
        else {
            return PrayerTimelineEntry(
                date: instant,
                content: .invitation(.init(reason: .stale))
            )
        }

        let resolution = PrayerStateResolver.resolve(prayerTimes: schedule, now: instant)
        PrayerResolverDiagnostics.emit(
            prayerTimes: schedule,
            now: instant,
            resolution: resolution,
            surface: "ios.widget"
        )

        let currentWindow: ClosedRange<Date>?
        if case .current(let startedAt, let endsAt) = resolution.windowState,
           startedAt <= endsAt {
            currentWindow = startedAt...endsAt
        } else {
            currentWindow = nil
        }

        // The strip shows the bracket day's five prayers. Logged
        // states only exist for the snapshot's "today" — tomorrow's
        // slots are simply unlogged, which is the truth.
        let table = schedule
        let isToday = table.fajr.scheduledTime == snapshot.today.fajr
        let slots = table.dayPrayerTimes.map { prayerTime in
            PrayerTimelineEntry.LiveDay.PrayerSlot(
                prayer: prayerTime.prayer,
                scheduledTime: prayerTime.scheduledTime,
                status: isToday
                    ? snapshot.loggedStatusByPrayerRaw[prayerTime.prayer.rawValue]
                        .flatMap(PrayerStatus.init(rawValue:))
                    : nil,
                withJamaah: isToday
                    ? (snapshot.jamaahByPrayerRaw[prayerTime.prayer.rawValue] ?? false)
                    : false
            )
        }

        var nextOccurrences: [String: Date] = [:]
        for prayer in Prayer.allCases {
            let candidates = [
                time(of: prayer, in: snapshot.today),
                time(of: prayer, in: snapshot.tomorrow),
            ]
            nextOccurrences[prayer.rawValue] = candidates.first { $0 >= instant }
        }

        return PrayerTimelineEntry(
            date: instant,
            content: .live(PrayerTimelineEntry.LiveDay(
                nextPrayer: resolution.nextPrayer.prayer,
                nextPrayerTime: resolution.countdownTarget,
                currentPrayer: resolution.currentPrayer?.prayer,
                currentWindow: currentWindow,
                slots: slots,
                sunrise: table.sunrise,
                cityName: snapshot.cityName,
                timeZoneIdentifier: snapshot.timeZoneIdentifier,
                qiblaBearingDegrees: snapshot.qiblaBearingDegrees,
                night: snapshot.relevantNight(at: instant),
                hijri: snapshot.hijriStamp(at: instant),
                fasting: snapshot.fastingStamp(at: instant),
                isPaused: snapshot.isPaused,
                qadaRemaining: snapshot.qadaRemaining,
                nextOccurrenceByPrayerRaw: nextOccurrences
            ))
        )
    }

    private func time(of prayer: Prayer, in table: WidgetSnapshot.DayTable) -> Date {
        switch prayer {
        case .fajr: table.fajr
        case .dhuhr: table.dhuhr
        case .asr: table.asr
        case .maghrib: table.maghrib
        case .isha: table.isha
        }
    }

    // MARK: - Timeline

    func timeline(from now: Date) -> Timeline<PrayerTimelineEntry> {
        guard let snapshot, snapshot.freshness(at: now) == .fresh else {
            // Nothing to show. The app's next publish triggers a
            // reload; the hourly retry below is only a safety net for
            // a publish this process never hears about.
            return Timeline(
                entries: [entry(at: now)],
                policy: .after(now.addingTimeInterval(3_600))
            )
        }

        let truthEnds = min(
            snapshot.dayAfterTomorrowFajr,
            snapshot.writtenAt.addingTimeInterval(WidgetSnapshot.maximumAge)
        )

        var boundaries: Set<Date> = []
        for table in [snapshot.today, snapshot.tomorrow] {
            boundaries.formUnion([
                table.fajr, table.sunrise, table.dhuhr,
                table.asr, table.maghrib, table.isha,
            ])
        }
        for night in [snapshot.tonight, snapshot.tomorrowNight] {
            boundaries.formUnion([night.nisfAlLayl, night.lastThirdStart])
        }
        boundaries.formUnion(hijriRollovers(after: now, until: truthEnds))

        // Sky keyframes between the boundaries, so the ground drifts
        // rather than jump-cuts.
        var keyframe = now.addingTimeInterval(Self.skyKeyframeInterval)
        while keyframe < truthEnds {
            boundaries.insert(keyframe)
            keyframe = keyframe.addingTimeInterval(Self.skyKeyframeInterval)
        }

        let instants = [now] + boundaries
            .filter { $0 > now && $0 < truthEnds }
            .sorted()

        var entries = instants.map(entry(at:))
        // The terminal invitation: whatever happens to every reload
        // after this moment, no face ever shows expired truth.
        entries.append(PrayerTimelineEntry(
            date: truthEnds,
            content: .invitation(.init(reason: .stale))
        ))

        return Timeline(entries: entries, policy: .after(truthEnds))
    }

    /// Civil midnights in the place timezone — the Hijri layer's day
    /// boundary in this app.
    private func hijriRollovers(after now: Date, until end: Date) -> [Date] {
        guard
            let snapshot,
            let timeZone = TimeZone(identifier: snapshot.timeZoneIdentifier)
        else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        var rollovers: [Date] = []
        var cursor = calendar.startOfDay(for: now)
        for _ in 0..<3 {
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            if next > now && next < end { rollovers.append(next) }
            cursor = next
        }
        return rollovers
    }
}
