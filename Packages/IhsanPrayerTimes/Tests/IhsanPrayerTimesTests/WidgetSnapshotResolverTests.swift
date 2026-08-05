import Foundation
import IhsanCore
import Testing
@testable import IhsanPrayerTimes

/// The one-truth guarantee, held under test: for every instant a
/// snapshot covers, the widget path (snapshot → rebuilt schedule →
/// shared resolver) answers exactly what the app path (fresh
/// `scheduleWindow` → shared resolver) answers. If these ever diverge,
/// a widget can show a different prayer than the Today screen — the
/// defect class this family was rebuilt to end.
@Suite("Widget snapshot resolver equivalence")
struct WidgetSnapshotResolverTests {

    private struct Site {
        let coordinates: Coordinates
        let timeZone: TimeZone
        let method: CalculationMethodChoice
        let madhab: MadhabChoice
        let rule: HighLatitudeRule
    }

    private static let chicago = Site(
        coordinates: Coordinates(latitude: 41.8781, longitude: -87.6298),
        timeZone: TimeZone(identifier: "America/Chicago")!,
        method: .isna,
        madhab: .standard,
        rule: .middleOfNight
    )

    private static let karachi = Site(
        coordinates: Coordinates(latitude: 24.8607, longitude: 67.0011),
        timeZone: TimeZone(identifier: "Asia/Karachi")!,
        method: .karachi,
        madhab: .hanafi,
        rule: .middleOfNight
    )

