import Foundation
import IhsanCore
import Testing
@testable import IhsanPrayerTimes

/// Calculation depth: custom twilight angles, fixed-interval Isha, and
/// per-prayer manual offsets. The governing rule is that `.standard` is
/// the identity — the pinned `FardhSnapshotTests` prove the presets did
/// not move, and everything here proves the overrides do exactly and
/// only what they say.
@Suite("Calculation tuning")
struct CalculationTuningTests {
    private let provider = AdhanPrayerTimesProvider()
    private let chicago = Coordinates(latitude: 41.8781, longitude: -87.6298)
    private let chicagoZone = TimeZone(identifier: "America/Chicago")!
    private let mayDay = Date(timeIntervalSince1970: 1_778_846_400) // 2026-05-15T12:00:00Z

    private func times(
        method: CalculationMethodChoice = .isna,
        tuning: CalculationTuning = .standard,
        coordinates: Coordinates? = nil,
        timeZone: TimeZone? = nil,
        date: Date? = nil
    ) throws -> DayPrayerTimes {
        try provider.dayTimes(
            for: date ?? mayDay,
            coordinates: coordinates ?? chicago,
            timeZone: timeZone ?? chicagoZone,
            calculationMethod: method,
            madhab: .standard,
            highLatitudeRule: .middleOfNight,
            tuning: tuning
        )
    }

    // MARK: - Identity

    @Test("An untuned computation is byte-identical to the untuned overload")
    func standardTuningIsTheIdentity() throws {
        let explicit = try times(tuning: .standard)
        let implicit = try provider.dayTimes(
            for: mayDay,
            coordinates: chicago,
            timeZone: chicagoZone,
            calculationMethod: .isna,
            madhab: .standard,
            highLatitudeRule: .middleOfNight
        )

        #expect(explicit.fajr.scheduledTime == implicit.fajr.scheduledTime)
        #expect(explicit.dhuhr.scheduledTime == implicit.dhuhr.scheduledTime)
        #expect(explicit.asr.scheduledTime == implicit.asr.scheduledTime)
        #expect(explicit.maghrib.scheduledTime == implicit.maghrib.scheduledTime)
        #expect(explicit.isha.scheduledTime == implicit.isha.scheduledTime)
        #expect(explicit.sunrise == implicit.sunrise)
    }

    // MARK: - Fajr angle

    @Test("A steeper Fajr angle moves Fajr earlier and touches nothing else")
    func customFajrAngleMovesOnlyFajr() throws {
        let baseline = try times()
        let steeper = try times(tuning: CalculationTuning(fajrAngle: 18))

        // ISNA is 15°; 18° is further below the horizon, so first light
        // is reached earlier.
        #expect(steeper.fajr.scheduledTime < baseline.fajr.scheduledTime)
        #expect(steeper.sunrise == baseline.sunrise)
        #expect(steeper.dhuhr.scheduledTime == baseline.dhuhr.scheduledTime)
        #expect(steeper.asr.scheduledTime == baseline.asr.scheduledTime)
        #expect(steeper.maghrib.scheduledTime == baseline.maghrib.scheduledTime)
        #expect(steeper.isha.scheduledTime == baseline.isha.scheduledTime)
    }

    @Test("A shallower Fajr angle moves Fajr later")
    func shallowerFajrAngleMovesFajrLater() throws {
        let baseline = try times()
        let shallower = try times(tuning: CalculationTuning(fajrAngle: 12))

        #expect(shallower.fajr.scheduledTime > baseline.fajr.scheduledTime)
    }

    @Test("A custom Fajr angle reproduces the preset that publishes it")
    func customAngleMatchesTheEquivalentPreset() throws {
        // MWL is 18° / 17°. Overriding ISNA to both of those angles must
        // land on MWL's times exactly — proof the override feeds the
        // same solar math and not a parallel one.
        let mwl = try times(method: .muslimWorldLeague)
        let tuned = try times(
            method: .isna,
            tuning: CalculationTuning(fajrAngle: 18, ishaRule: .angle(17))
        )

        #expect(tuned.fajr.scheduledTime == mwl.fajr.scheduledTime)
        #expect(tuned.isha.scheduledTime == mwl.isha.scheduledTime)
    }

    // MARK: - Isha

    @Test("A steeper Isha angle moves Isha later and touches nothing else")
    func customIshaAngleMovesOnlyIsha() throws {
        let baseline = try times()
        let steeper = try times(tuning: CalculationTuning(ishaRule: .angle(18)))

        #expect(steeper.isha.scheduledTime > baseline.isha.scheduledTime)
        #expect(steeper.fajr.scheduledTime == baseline.fajr.scheduledTime)
        #expect(steeper.maghrib.scheduledTime == baseline.maghrib.scheduledTime)
    }

