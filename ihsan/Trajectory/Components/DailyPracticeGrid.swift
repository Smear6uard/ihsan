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
    /// What each cycle holds beyond its five fardh, keyed by cycle
    /// date. Empty until the sunnah layer or the tasbīḥ has been used.
    var voluntary: [Date: DayVoluntaryDetail] = [:]
    /// A cell tap opens the log sheet for that prayer and day.
    let onCellTap: (DayCompletion, PrayerCompletion) -> Void

    /// The one row showing its detail, if any. Tapping a date opens
    /// it; tapping the same date again closes it.
    ///
    /// `-IhsanDebugExpandPracticeDay N` opens the Nth row from the top
    /// for the capture harness — a screenshot of an expansion nobody
    /// can tap open is a screenshot of the collapsed state.
    @State private var expandedDay: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let debugExpandRow: Int? = DebugLaunch.value(
        after: "-IhsanDebugExpandPracticeDay"
    ).flatMap(Int.init)

    var body: some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.md) {
            sectionHeader

            columnHeaders

            // Rows render newest-first so today sits at the top of
            // the grid.
            VStack(spacing: rowSpacing) {
                ForEach(days.reversed()) { day in
                    row(for: day)
                    if expandedDay == day.date, let detail = voluntary[day.date],
                       !detail.isEmpty {
                        voluntaryDetail(detail)
                    }
                }
            }
        }
        .padding(IhsanSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .celestialPanel(tokens: tokens, cornerRadius: 18)
        .onAppear {
            guard let index = debugExpandRow else { return }
            let newestFirst = Array(days.reversed())
            guard newestFirst.indices.contains(index) else { return }
            expandedDay = newestFirst[index].date
        }
        // A data matrix cannot reflow per-glyph: cap type growth here
        // and let the per-day VoiceOver summaries carry the detail at
        // accessibility sizes.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
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
                // Reduce Motion gets the same answer without the
                // growth — the detail appears, it does not arrive.
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) {
                    expandedDay = expandedDay == day.date ? nil : day.date
                }
            } label: {
                dateLabel(for: day, isToday: isToday)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(voluntary[day.date]?.isEmpty ?? true)
            .accessibilityLabel(rowAccessibilityLabel(day: day))
            .accessibilityHint(
                (voluntary[day.date]?.isEmpty ?? true)
                    ? ""
                    : "Shows this day's voluntary worship."
            )

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

    // MARK: - The day's voluntary detail

    /// What the tapped cycle held beyond its five, in the register the
    /// rest of the card uses: named, ordered, and finished.
    ///
    /// No percentage, no total, and nothing carried across days. The
    /// question this answers is "what did I offer that day", and the
    /// honest answer is a list.
    @ViewBuilder
    private func voluntaryDetail(_ detail: DayVoluntaryDetail) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if !detail.naflKinds.isEmpty {
                detailSection(label: "NAFL") {
                    ChipFlow(spacing: 6) {
                        ForEach(Array(detail.naflKinds.enumerated()), id: \.offset) { _, kind in
                            naflChip(kind)
                        }
                    }
                }
            }
            if !detail.sittings.isEmpty {
                detailSection(label: "DHIKR") {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(detail.sittings) { sitting in
                            Text("\(sitting.label) · \(sitting.count)")
                                .font(.system(.caption, design: .serif))
                                .foregroundStyle(tokens.ink)
                        }
                    }
                }
            }
        }
        .padding(.leading, dateColumnWidth)
        .padding(.top, 2)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(detail.spokenSummary)
        .transition(reduceMotion ? .identity : .opacity)
    }

    @ViewBuilder
    private func detailSection<Content: View>(
        label: String, @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(IhsanFont.inscription)
                .tracking(1.3)
                .foregroundStyle(tokens.inkSecondary)
                .frame(width: 44, alignment: .leading)
            content()
        }
    }

    /// One recorded voluntary prayer: the ornament of the fard it
    /// surrounds where it has one, the four-pointed mark where it
    /// stands alone, and its name.
    private func naflChip(_ kind: NaflKind) -> some View {
        HStack(spacing: 4) {
            Group {
                if let fard = kind.surroundedFard {
                    PrayerOrnamentShape(prayer: fard, mode: .outline)
                        .stroke(tokens.metal.opacity(0.85), lineWidth: 0.9)
                } else {
                    FourPointedStar()
                        .fill(tokens.metal.opacity(0.85))
                }
            }
            .frame(width: 9, height: 9)
            Text(kind.displayNameEnglish)
                .font(.system(.caption2, weight: .medium))
                .foregroundStyle(tokens.ink)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background {
            Capsule(style: .continuous)
                .strokeBorder(tokens.keyline.opacity(0.35), lineWidth: 0.6)
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
                ? "\(PrayerStatus.onTime.spokenLabel), in \(IhsanVocabulary.jamaah)"
                : PrayerStatus.onTime.spokenLabel
            case .some(let status): statusText = status.spokenLabel
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
                    if day.needsReview {
                        // Two records of one prayer, kept rather than
                        // resolved. A hollow keyline ring — a question
                        // in the sheet's own hand, not a warning.
                        Circle()
                            .strokeBorder(tokens.keyline.opacity(0.75), lineWidth: 1)
                            .frame(width: 7, height: 7)
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
        let base = "\(dateText), \(count) of \(total) prayers on time"
        return day.needsReview
            ? "\(base). Two entries for one prayer, kept for your review."
            : base
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
    let voluntary: [Date: DayVoluntaryDetail] = [
        days[1].date: DayVoluntaryDetail(
            naflKinds: [.rawatibBefore(.fajr), .duha, .witr],
            sittings: [
                .init(id: UUID(), label: "Subḥān Allāh", count: 33),
                .init(id: UUID(), label: "Astaghfirullāh", count: 100)
            ]
        )
    ]
    return ScrollView {
        DailyPracticeGrid(
            days: days, tokens: tokens, voluntary: voluntary, onCellTap: { _, _ in }
        )
        .padding()
    }
    .background(tokens.pageGroundFlat)
}

// MARK: - Chip flow

/// A one-purpose wrapping row: chips laid left to right, wrapping when
/// the line runs out. A grid would give every chip the widest chip's
/// width, and "Duha" beside "Before Maghrib" would sit in a column of
/// air.
private struct ChipFlow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(
        proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = self.rows(subviews: subviews, width: width)
        let height = rows.reduce(0) { $0 + $1.height } +
            spacing * CGFloat(max(0, rows.count - 1))
        let widest = rows.map(\.width).max() ?? 0
        return CGSize(width: min(width, max(widest, 0)), height: height)
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        var y = bounds.minY
        for row in rows(subviews: subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let advance = current.indices.isEmpty ? size.width : size.width + spacing
            if !current.indices.isEmpty, current.width + advance > width {
                rows.append(current)
                current = Row()
                current.indices = [index]
                current.width = size.width
                current.height = size.height
            } else {
                current.indices.append(index)
                current.width += advance
                current.height = max(current.height, size.height)
            }
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
