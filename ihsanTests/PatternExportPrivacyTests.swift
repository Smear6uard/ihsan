import SwiftUI
import Testing
import IhsanCore
import IhsanDesignSystem
@testable import ihsan

#if canImport(UIKit)
import UIKit

@Suite("Pattern export privacy")
struct PatternExportPrivacyTests {
    @MainActor
    @Test("pause marks flatten to absent marks only in export")
    func pauseMarksFlattenPixelForPixel() throws {
        let calendar = utcCalendar
        let seededMonth = makeSeededMonth(calendar: calendar)
        let pausedCandidate = seededMonth.first { $0.isPaused }
        let absentCandidate = seededMonth.first {
            !$0.isPaused && $0.prayerCompletions.allSatisfy { $0.status == nil }
        }
        let pausedDay = try #require(pausedCandidate)
        let absentDay = try #require(absentCandidate)
        let aggregate = TrajectoryAggregator.aggregate(days: seededMonth, qadaLogs: [])

        let prepared = PatternExportPrivacy.prepare(
            days: seededMonth,
            aggregate: aggregate,
            naflDays: [pausedDay.date],
            dhikrDays: [pausedDay.date],
            calendar: calendar
        )
        let exportedPauseCandidate = prepared.days.first { $0.id == pausedDay.id }
        let exportedAbsentCandidate = prepared.days.first { $0.id == absentDay.id }
        let exportedPause = try #require(exportedPauseCandidate)
        let exportedAbsent = try #require(exportedAbsentCandidate)

        #expect(!exportedPause.isPaused)
        #expect(!exportedPause.isTraveling)
        #expect(!exportedPause.needsReview)
        #expect(exportedPause.prayerCompletions.allSatisfy { $0.status == nil })
        #expect(prepared.naflDays?.contains(pausedDay.date) == false)
        #expect(prepared.dhikrDays?.contains(pausedDay.date) == false)

        let tokens = PaletteState.afternoon.tokens
        let exportPausePixels = try renderMark(day: exportedPause, tokens: tokens)
        let exportAbsentPixels = try renderMark(day: exportedAbsent, tokens: tokens)
        // Give the live comparison the same blank slate as the absent
        // day. The pause flag is therefore the only possible pixel
        // difference, while the seeded hidden statuses above still
        // prove the sanitizer removed more than a visual flag.
        let livePausedBlank = DayCompletion(
            id: exportedPause.id,
            date: exportedPause.date,
            prayerCompletions: exportedPause.prayerCompletions,
            isPaused: true,
            isTraveling: false,
            needsReview: false
        )
        let livePausePixels = try renderMark(day: livePausedBlank, tokens: tokens)
        let liveAbsentPixels = try renderMark(day: absentDay, tokens: tokens)

        #expect(exportPausePixels == exportAbsentPixels)
        #expect(livePausePixels != liveAbsentPixels)
    }

    @MainActor
    @Test("share renderer produces a three-times portrait PNG")
    func rendererProducesThreeTimesPortraitImage() throws {
        let calendar = utcCalendar
        let days = makeSeededMonth(calendar: calendar)
        let aggregate = TrajectoryAggregator.aggregate(days: days, qadaLogs: [])
        let content = PatternExportPrivacy.prepare(
            days: days,
            aggregate: aggregate,
            naflDays: nil,
            dhikrDays: nil,
            calendar: calendar
        )
        let payload = try #require(
            PatternShareRenderer.render(
                content: content,
                period: .thirtyDays,
                tokens: PaletteState.afternoon.tokens,
                reduceTransparency: false
            )
        )
        let image = try #require(payload.image.cgImage)

        #expect(image.width == Int(PatternShareCard.pointSize.width * 3))
        #expect(image.height == Int(PatternShareCard.pointSize.height * 3))
        #expect(payload.item.pngData.isEmpty == false)
    }

    @MainActor
    private func renderMark(
        day: DayCompletion,
        tokens: SkyPaletteTokens
    ) throws -> Data {
        let completionCandidate = day.prayerCompletions.first { $0.prayer == .fajr }
        let completion = try #require(completionCandidate)
        let renderer = ImageRenderer(
            content: ZStack {
                tokens.panelFill
                GestaltDot(
                    completion: completion,
                    isPausedDay: day.isPaused,
                    size: 16,
                    tokens: tokens
                )
            }
            .frame(width: 24, height: 24)
        )
        renderer.proposedSize = ProposedViewSize(width: 24, height: 24)
        renderer.scale = 3
        renderer.isOpaque = true
        return try #require(renderer.uiImage?.pngData())
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func makeSeededMonth(calendar: Calendar) -> [DayCompletion] {
        let start = calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 1)
        )!
        return (0..<30).map { index in
            let date = calendar.date(byAdding: .day, value: index, to: start)!
            let isPaused = index == 11
            let isOrdinaryAbsent = index == 12
            let completions = Prayer.allCases.enumerated().map { prayerIndex, prayer in
                let status: PrayerStatus? = if isOrdinaryAbsent {
                    nil
                } else if isPaused {
                    prayerIndex == 0 ? .onTime : .late
                } else {
                    switch (index + prayerIndex) % 4 {
                    case 0: .onTime
                    case 1: .late
                    case 2: .missed
                    default: nil
                    }
                }
                return PrayerCompletion(
                    prayer: prayer,
                    status: status,
                    withJamaah: status == .onTime && prayerIndex.isMultiple(of: 2)
                )
            }
            return DayCompletion(
                id: date,
                date: date,
                prayerCompletions: completions,
                isPaused: isPaused,
                isTraveling: isPaused,
                needsReview: isPaused
            )
        }
    }
}
#endif
