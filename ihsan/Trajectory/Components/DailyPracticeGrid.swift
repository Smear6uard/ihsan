import SwiftUI
import IhsanCore
import IhsanDesignSystem

/// The day-by-day detail grid beneath the gestalt pattern.
///
/// Days as rows (newest first), the five fardh prayers as columns.
/// The column headers are the five prayer ornaments at small scale —
/// the same forms the plate teaches, VoiceOver-labeled with the
/// prayer names. Cells speak the dot-state language; the date labels
/// sit in the system register. A cell tap opens the log sheet for
/// that prayer and day — the canonical way to log yesterday and
/// earlier.
struct DailyPracticeGrid: View {
    let days: [DayCompletion]
    let tokens: SkyPaletteTokens
    let onDayTap: (DayCompletion) -> Void
    /// A cell tap opens the log sheet for that prayer and day.
    let onCellTap: (DayCompletion, PrayerCompletion) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.md) {
            sectionHeader

            columnHeaders

            // Rows render newest-first so today sits at the top of
            // the grid.
            VStack(spacing: rowSpacing) {
                ForEach(days.reversed()) { day in
                    row(for: day)
                }
            }
        }
        .padding(IhsanSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .celestialPanel(tokens: tokens, cornerRadius: 18)
    }

    // MARK: - Header

    private var sectionHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("DAILY PRACTICE")
                .font(IhsanFont.inscription)
                .tracking(1.8)
                .foregroundStyle(tokens.inkSecondary)
            Spacer()
            if let range = dateRangeText {
                Text(range)
                    .font(IhsanFont.inscription)
                    .tracking(1.4)
                    .foregroundStyle(tokens.inkSecondary.opacity(0.8))
            }
        }
    }

    private var dateRangeText: String? {
        guard let first = days.first?.date,
              let last = days.last?.date
        else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let oldest = formatter.string(from: first).uppercased()
        let newest = formatter.string(from: last).uppercased()
        return "\(oldest) — \(newest)"
    }

    // MARK: - Column headers (the five ornaments at small scale)

    private var columnHeaders: some View {
        HStack(spacing: cellSpacing) {
            // Left gutter matches the date column width below so the
            // five ornaments align with their cells.
            Color.clear.frame(width: dateColumnWidth)
            ForEach(Prayer.allCases, id: \.self) { prayer in
                PrayerOrnamentShape(prayer: prayer, mode: .outline)
                    .stroke(tokens.metal.opacity(0.85), lineWidth: 1.0)
                    .frame(width: ornamentSize, height: ornamentSize)
                    .frame(width: cellSize, alignment: .center)
                    .accessibilityLabel(prayer.displayNameEnglish)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Row

    /// The date label opens the day's breakdown; each cell is its own
    /// button opening the log sheet for that prayer and day. Buttons
    /// are siblings, never nested.
    private func row(for day: DayCompletion) -> some View {
        // The aggregator's newest day IS today — deriving the marker
        // from the data keeps it truthful under a debug now-override
        // (the wall clock may disagree with the app's clock).
        let isToday = day.date == days.last?.date
        return HStack(spacing: cellSpacing) {
            Button {
                Haptics.tap()
                onDayTap(day)
            } label: {
                dateLabel(for: day, isToday: isToday)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(rowAccessibilityLabel(day: day))
            .accessibilityHint("Show breakdown for this day")

            ForEach(day.prayerCompletions, id: \.prayer) { completion in
                Button {
                    Haptics.tap()
                    onCellTap(day, completion)
                } label: {
                    DayPrayerCell(
                        completion: completion,
                        isPausedDay: day.isPaused,
                        size: cellSize,
                        tokens: tokens
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(cellAccessibilityLabel(day: day, completion: completion))
                .accessibilityHint("Opens the log sheet for this prayer and day.")
            }
            Spacer(minLength: 0)
        }
    }

    private func cellAccessibilityLabel(
        day: DayCompletion, completion: PrayerCompletion
    ) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        let dateText = formatter.string(from: day.date)
        let statusText: String
        if day.isPaused {
            statusText = "excused"
        } else {
            switch completion.status {
            case .onTime: statusText = completion.withJamaah
                ? "on time, in \(IhsanVocabulary.jamaah)" : "on time"
            case .late: statusText = "late"
            case .missed: statusText = "missed"
            case .qada: statusText = "qadā"
            case nil: statusText = "not logged"
            }
        }
        return "\(completion.prayer.displayNameEnglish), \(dateText), \(statusText)"
    }

    /// The date column, set in the system register: abbreviated month
    /// and day, the weekday beneath, the travel plane footnoting a
    /// traveling day.
    private func dateLabel(for day: DayCompletion, isToday: Bool) -> some View {
        HStack(spacing: 4) {
            // Today gets a small metal dot to its left — "you are
            // here" in the pattern's own metal.
            Circle()
                .fill(isToday ? tokens.metal : .clear)
                .frame(width: 5, height: 5)
            VStack(alignment: .leading, spacing: 0) {
                Text(day.date, format: .dateTime.month(.abbreviated).day())
                    .font(.system(.footnote, weight: .medium))
                    .foregroundStyle(tokens.ink)
                HStack(spacing: 3) {
                    Text(weekday(for: day.date))
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(tokens.inkSecondary.opacity(0.85))
                    if day.isTraveling {
                        TravelPlaneMark()
                            .fill(tokens.metal.opacity(0.60))
                            .frame(width: 8, height: 8)
                    }
                }
            }
        }
        .frame(width: dateColumnWidth, alignment: .leading)
    }

    private func weekday(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }

    // MARK: - Geometry

    /// Cell size scales down for longer periods so the matrix fits
    /// on a single iPhone screen without horizontal scrolling.
    private var cellSize: CGFloat {
        switch days.count {
        case ...7: return 30
        case ...14: return 26
        case ...30: return 20
        default: return 15
        }
    }

    private var ornamentSize: CGFloat {
        min(16, max(10, cellSize * 0.6))
    }

    private var cellSpacing: CGFloat {
        switch days.count {
        case ...7: return 7
        case ...14: return 5
        case ...30: return 3
        default: return 2
        }
    }

    private var rowSpacing: CGFloat {
        cellSpacing
    }

    private var dateColumnWidth: CGFloat {
        switch days.count {
        case ...7: return 64
        case ...14: return 60
        case ...30: return 54
        default: return 48
        }
    }

    // MARK: - Accessibility

    private func rowAccessibilityLabel(day: DayCompletion) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        let dateText = formatter.string(from: day.date)
        let count = day.onTimeCount
        let total = day.prayerCompletions.count
        if day.isPaused {
            return "\(dateText), paused day, excluded from totals"
        }
        return "\(dateText), \(count) of \(total) prayers on time"
    }
}

#Preview("Daily practice grid — 14 days") {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    let tokens = PaletteState.afternoon.tokens
    let days: [DayCompletion] = (0..<14).map { offset in
        let date = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
        let statuses: [PrayerStatus?] = [
            .onTime, .onTime, .late, .missed, [.qada, .onTime, nil].randomElement() ?? nil
        ]
        let completions = zip(Prayer.allCases, statuses).map { prayer, status in
            PrayerCompletion(
                prayer: prayer,
                status: status,
                withJamaah: prayer == .fajr && status == .onTime
            )
        }
        return DayCompletion(
            id: date,
            date: date,
            prayerCompletions: completions,
            isPaused: false,
            isTraveling: offset == 3
        )
    }
    return ScrollView {
        DailyPracticeGrid(days: days, tokens: tokens, onDayTap: { _ in }, onCellTap: { _, _ in })
            .padding()
    }
    .background(tokens.pageGroundFlat)
}