    @Test("Interval mode puts Isha exactly that many minutes after Maghrib")
    func intervalModeIsExact() throws {
        for minutes in [60, 75, 90, 120] {
            let tuned = try times(tuning: CalculationTuning(ishaRule: .intervalMinutes(minutes)))
            let delta = tuned.isha.scheduledTime.timeIntervalSince(tuned.maghrib.scheduledTime)
            #expect(delta == Double(minutes) * 60, "interval \(minutes) landed at \(delta)s")
        }
    }

    @Test("Interval mode reproduces Umm al-Qura's published 90 minutes")
    func intervalModeMatchesUmmAlQura() throws {
        let mecca = Coordinates(latitude: 21.4225, longitude: 39.8262)
        let riyadh = TimeZone(identifier: "Asia/Riyadh")!

        let published = try times(method: .ummAlQura, coordinates: mecca, timeZone: riyadh)
        let tuned = try times(
            method: .ummAlQura,
            tuning: CalculationTuning(ishaRule: .intervalMinutes(90)),
            coordinates: mecca,
            timeZone: riyadh
        )

        #expect(tuned.isha.scheduledTime == published.isha.scheduledTime)
    }

    @Test("Choosing an angle after an interval clears the interval")
    func angleModeReplacesIntervalMode() throws {
        let interval = try times(tuning: CalculationTuning(ishaRule: .intervalMinutes(90)))
        let angle = try times(tuning: CalculationTuning(ishaRule: .angle(17)))
        let ishaAngleGap = angle.isha.scheduledTime.timeIntervalSince(angle.maghrib.scheduledTime)

        #expect(interval.isha.scheduledTime != angle.isha.scheduledTime)
        #expect(ishaAngleGap != 90 * 60)
    }

    // MARK: - Offsets

    @Test("Every per-prayer offset shifts exactly its own prayer")
    func offsetsShiftOnlyTheirOwnPrayer() throws {
        let baseline = try times()

        let tuned = try times(tuning: CalculationTuning(
            offsets: PrayerOffsets(fajr: -5, dhuhr: 2, asr: 3, maghrib: -1, isha: 10)
        ))

        #expect(tuned.fajr.scheduledTime == baseline.fajr.scheduledTime.addingTimeInterval(-5 * 60))
        #expect(tuned.dhuhr.scheduledTime == baseline.dhuhr.scheduledTime.addingTimeInterval(2 * 60))
        #expect(tuned.asr.scheduledTime == baseline.asr.scheduledTime.addingTimeInterval(3 * 60))
        #expect(tuned.maghrib.scheduledTime == baseline.maghrib.scheduledTime.addingTimeInterval(-1 * 60))
        #expect(tuned.isha.scheduledTime == baseline.isha.scheduledTime.addingTimeInterval(10 * 60))
        // Sunrise is not a prayer and has no offer of an offset.
        #expect(tuned.sunrise == baseline.sunrise)
    }

