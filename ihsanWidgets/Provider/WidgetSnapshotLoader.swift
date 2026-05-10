import Foundation
import IhsanCore
import IhsanPrayerTimes
import SwiftData

/// Bridges the live shared SwiftData store + App Group location cache
/// into a series of `PrayerTimelineEntry` snapshots suitable for the
/// timeline.
///
/// Pinned to `@MainActor` because both `UserSettings.fetchOrCreate(...)`
/// and SwiftData's `ModelContext` operate on the main actor. The widget
/// extension is a short-lived process; opening a container, fetching,
/// and discarding all happens within a single timeline-build call.
@MainActor
struct WidgetSnapshotLoader {
    let prayerTimesProvider: any PrayerTimesProviding

    init(prayerTimesProvider: any PrayerTimesProviding = AdhanPrayerTimesProvider()) {
        self.prayerTimesProvider = prayerTimesProvider
    }

    /// Builds the entry sequence for the next ~36 hours starting at
    /// `referenceDate`. The first entry is "now" and subsequent entries
    /// land exactly at each prayer transition so the widget's "next
    /// prayer" advances precisely as time crosses each scheduled
    /// boundary. The last entry is tomorrow's Fajr — when the timeline
    /// reloads at that moment we recompute the next day's transitions.
    func entries(starting referenceDate: Date) -> [PrayerTimelineEntry] {
        // Location: bail to a "missing location" entry rather than
        // showing stale or invented prayer times.
        guard let location = WidgetLocationCache.current() else {
            return [missingLocationEntry(at: referenceDate)]
        }

        // Open the shared SwiftData store ONCE per timeline build to
        // minimize widget energy use. If CloudKit isn't yet initialized
        // we fall back to default calculation settings and an empty log
        // map so the widget still renders something.
        let calculation: (CalculationMethodChoice, MadhabChoice, HighLatitudeRule)
        let logsByPrayerRaw: [String: String]
        if let context = openSharedContext() {
            calculation = readCalculation(from: context) ?? (.isna, .standard, .middleOfNight)
            logsByPrayerRaw = readTodaysLogs(at: referenceDate, from: context)
        } else {
            calculation = (.isna, .standard, .middleOfNight)
            logsByPrayerRaw = [:]
        }

        let timeZone = TimeZone.current

        // Compute today's prayer times and tomorrow's Fajr — together
        // these define the transition boundaries we emit entries at.
        guard
            let today = try? prayerTimesProvider.dayTimes(
                for: referenceDate,
                coordinates: location.coordinates,
                timeZone: timeZone,
                calculationMethod: calculation.0,
                madhab: calculation.1,
                highLatitudeRule: calculation.2
            ),
            let tomorrowFajrDate = Calendar.current.date(
                byAdding: .day, value: 1, to: referenceDate
            ),
            let tomorrow = try? prayerTimesProvider.dayTimes(
                for: tomorrowFajrDate,
                coordinates: location.coordinates,
                timeZone: timeZone,
                calculationMethod: calculation.0,
                madhab: calculation.1,
                highLatitudeRule: calculation.2
            )
        else {
            return [missingLocationEntry(at: referenceDate)]
        }

        let qibla = WidgetQiblaBearing.bearing(from: location.coordinates)

        let slots: [PrayerTimelineEntry.PrayerSlot] = today.allFardh.map {
            PrayerTimelineEntry.PrayerSlot(
                prayer: $0.prayer,
                scheduledTime: $0.scheduledTime
            )
        }

        // Build the list of upcoming transitions: every today-prayer
        // whose scheduled time is in the future, plus tomorrow's Fajr.
        let upcoming: [(Prayer, Date)] = today.allFardh
            .filter { $0.scheduledTime > referenceDate }
            .map { ($0.prayer, $0.scheduledTime) }
            + [(tomorrow.fajr.prayer, tomorrow.fajr.scheduledTime)]

        // Emit one entry at "now" plus one immediately at each transition.
        // We use the SAME `nextPrayer` for the entry whose `date` IS the
        // transition: by the time iOS shows the entry at exactly the
        // scheduled time, the system considers that prayer "now passed"
        // and we want the user to see the FOLLOWING prayer's countdown.
        var entries: [PrayerTimelineEntry] = []

        // Initial "now" entry — what's coming next from the reference moment.
        if let firstUpcoming = upcoming.first {
            entries.append(
                PrayerTimelineEntry(
                    date: referenceDate,
                    nextPrayer: firstUpcoming.0,
                    nextPrayerScheduledTime: firstUpcoming.1,
                    todayPrayerTimes: slots,
                    loggedStatusByPrayerRaw: logsByPrayerRaw,
                    cityName: location.displayCity,
                    qiblaBearingDegrees: qibla,
                    isLocationMissing: false
                )
            )
        }

        // One entry per transition, advancing `nextPrayer` to the entry
        // that follows. The final entry (tomorrow's Fajr) carries
        // tomorrow's Fajr as its OWN next prayer so the widget shows
        // 0s remaining briefly before the timeline reloads.
        for (i, transition) in upcoming.enumerated() {
            let next: (Prayer, Date)
            if i + 1 < upcoming.count {
                next = upcoming[i + 1]
            } else {
                next = transition
            }
            entries.append(
                PrayerTimelineEntry(
                    date: transition.1,
                    nextPrayer: next.0,
                    nextPrayerScheduledTime: next.1,
                    todayPrayerTimes: slots,
                    loggedStatusByPrayerRaw: logsByPrayerRaw,
                    cityName: location.displayCity,
                    qiblaBearingDegrees: qibla,
                    isLocationMissing: false
                )
            )
        }

        return entries
    }

    private func openSharedContext() -> ModelContext? {
        guard let container = try? IhsanModelContainerFactory.makeContainer() else {
            return nil
        }
        return ModelContext(container)
    }

    private func readCalculation(
        from context: ModelContext
    ) -> (CalculationMethodChoice, MadhabChoice, HighLatitudeRule)? {
        guard let settings = try? UserSettings.fetchOrCreate(in: context) else {
            return nil
        }
        return (settings.calculationMethod, settings.madhab, settings.highLatitudeRule)
    }

    private func readTodaysLogs(
        at referenceDate: Date,
        from context: ModelContext
    ) -> [String: String] {
        let dayStart = Calendar.current.startOfDay(for: referenceDate)
        let descriptor = FetchDescriptor<PrayerLog>(
            predicate: #Predicate<PrayerLog> { $0.prayerDate == dayStart }
        )
        guard let logs = try? context.fetch(descriptor) else {
            return [:]
        }
        var result: [String: String] = [:]
        for log in logs {
            result[log.prayerRaw] = log.statusRaw
        }
        return result
    }

    private func missingLocationEntry(at date: Date) -> PrayerTimelineEntry {
        let placeholder = PrayerTimelineEntry.placeholder(at: date)
        return PrayerTimelineEntry(
            date: date,
            nextPrayer: placeholder.nextPrayer,
            nextPrayerScheduledTime: placeholder.nextPrayerScheduledTime,
            todayPrayerTimes: placeholder.todayPrayerTimes,
            loggedStatusByPrayerRaw: [:],
            cityName: "Open Ihsan",
            qiblaBearingDegrees: nil,
            isLocationMissing: true
        )
    }
}
