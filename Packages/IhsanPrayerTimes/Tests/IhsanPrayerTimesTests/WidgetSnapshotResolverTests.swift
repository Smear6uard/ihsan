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

// MARK: - The two clocks, carried in the snapshot

/// A widget renders from the snapshot alone. So the snapshot has to
/// carry both clocks, and carry them the way the app resolves them: the
/// cycle its logged slate belongs to, and each covered day's evening
/// turn. A widget that keeps the app's prayer answers but files its
/// logged marks under a different day is the same defect wearing
/// different clothes.
@Suite("Widget snapshot carries both clocks")
struct WidgetSnapshotClockTests {

    private static let chicago = Coordinates(latitude: 41.8781, longitude: -87.6298)
    private static let timeZone = TimeZone(identifier: "America/Chicago")!

    private static func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(
            year: 2026, month: 7, day: day, hour: hour, minute: minute
        ))!
    }

    private func snapshot(builtAt: Date) throws -> WidgetSnapshot {
        try WidgetSnapshotBuilder.build(
            at: builtAt,
            cityName: "Chicago",
            qiblaBearingDegrees: nil,
            provider: AdhanPrayerTimesProvider(),
            coordinates: Self.chicago,
            timeZone: Self.timeZone,
            calculationMethod: .isna,
            madhab: .standard,
            highLatitudeRule: .middleOfNight,
            facts: .empty
        )
    }

    private func window(at instant: Date) throws -> PrayerScheduleWindow {
        try AdhanPrayerTimesProvider().scheduleWindow(
            for: instant,
            coordinates: Self.chicago,
            timeZone: Self.timeZone,
            calculationMethod: .isna,
            madhab: .standard,
            highLatitudeRule: .middleOfNight
        )
    }

    /// Clock 1: the snapshot's cycle is the app's cycle, at every hour
    /// that used to disagree.
    @Test
    func theSnapshotCycleIsTheAppCycle() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Self.timeZone

        for instant in [
            Self.at(30, 12, 0),   // midday
            Self.at(30, 21, 30),  // after Isha
            Self.at(30, 23, 59),  // last minute before midnight
            Self.at(31, 0, 1),    // first minute after it
            Self.at(31, 1, 0),    // the hour the defect lived at
            Self.at(31, 6, 0),    // after Fajr: rolled
        ] {
            let snapshot = try snapshot(builtAt: instant)
            let app = try window(at: instant).cycle(at: instant)
            #expect(
                snapshot.cycleDayStart == app.date,
                "the snapshot filed \(instant) under a different cycle than the app"
            )
            #expect(snapshot.cycleRollsAt == app.rollsAt)
            #expect(instant < snapshot.cycleRollsAt)
        }
    }

    /// Midnight moves neither clock. A snapshot built at 23:59 and one
    /// built at 00:01 name the same cycle.
    @Test
    func midnightMovesNeitherClock() throws {
        let before = try snapshot(builtAt: Self.at(30, 23, 59))
        let after = try snapshot(builtAt: Self.at(31, 0, 1))
        #expect(before.cycleDayStart == after.cycleDayStart)
        #expect(before.cycleRollsAt == after.cycleRollsAt)
    }

    /// Clock 2: each covered day carries its own Maghrib as the turn,
    /// and the boundary set no longer contains civil midnight.
    @Test
    func eveningTurnsTravelWithEachDay() throws {
        let builtAt = Self.at(30, 12, 0)
        let snapshot = try snapshot(builtAt: builtAt)
        let facts = try WidgetSnapshotBuilder.coveredDays(
            at: builtAt,
            provider: AdhanPrayerTimesProvider(),
            coordinates: Self.chicago,
            timeZone: Self.timeZone,
            calculationMethod: .isna,
            madhab: .standard,
            highLatitudeRule: .middleOfNight
        )
        // Three days, so an evening late in the snapshot's run has a
        // day to turn into.
        #expect(facts.today < facts.tomorrow)
        #expect(facts.tomorrow < facts.dayAfterTomorrow)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Self.timeZone
        let midnight = calendar.startOfDay(for: Self.at(31, 12, 0))
        let boundaries = snapshot.timelineBoundaries(
            after: builtAt, until: snapshot.dayAfterTomorrowFajr
        )
        #expect(!boundaries.contains(midnight), "civil midnight is still a widget boundary")
        #expect(boundaries.contains(snapshot.today.maghrib), "the evening turn is not a boundary")
        #expect(boundaries.contains(snapshot.cycleRollsAt), "the cycle roll is not a boundary")
    }
}
