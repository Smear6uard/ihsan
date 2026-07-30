import SwiftUI
import IhsanCore
import IhsanDesignSystem

/// The day-by-day detail grid that sits beneath the gestalt dot pattern.
///
/// Renders the period's days as rows and the five fardh prayers as
/// columns; each cell is a `DayPrayerCell` carrying both status and
/// jamaʿah modifier in one small illuminated square. The gestalt grid
/// above is the visual headline of the screen; this matrix exists for
/// the user who wants to drill into the specific outcomes — which day,
/// which prayer.
///
/// The grid is wrapped in an illuminated parchment panel so it reads
/// as one composed surface — the period's record laid out on a single
/// page of the manuscript — rather than as a free-floating chart.
struct DailyPracticeGrid: View {
    let days: [DayCompletion]
    let onDayTap: (DayCompletion) -> Void
    /// A cell tap opens the log sheet for that prayer and day — the
    /// canonical way to log yesterday and earlier.
    let onCellTap: (DayCompletion, PrayerCompletion) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.md) {
            sectionHeader

            columnHeaders

            // Rows render newest-first so today sits at the top of
            // the grid (matches the spec mockup; matches user
            // intuition that the most recent record reads first).
            VStack(spacing: rowSpacing) {
                ForEach(days.reversed()) { day in
                    row(for: day)
                }
            }
        }
        .padding(IhsanSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ihsanIlluminatedPanel(intensity: .regular)
    }

    // MARK: - Header

    private var sectionHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("DAILY PRACTICE")
                .font(IhsanFont.inscription)
                .tracking(1.8)
                .foregroundStyle(IhsanColor.brassDark)
            Spacer()
            if let range = dateRangeText {
                Text(range)
                    .font(IhsanFont.inscription)
                    .tracking(1.4)
                    .foregroundStyle(IhsanColor.brassDark.opacity(0.75))
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

    // MARK: - Column headers (prayer abbreviations)

    private var columnHeaders: some View {
        HStack(spacing: cellSpacing) {
            // Left gutter matches the date column width below so the
            // five prayer codes align with their cells.
            Color.clear.frame(width: dateColumnWidth)
            ForEach(Prayer.allCases, id: \.self) { prayer in
                Text(prayer.threeLetterCode)
                    .font(IhsanFont.inscription)
                    .tracking(1.2)
                    .foregroundStyle(IhsanColor.brassDark.opacity(0.85))
                    .frame(width: cellSize, alignment: .center)
            }
            Spacer(minLength: 0)
        }
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
                    DayPrayerCell(completion: completion, size: cellSize)
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
        switch completion.status {
        case .onTime: statusText = completion.withJamaah
            ? "on time, in \(IhsanVocabulary.jamaah)" : "on time"
        case .late: statusText = "late"
        case .missed: statusText = "missed"
        case .qada: statusText = "qadā"
        case nil: statusText = "not logged"
        }
        return "\(completion.prayer.displayNameEnglish), \(dateText), \(statusText)"
    }

    private func dateLabel(for day: DayCompletion, isToday: Bool) -> some View {
        HStack(spacing: 4) {
            // Today gets a small brass dot to its left — the manuscript
            // equivalent of "you are here".
            Circle()
                .fill(isToday ? IhsanColor.brass : .clear)
                .frame(width: 5, height: 5)
            VStack(alignment: .leading, spacing: 0) {
                Text(dayOfMonth(for: day.date))
                    .font(.system(size: 16, weight: .medium, design: .serif))
                    .foregroundStyle(IhsanColor.inkDeep)
                Text(dayOfWeek(for: day.date))
                    .font(.system(size: 10, weight: .semibold, design: .default).smallCaps())
                    .tracking(1.0)
                    .foregroundStyle(IhsanColor.brassDark.opacity(0.75))
            }
        }
        .frame(width: dateColumnWidth, alignment: .leading)
    }

    private func dayOfMonth(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func dayOfWeek(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }

    // MARK: - Geometry

    /// Cell size scales down for longer periods so the matrix fits
    /// on a single iPhone screen without horizontal scrolling. The
    /// gestalt dot grid above is the visual headline now, so the
    /// detail-grid cells are demoted to ~85% of their previous size —
    /// still legible, no longer dominant.
    private var cellSize: CGFloat {
        switch days.count {
        case ...7: return 30
        case ...14: return 26
        case ...30: return 20
        default: return 15
        }
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

private extension Prayer {
    /// Three-letter small-caps code rendered in the column header.
    var threeLetterCode: String {
        switch self {
        case .fajr: return "FAJ"
        case .dhuhr: return "DHU"
        case .asr: return "ASR"
        case .maghrib: return "MAG"
        case .isha: return "ISH"
        }
    }
}

#Preview("Daily practice grid — 14 days") {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
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
            isTraveling: false
        )
    }
    return ScrollView {
        DailyPracticeGrid(days: days, onDayTap: { _ in }, onCellTap: { _, _ in })
            .padding()
    }
    .ihsanManuscriptPage()
}
