import Foundation
import IhsanCore
import Testing
@testable import IhsanDesignSystem

// MARK: - Helpers

private func makeDate(hour: Int, minute: Int = 0) -> Date {
    var components = DateComponents()
    components.year = 2026
    components.month = 5
    components.day = 15
    components.hour = hour
    components.minute = minute
    return Calendar.current.date(from: components)!
}

private func defaultMarks() -> [PrayerArc.PrayerMark] {
    [
        .init(prayer: .fajr,    time: makeDate(hour: 5,  minute: 0)),
        .init(prayer: .dhuhr,   time: makeDate(hour: 12, minute: 30)),
        .init(prayer: .asr,     time: makeDate(hour: 15, minute: 30)),
        .init(prayer: .maghrib, time: makeDate(hour: 19, minute: 0)),
        .init(prayer: .isha,    time: makeDate(hour: 21, minute: 30))
    ]
}

private let testSize = CGSize(width: 360, height: 80)

// MARK: - ArcGeometry — endpoint and apex pinning

@Test
func arcStartsAtLeftHorizon() {
    let p = ArcGeometry.point(at: 0, in: testSize)
    #expect(p.x == ArcGeometry.inset)
    #expect(p.y == testSize.height - ArcGeometry.baseInsetBottom)
}

@Test
func arcEndsAtRightHorizon() {
    let p = ArcGeometry.point(at: 1, in: testSize)
    #expect(p.x == testSize.width - ArcGeometry.inset)
    #expect(p.y == testSize.height - ArcGeometry.baseInsetBottom)
}

@Test
func arcApexIsAtCenterAndElevated() {
    let p = ArcGeometry.point(at: 0.5, in: testSize)
    let expectedX = testSize.width / 2
    let expectedY = testSize.height - ArcGeometry.baseInsetBottom - ArcGeometry.amplitude
    #expect(abs(p.x - expectedX) < 0.001)
    #expect(abs(p.y - expectedY) < 0.001)
}

@Test
func arcIsHorizontallyMonotonic() {
    // Stepping t from 0 → 1 must produce strictly increasing x. The
    // sine-curve y is allowed to fall back to the base; x is not.
    var lastX: CGFloat = -.infinity
    for i in 0...60 {
        let t = Double(i) / 60.0
        let p = ArcGeometry.point(at: t, in: testSize)
        #expect(p.x > lastX, "x not monotonic at t=\(t)")
        lastX = p.x
    }
}

@Test
func arcIsSymmetric() {
    // y(t) must equal y(1 − t) — the curve is mirrored about the apex.
    for i in 0..<30 {
        let t = Double(i) / 60.0
        let pLeft = ArcGeometry.point(at: t, in: testSize)
        let pRight = ArcGeometry.point(at: 1 - t, in: testSize)
        #expect(abs(pLeft.y - pRight.y) < 0.001, "asymmetric y at t=\(t)")
    }
}

// MARK: - ArcPosition — day vs night

@Test
func positionIsPreDawnBeforeFajr() {
    let marks = defaultMarks()
    let before = makeDate(hour: 3, minute: 30)
    #expect(ArcPosition.compute(at: before, marks: marks) == .preDawn)
}

@Test
func positionIsPostIshaAfterIsha() {
    let marks = defaultMarks()
    let after = makeDate(hour: 23, minute: 30)
    #expect(ArcPosition.compute(at: after, marks: marks) == .postIsha)
}

@Test
func positionAtFajrIsTZero() {
    let marks = defaultMarks()
    let fajr = marks.first(where: { $0.prayer == .fajr })!.time
    let position = ArcPosition.compute(at: fajr, marks: marks)
    if case .dayArc(let t) = position {
        #expect(abs(t) < 0.001, "expected t≈0 at fajr, got \(t)")
    } else {
        #expect(Bool(false), "expected dayArc at fajr, got \(position)")
    }
}

@Test
func positionAtIshaIsExactlyPostIsha() {
    // Inclusive boundary: at exactly Isha we've completed the arc.
    // Use >=, not >, so the post-Isha night layer engages at the
    // moment the user finishes the day's last prayer rather than a
    // second later.
    let marks = defaultMarks()
    let isha = marks.first(where: { $0.prayer == .isha })!.time
    #expect(ArcPosition.compute(at: isha, marks: marks) == .postIsha)
}

@Test
func positionAtDhuhrIsProportional() {
    // Fajr 5:00, Isha 21:30 → 16.5 h span. Dhuhr 12:30 = 7.5 h in.
    // t = 7.5 / 16.5 ≈ 0.4545.
    let marks = defaultMarks()
    let dhuhr = marks.first(where: { $0.prayer == .dhuhr })!.time
    let position = ArcPosition.compute(at: dhuhr, marks: marks)
    if case .dayArc(let t) = position {
        let expected = (7.5 / 16.5)
        #expect(abs(t - expected) < 0.01, "expected t≈\(expected), got \(t)")
    } else {
        #expect(Bool(false), "expected dayArc at dhuhr")
    }
}

@Test
func positionMidwayHasMidwayT() {
    // 13:15 sits exactly between fajr 5:00 and isha 21:30 → t=0.5.
    let marks = defaultMarks()
    let midpoint = makeDate(hour: 13, minute: 15)
    let position = ArcPosition.compute(at: midpoint, marks: marks)
    if case .dayArc(let t) = position {
        #expect(abs(t - 0.5) < 0.001, "expected t≈0.5, got \(t)")
    } else {
        #expect(Bool(false), "expected dayArc at midpoint")
    }
}

@Test
func prayerDotsCoverFullHorizon() {
    // Fajr and Isha must always span the full horizontal width of the
    // arc — they are the visual "horizons" of the day. Any other
    // ordering is a bug.
    let marks = defaultMarks()
    let fajrPos = ArcPosition.compute(at: marks[0].time, marks: marks)
    let ishaPos = ArcPosition.compute(at: marks[4].time, marks: marks)
    if case .dayArc(let tFajr) = fajrPos {
        #expect(tFajr == 0.0)
    } else {
        #expect(Bool(false), "fajr should be dayArc at t=0")
    }
    // Isha at its own time is post-Isha (inclusive); the verifying
    // case is t=1 for the visual marker, which we get by computing
    // one second before isha.
    let justBeforeIsha = marks[4].time.addingTimeInterval(-1)
    let beforePos = ArcPosition.compute(at: justBeforeIsha, marks: marks)
    if case .dayArc(let t) = beforePos {
        #expect(t > 0.9999, "expected t near 1 just before isha, got \(t)")
    } else {
        #expect(Bool(false), "just-before-isha should be dayArc")
    }
    _ = ishaPos
}