    private func date(
        _ site: Site, _ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = site.timeZone
        return calendar.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute
        ))!
    }

    private func snapshot(_ site: Site, builtAt: Date) throws -> WidgetSnapshot {
        try WidgetSnapshotBuilder.build(
            at: builtAt,
            cityName: "Test",
            qiblaBearingDegrees: nil,
            provider: AdhanPrayerTimesProvider(),
            coordinates: site.coordinates,
            timeZone: site.timeZone,
            calculationMethod: site.method,
            madhab: site.madhab,
            highLatitudeRule: site.rule,
            facts: .empty
        )
    }

    private func appResolution(_ site: Site, at instant: Date) throws -> PrayerResolution {
        let window = try AdhanPrayerTimesProvider().scheduleWindow(
            for: instant,
            coordinates: site.coordinates,
            timeZone: site.timeZone,
            calculationMethod: site.method,
            madhab: site.madhab,
            highLatitudeRule: site.rule
        )
        return PrayerStateResolver.resolve(prayerTimes: window.resolverSchedule, now: instant)
    }

    private func expectEquivalence(
        _ site: Site, snapshot: WidgetSnapshot, at instant: Date,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let widgetSchedule = try #require(
            snapshot.resolverSchedule(containing: instant),
            "Snapshot refused an instant it should cover: \(instant)",
            sourceLocation: sourceLocation
        )
        let widget = PrayerStateResolver.resolve(prayerTimes: widgetSchedule, now: instant)
        let app = try appResolution(site, at: instant)

        #expect(
            widget.nextPrayer == app.nextPrayer,
            "next diverged at \(instant)", sourceLocation: sourceLocation
        )
        #expect(
            widget.currentPrayer == app.currentPrayer,
            "current diverged at \(instant)", sourceLocation: sourceLocation
        )
        #expect(
            widget.countdownTarget == app.countdownTarget,
            "countdown diverged at \(instant)", sourceLocation: sourceLocation
        )
        #expect(
            widget.windowState == app.windowState,
            "window state diverged at \(instant)", sourceLocation: sourceLocation
        )
    }

    // MARK: - The named regression

    /// The competitor failure this family is designed against, pinned
    /// by name: widget and app disagreeing about Fajr and Isha around
    /// the day's edges — post-Isha rollover, the pre-Fajr night, the
    /// exact boundary instants. The widget resolves from its snapshot;
    /// the app from a fresh calculation; the answers must be one.
    @Test
    func pillarsFajrIshaBugStaysDead() throws {
        let site = Self.chicago
        // Built at noon so every edge below — including tomorrow
        // night's — falls inside the 36-hour freshness rule.
        let builtAt = date(site, 2026, 7, 30, 12, 0)
        let snapshot = try snapshot(site, builtAt: builtAt)

        let edges: [Date] = [
            snapshot.today.fajr,                                   // exact Fajr start
            snapshot.today.fajr.addingTimeInterval(-1),            // deep night before it
            snapshot.today.sunrise.addingTimeInterval(-1),         // Fajr window's last second
            snapshot.today.sunrise,                                // the forenoon gap opens
            snapshot.today.isha,                                   // exact Isha start
            snapshot.today.isha.addingTimeInterval(1),             // Isha open
            date(site, 2026, 7, 31, 0, 0),                         // civil midnight, Isha still open
            snapshot.tomorrow.fajr.addingTimeInterval(-1),         // last second of tonight
            snapshot.tomorrow.fajr,                                // rollover: tomorrow's table
            snapshot.tomorrow.isha.addingTimeInterval(60),         // tomorrow night, day two
        ]
        for edge in edges {
            try expectEquivalence(site, snapshot: snapshot, at: edge)
        }
    }

    // MARK: - Sweeps

    @Test
    func widgetAgreesWithAppAcrossBothCoveredDays() throws {
        let site = Self.karachi
        let builtAt = date(site, 2026, 7, 30, 5, 0)
        let snapshot = try snapshot(site, builtAt: builtAt)

        // Every 10 minutes across the whole span the snapshot claims
        // as fresh — coverage ends at the terminal Fajr or the
        // 36-hour age rule, whichever arrives first.
        var instant = builtAt
        let end = min(
            snapshot.dayAfterTomorrowFajr.addingTimeInterval(-1),
            builtAt.addingTimeInterval(WidgetSnapshot.maximumAge - 1)
        )
        while instant <= end {
            try expectEquivalence(site, snapshot: snapshot, at: instant)
            instant = instant.addingTimeInterval(600)
        }
    }

    /// The fall-back transition (America/Chicago, 2026-11-01): the
    /// night gains an hour mid-span. Absolute instants make this a
    /// non-event — proven, not assumed.
    @Test
    func equivalenceHoldsAcrossDSTFallBack() throws {
        let site = Self.chicago
        let builtAt = date(site, 2026, 10, 31, 12, 0)
        let snapshot = try snapshot(site, builtAt: builtAt)

        var instant = builtAt
        let end = min(
            snapshot.dayAfterTomorrowFajr.addingTimeInterval(-1),
            builtAt.addingTimeInterval(WidgetSnapshot.maximumAge - 1)
        )
        while instant <= end {
            try expectEquivalence(site, snapshot: snapshot, at: instant)
            instant = instant.addingTimeInterval(900)
        }
    }

    /// Built at 2 am — before today's Fajr — the bracketing rule
    /// keeps the civil day and lets yesterday's Isha own the pre-dawn
    /// stretch, exactly as `scheduleWindow` resolves it for the app.
    @Test
    func preFajrBuildKeepsTheCivilDayWithYesterdaysIsha() throws {
        let site = Self.chicago
        let builtAt = date(site, 2026, 7, 30, 2, 0)
        let snapshot = try snapshot(site, builtAt: builtAt)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = site.timeZone
        #expect(calendar.component(.day, from: snapshot.today.civilDayStart) == 30)
        // Pre-dawn resolves against yesterday's Isha, not a guess.
        let widgetSchedule = try #require(snapshot.resolverSchedule(containing: builtAt))
        let resolution = PrayerStateResolver.resolve(prayerTimes: widgetSchedule, now: builtAt)
        #expect(resolution.currentPrayer?.prayer == .isha)
        #expect(resolution.nextPrayer.prayer == .fajr)
        try expectEquivalence(site, snapshot: snapshot, at: builtAt)
        // And it still covers all of the 30th.
        try expectEquivalence(site, snapshot: snapshot, at: date(site, 2026, 7, 30, 23, 0))
    }

    // MARK: - Staleness refuses to resolve

    @Test
    func staleInstantsResolveNothing() throws {
        let site = Self.chicago
        let builtAt = date(site, 2026, 7, 30, 6, 30)
        let snapshot = try snapshot(site, builtAt: builtAt)

        #expect(snapshot.resolverSchedule(containing: snapshot.dayAfterTomorrowFajr) == nil)
        #expect(
            snapshot.resolverSchedule(
                containing: builtAt.addingTimeInterval(WidgetSnapshot.maximumAge + 60)
            ) == nil
        )
        #expect(snapshot.resolverSchedule(containing: date(site, 2026, 7, 29, 12, 0)) == nil)
    }

    /// The builder's covered-days answer matches what the snapshot
    /// actually carries — the publisher assembles Hijri and fasting
    /// facts for these exact days.
    @Test
    func coveredDaysMatchTheBuiltTables() throws {
        let site = Self.chicago
        let builtAt = date(site, 2026, 7, 30, 22, 30)
        let snapshot = try snapshot(site, builtAt: builtAt)
        let covered = try WidgetSnapshotBuilder.coveredDays(
            at: builtAt,
            provider: AdhanPrayerTimesProvider(),
            coordinates: site.coordinates,
            timeZone: site.timeZone,
            calculationMethod: site.method,
            madhab: site.madhab,
            highLatitudeRule: site.rule
        )
        #expect(covered.today == snapshot.today.civilDayStart)
        #expect(covered.tomorrow == snapshot.tomorrow.civilDayStart)
    }
}