    @Test("Offsets ride on top of angle overrides rather than replacing them")
    func offsetsComposeWithAngles() throws {
        let angled = try times(tuning: CalculationTuning(fajrAngle: 18))
        let angledAndOffset = try times(tuning: CalculationTuning(
            fajrAngle: 18,
            offsets: PrayerOffsets(fajr: -4)
        ))

        #expect(
            angledAndOffset.fajr.scheduledTime
                == angled.fajr.scheduledTime.addingTimeInterval(-4 * 60)
        )
    }

    @Test("A preset's own published corrections survive a manual offset")
    func methodAdjustmentsSurviveOffsets() throws {
        // Umm al-Qura publishes a Dhuhr correction of its own. Adding a
        // user offset must add to it, not overwrite it.
        let mecca = Coordinates(latitude: 21.4225, longitude: 39.8262)
        let riyadh = TimeZone(identifier: "Asia/Riyadh")!
        let baseline = try times(method: .ummAlQura, coordinates: mecca, timeZone: riyadh)
        let offset = try times(
            method: .ummAlQura,
            tuning: CalculationTuning(offsets: PrayerOffsets(dhuhr: 5)),
            coordinates: mecca,
            timeZone: riyadh
        )

        #expect(
            offset.dhuhr.scheduledTime
                == baseline.dhuhr.scheduledTime.addingTimeInterval(5 * 60)
        )
    }

    // MARK: - Clamping

    @Test("Angles outside the offered range are clamped, never computed with")
    func anglesClampToTheOfferedRange() {
        #expect(CalculationTuning(fajrAngle: 40).fajrAngle == 20)
        #expect(CalculationTuning(fajrAngle: 3).fajrAngle == 12)
        #expect(CalculationTuning(fajrAngle: -100).fajrAngle == 12)
        #expect(CalculationTuning(fajrAngle: .infinity).fajrAngle == 20)
    }

    @Test("Angles snap to the half-degree the picker offers")
    func anglesSnapToTheStep() {
        #expect(CalculationTuning(fajrAngle: 15.3).fajrAngle == 15.5)
        #expect(CalculationTuning(fajrAngle: 15.2).fajrAngle == 15.0)
        #expect(CalculationTuning(ishaRule: .angle(17.26)).ishaRule == .angle(17.5))
    }

    @Test("Intervals clamp and snap to the five-minute step")
    func intervalsClampAndSnap() {
        #expect(CalculationTuning(ishaRule: .intervalMinutes(5)).ishaRule == .intervalMinutes(60))
        #expect(CalculationTuning(ishaRule: .intervalMinutes(999)).ishaRule == .intervalMinutes(120))
        #expect(CalculationTuning(ishaRule: .intervalMinutes(83)).ishaRule == .intervalMinutes(85))
    }

    @Test("Offsets clamp to ±10 minutes")
    func offsetsClamp() {
        let wild = PrayerOffsets(fajr: 90, dhuhr: -90, asr: 10, maghrib: -10, isha: 0)
        #expect(wild.fajr == 10)
        #expect(wild.dhuhr == -10)
        #expect(wild.asr == 10)
        #expect(wild.maghrib == -10)
        #expect(wild.isha == 0)
    }

    @Test("The subscript clamps on write too")
    func offsetSubscriptClamps() {
        var offsets = PrayerOffsets()
        offsets[.asr] = 500
        #expect(offsets[.asr] == 10)
        offsets[.asr] = -3
        #expect(offsets[.asr] == -3)
    }

    // MARK: - What counts as "custom"

    @Test("Offsets alone do not make a method custom; an angle does")
    func onlyAngleOverridesRenameTheMethod() {
        #expect(CalculationTuning.standard.overridesAngles == false)
        #expect(CalculationTuning(offsets: PrayerOffsets(asr: 3)).overridesAngles == false)
        #expect(CalculationTuning(fajrAngle: 16).overridesAngles)
        #expect(CalculationTuning(ishaRule: .angle(15)).overridesAngles)
        #expect(CalculationTuning(ishaRule: .intervalMinutes(90)).overridesAngles)
    }

    @Test("Resetting drops the angles and keeps the offsets")
    func resettingKeepsOffsets() {
        let tuned = CalculationTuning(
            fajrAngle: 18,
            ishaRule: .intervalMinutes(90),
            offsets: PrayerOffsets(asr: 3)
        )
        let reset = tuned.resettingAngles()

        #expect(reset.fajrAngle == nil)
        #expect(reset.ishaRule == .preset)
        #expect(reset.offsets.asr == 3)
        #expect(reset.overridesAngles == false)
    }

    // MARK: - Displayed angles match computed angles

    @Test("Every offered preset reports the angles it actually computes with")
    func presetsReportTruthfulAngles() throws {
        for method in CalculationMethodChoice.allCases where method != .other {
            let angles = try #require(method.angles, "\(method) must publish its angles")
            #expect(CalculationTuning.angleRange.contains(angles.fajrAngle) || angles.fajrAngle > 0)

            // Exactly one of the two Isha shapes, never both and never
            // neither — a row that showed both would be lying.
            let hasAngle = angles.ishaAngle != nil
            let hasInterval = angles.ishaIntervalMinutes != nil
            #expect(hasAngle != hasInterval, "\(method) resolved to \(angles)")
        }

        #expect(CalculationMethodChoice.other.angles == nil)
    }

    @Test("The displayed angles match the published ones for known methods")
    func knownMethodAnglesAreTheDocumentedValues() throws {
        let isna = try #require(CalculationMethodChoice.isna.angles)
        #expect(isna.fajrAngle == 15)
        #expect(isna.ishaAngle == 15)

        let mwl = try #require(CalculationMethodChoice.muslimWorldLeague.angles)
        #expect(mwl.fajrAngle == 18)
        #expect(mwl.ishaAngle == 17)

        let ummAlQura = try #require(CalculationMethodChoice.ummAlQura.angles)
        #expect(ummAlQura.fajrAngle == 18.5)
        #expect(ummAlQura.ishaAngle == nil)
        #expect(ummAlQura.ishaIntervalMinutes == 90)

        let karachi = try #require(CalculationMethodChoice.karachi.angles)
        #expect(karachi.fajrAngle == 18)
        #expect(karachi.ishaAngle == 18)
    }

    @Test("Effective angles fold the override onto the preset it started from")
    func effectiveAnglesReflectTheOverride() throws {
        // Only Fajr changed — Isha still reads the preset's own value.
        let partial = try #require(CalculationMethodAngles.effective(
            method: .isna,
            tuning: CalculationTuning(fajrAngle: 16.5)
        ))
        #expect(partial.fajrAngle == 16.5)
        #expect(partial.ishaAngle == 15)

        // Switching to interval mode drops the angle entirely.
        let interval = try #require(CalculationMethodAngles.effective(
            method: .isna,
            tuning: CalculationTuning(ishaRule: .intervalMinutes(90))
        ))
        #expect(interval.fajrAngle == 15)
        #expect(interval.ishaAngle == nil)
        #expect(interval.ishaIntervalMinutes == 90)

        // Untouched is the preset itself.
        let untouched = try #require(CalculationMethodAngles.effective(
            method: .karachi,
            tuning: .standard
        ))
        #expect(untouched == CalculationMethodChoice.karachi.angles)
    }

    // MARK: - Depth reaches the resolver, not just the day table

    @Test("Tuning reaches the schedule window and the resolved state")
    func tuningFlowsThroughTheResolver() throws {
        let baselineWindow = try provider.scheduleWindow(
            for: mayDay,
            coordinates: chicago,
            timeZone: chicagoZone,
            calculationMethod: .isna,
            madhab: .standard,
            highLatitudeRule: .middleOfNight
        )
        let tunedWindow = try provider.scheduleWindow(
            for: mayDay,
            coordinates: chicago,
            timeZone: chicagoZone,
            calculationMethod: .isna,
            madhab: .standard,
            highLatitudeRule: .middleOfNight,
            tuning: CalculationTuning(fajrAngle: 18)
        )

        #expect(tunedWindow.day.fajr.scheduledTime < baselineWindow.day.fajr.scheduledTime)
        #expect(tunedWindow.tomorrowFajr.scheduledTime < baselineWindow.tomorrowFajr.scheduledTime)
        #expect(tunedWindow.resolverSchedule.tableHash != baselineWindow.resolverSchedule.tableHash)
    }

    @Test("A tuned schedule still resolves without entering a prayer early")
    func tunedSchedulesStayHonest() throws {
        let tunings: [CalculationTuning] = [
            CalculationTuning(fajrAngle: 12),
            CalculationTuning(fajrAngle: 20, ishaRule: .angle(20)),
            CalculationTuning(ishaRule: .intervalMinutes(60)),
            CalculationTuning(ishaRule: .intervalMinutes(120), offsets: PrayerOffsets(fajr: -10, isha: 10))
        ]

        for tuning in tunings {
            let window = try provider.scheduleWindow(
                for: mayDay,
                coordinates: chicago,
                timeZone: chicagoZone,
                calculationMethod: .isna,
                madhab: .standard,
                highLatitudeRule: .middleOfNight,
                tuning: tuning
            )
            let schedule = window.resolverSchedule

            for prayer in schedule.dayPrayerTimes {
                let justBefore = prayer.scheduledTime.addingTimeInterval(-60)
                let resolution = PrayerStateResolver.resolve(prayerTimes: schedule, now: justBefore)
                #expect(
                    resolution.currentPrayer != prayer,
                    "\(prayer.prayer) was current a minute before it began under \(tuning)"
                )
                #expect(resolution.nextPrayer.scheduledTime > justBefore)
            }

            // Chronology holds: the tuned day is still a day.
            let times = schedule.dayPrayerTimes.map(\.scheduledTime)
            #expect(times == times.sorted())
            #expect(schedule.fajr.scheduledTime < schedule.sunrise)
        }
    }

    @Test("Moonsighting's seasonal twilight yields to an explicit angle")
    func customAngleWinsOverMethodSpecificAlgorithms() throws {
        // Above 55° the Moonsighting Committee method substitutes a
        // seasonal twilight table for the angle. A person who types an
        // angle must get that angle, not the table.
        let tromso = Coordinates(latitude: 69.6492, longitude: 18.9553)
        let zone = TimeZone(identifier: "Europe/Oslo")!
        let march = Date(timeIntervalSince1970: 1_772_884_800) // 2026-03-07T12:00:00Z

        let seasonal = try times(
            method: .moonsightingCommittee,
            coordinates: tromso,
            timeZone: zone,
            date: march
        )
        let explicit = try times(
            method: .moonsightingCommittee,
            tuning: CalculationTuning(fajrAngle: 12),
            coordinates: tromso,
            timeZone: zone,
            date: march
        )

        #expect(explicit.fajr.scheduledTime != seasonal.fajr.scheduledTime)
    }
}
