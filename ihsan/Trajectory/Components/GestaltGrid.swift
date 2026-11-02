import SwiftUI
import IhsanCore
import IhsanDesignSystem

/// The Path's one picture of the period: a row per prayer, a column per
/// day, and the same grid is the way into any single day.
///
/// From arm's length a month of mixed states reads as a texture; each
/// mark is one prayer on one day, speaking the plate's ornament-state
/// language at dot scale:
///
/// - **On time** — the filled gilded form: leaf gold bounded by the
///   keyline.
/// - **Jamāʿah** — the gilded form ringed in the bright metal: the
///   congregation distinguishes itself by a halo, not a new hue.
/// - **Delayed** — the warm metal outline, hollow centre.
/// - **Missed** — the quiet passed form: a secondary-ink outline,
///   present but subdued. Never vermillion; the record does not
///   scold.
/// - **Qadā** — the lapis pigment bounded by metal, the sheet's own
///   made-up-later voice.
/// - **No record** — the faintest metal ring.
/// - **Not counted** — a small pip: today's prayers still to come, and
///   the days before the record began. `PathTally.isCounted` decides,
///   so the marks and the key's numbers cannot disagree.
/// - **Excused pause** — a calm neutral dash across the whole
///   column: excluded, never negative.
/// - **Travel** — the day's marks render normally and a Travel row
///   footnotes the column with the engraved plane mark.
///
/// Every row is named at the left margin. A pattern nobody can read
/// without being told which row is which was the first thing wrong with
/// the card this replaces, along with having no way in: the same data
/// was drawn a second time, flipped, thirty rows further down the page,
/// because this one could not be touched.
///
/// Tap a column, or drag across the grid, and the day card beneath
/// follows. 7 / 30 / 90 days give a column per day; a year gives a
/// column per week (modal status), and touching a week lands on its
/// latest day. Beneath the fardh rows, and only when there is something
/// in them, sit the Nafl and Dhikr presence rows.
///
/// All rows share one `GestaltLayout`, so a mark cannot land off-grid.
struct GestaltGrid: View {
    let days: [DayCompletion]
    let period: TrajectoryPeriod
    /// Resolved page tokens — the grid never picks its own colors.
    let tokens: SkyPaletteTokens
    /// Days carrying any voluntary record. Non-nil when the sunnah
    /// layer is on; a row beneath the five fardh rows — presence only,
    /// no denominator, no figure — appears only if at least one day in
    /// the window actually carries a record.
    var naflDays: Set<Date>? = nil
    /// Days carrying a recorded tasbīḥ sitting — same quiet
    /// presence-only register, same appears-only-with-data rule.
    var dhikrDays: Set<Date>? = nil
    /// The day of the earliest record anywhere. See `PathTally`.
    var recordBegan: Date? = nil
    /// The column the day card is showing. `nil` on the share image,
    /// which has no day card and takes no touches.
    var selectedColumn: Int? = nil
    /// Spoken as the grid's value: what the selected day holds.
    var selectionSummary: String? = nil
    /// A touch resolved to a column.
    var onSelectColumn: ((Int) -> Void)? = nil
    /// VoiceOver's up and down swipes: +1 is a day later, -1 a day
    /// earlier. Days rather than columns, so a year can still be walked.
    var onStepDay: ((Int) -> Void)? = nil

    /// The label gutter and row height grow with the reader's type
    /// size: a row label that clips is a row nobody can name.
    @ScaledMetric(relativeTo: .caption) private var labelGutter: CGFloat = 54
    @ScaledMetric(relativeTo: .caption) private var labelHeight: CGFloat = 16
    @ScaledMetric(relativeTo: .caption) private var axisHeight: CGFloat = 18

    /// One rendered column: the five-prayer slate plus the day-level
    /// state that colors it.
    private struct Column {
        let slate: [PrayerCompletion]
        let isPaused: Bool
        let isTraveling: Bool
        /// Whether a blank in this column counts as a gap.
        let countsBlanks: Bool
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = self.layout(availableWidth: proxy.size.width)
            let columns = self.columns

            VStack(alignment: .leading, spacing: IhsanSpacing.xs) {
                touchable(layout: layout) {
                    ZStack(alignment: .topLeading) {
                        selectionBand(layout: layout)
                        grid(columns: columns, layout: layout)
                    }
                }
                timeAxis(layout: layout)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: patternHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .modifier(AdjustableSelection(
            value: selectionSummary,
            onStepDay: onStepDay
        ))
    }

    /// The one layout every row on this card is positioned from.
    private func layout(availableWidth: CGFloat) -> GestaltLayout {
        GestaltLayout(
            period: period,
            availableWidth: availableWidth,
            labelGutter: labelGutter,
            labelHeight: labelHeight
        )
    }

    // MARK: - Touch

    /// A tap picks a column; a horizontal drag scrubs across them. The
    /// drag has to leave a vertical swipe to the page's scroll view, or
    /// the card would be a dead patch in the middle of the screen — so
    /// it is a pan that declines to begin unless it starts sideways.
    @ViewBuilder
    private func touchable<Content: View>(
        layout: GestaltLayout,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if let onSelectColumn {
            content()
                .contentShape(Rectangle())
                .onTapGesture { location in
                    onSelectColumn(layout.column(atX: location.x))
                }
                .gesture(HorizontalScrubGesture { x in
                    onSelectColumn(layout.column(atX: x))
                })
        } else {
            content()
        }
    }

    /// The selected day, as a lit band through its column. Wider than
    /// the column at the dense periods, where a column is three points
    /// across and a band that size would not be seen.
    @ViewBuilder
    private func selectionBand(layout: GestaltLayout) -> some View {
        if let selectedColumn {
            let width = max(layout.pitch, 7)
            RoundedRectangle(cornerRadius: min(width / 2, 7), style: .continuous)
                .fill(tokens.metal.opacity(0.20))
                .overlay {
                    RoundedRectangle(cornerRadius: min(width / 2, 7), style: .continuous)
                        .strokeBorder(Self.overlayMarkValue(for: tokens).color, lineWidth: 1)
                }
                .frame(width: width, height: gridHeight(layout: layout))
                .offset(x: layout.prayerDotCenter(column: selectedColumn) - width / 2)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Row labels

    private func rowLabel(_ name: String, layout: GestaltLayout) -> some View {
        Text(name)
            .font(.system(.caption, weight: .medium))
            .foregroundStyle(tokens.inkSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: layout.labelGutter, alignment: .leading)
    }

    // MARK: - Grid

    /// Opacity every overlay presence mark draws at. The overlay stays
    /// quieter than the fardh rows — visible if sought, quiet if not —
    /// but it has to be VISIBLE when sought, which at the old 0.40 of
    /// plain metal it was not on the near-white days.
    static let overlayMarkOpacity: Double = 0.85

    /// The overlay mark's colour, per panel polarity — the same rule
    /// `GestaltDot.lateOutlineValue` established: plain metal reads on
    /// a jewel panel (~6:1) and vanishes on a near-white one (~2.6:1),
    /// so the day states deepen it toward the keyline. Corrective H
    /// found the same thing for the almucantars: the same alpha buys
    /// less on a near-white field.
    static func overlayMarkValue(for tokens: SkyPaletteTokens) -> SRGBValue {
        tokens.panelFillValue.relativeLuminance < 0.5
            ? tokens.metalValue
            : SRGBValue.mix(tokens.metalValue, tokens.keylineValue, amount: 0.45)
    }

    /// Gap between the five fardh rows and the rows beneath them.
    private static let overlayGap: CGFloat = IhsanSpacing.xs

    @ViewBuilder
    private func grid(
        columns: [Column],
        layout: GestaltLayout
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(Prayer.allCases.enumerated()), id: \.element) { row, prayer in
                columnRow(
                    layout: layout,
                    count: columns.count,
                    label: prayer.displayNameEnglish
                ) { col in
                    prayerMark(column: columns[col], row: row, layout: layout)
                }
            }

            if showsAnyPresenceRow || columns.contains(where: \.isTraveling) {
                Color.clear.frame(height: Self.overlayGap)
            }

            if showsNaflRow, let naflColumns, naflColumns.count == columns.count {
                presenceRow(
                    label: "Nafl", present: naflColumns, layout: layout
                ) { present in
                    NaflPresenceMark(
                        present: present, size: layout.presenceMarkSize, tokens: tokens
                    )
                }
            }

            if showsDhikrRow, let dhikrColumns, dhikrColumns.count == columns.count {
                presenceRow(
                    label: "Dhikr", present: dhikrColumns, layout: layout
                ) { present in
                    DhikrPresenceMark(
                        present: present, size: layout.presenceMarkSize, tokens: tokens
                    )
                }
            }

            if columns.contains(where: \.isTraveling) {
                travelRow(columns: columns, layout: layout)
            }
        }
    }

    @ViewBuilder
    private func prayerMark(column: Column, row: Int, layout: GestaltLayout) -> some View {
        let completion = column.slate[row]
        let uncounted = completion.status == nil && !column.countsBlanks
        if layout.drawsTicks {
            GestaltTick(
                completion: completion,
                isPausedDay: column.isPaused,
                isUncounted: uncounted,
                width: layout.dotSize,
                height: layout.rowHeight - 3,
                tokens: tokens
            )
        } else {
            GestaltDot(
                completion: completion,
                isPausedDay: column.isPaused,
                isUncounted: uncounted,
                size: layout.dotSize,
                tokens: tokens
            )
        }
    }

    /// One row of the card: the label gutter, then one cell per column
    /// at the layout's pitch. Every row on the card is built here, so
    /// no row can acquire a spacing or an origin of its own.
    private func columnRow<Cell: View>(
        layout: GestaltLayout,
        count: Int,
        label: String,
        @ViewBuilder cell: @escaping (Int) -> Cell
    ) -> some View {
        HStack(spacing: 0) {
            rowLabel(label, layout: layout)
            HStack(spacing: 0) {
                ForEach(0..<count, id: \.self) { column in
                    cell(column)
                        .frame(width: layout.pitch)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(height: layout.rowHeight)
    }

    /// A named presence row. Its marks are dot-sized and dot-centred.
    private func presenceRow<Mark: View>(
        label: String,
        present: [Bool],
        layout: GestaltLayout,
        @ViewBuilder mark: @escaping (Bool) -> Mark
    ) -> some View {
        columnRow(
            layout: layout,
            count: present.count,
            label: label
        ) { column in
            mark(present[column])
        }
    }

    // MARK: - Which overlay rows are drawn
    //
    // A row appears when it has something in it, and never otherwise.
    // This is what replaced the two chips above the panel: they could
    // be toggled all day without changing a pixel, because a presence
    // overlay with no presences is indistinguishable from no overlay.
    // The data decides now, so the answer is always visible.

    private var showsAnyPresenceRow: Bool { showsNaflRow || showsDhikrRow }

    private var showsNaflRow: Bool {
        GestaltAggregation.hasAnyPresence(
            days: days, period: period, daysWithRecord: naflDays
        )
    }

    private var showsDhikrRow: Bool {
        GestaltAggregation.hasAnyPresence(
            days: days, period: period, daysWithRecord: dhikrDays
        )
    }

    /// Per-column presence of any voluntary record, aligned 1:1 with the
    /// fardh columns.
    ///
    /// An excused-pause column carries no mark. The pause is the app
    /// agreeing not to keep count, and the column already says so once
    /// — in the calm dash the fardh rows draw across it. Saying it
    /// twice would be keeping count of the days it agreed not to.
    private var naflColumns: [Bool]? {
        naflDays.map { presenceColumns(daysWithRecord: $0) }
    }

    private var dhikrColumns: [Bool]? {
        dhikrDays.map { presenceColumns(daysWithRecord: $0) }
    }

    private func presenceColumns(daysWithRecord: Set<Date>) -> [Bool] {
        let present = GestaltAggregation.presenceColumns(
            days: days, period: period, daysWithRecord: daysWithRecord
        )
        let paused = columns.map(\.isPaused)
        guard paused.count == present.count else { return present }
        return zip(present, paused).map { $0 && !$1 }
    }

    /// Travel is a named row rather than an unexplained symbol beneath
    /// the pattern.
    private func travelRow(
        columns: [Column],
        layout: GestaltLayout
    ) -> some View {
        let markSize: CGFloat = max(6, min(10, layout.dotSize + 4))
        return columnRow(
            layout: layout,
            count: columns.count,
            label: "Travel"
        ) { col in
            if columns[col].isTraveling {
                if layout.pitch >= markSize {
                    TravelPlaneMark()
                        .fill(tokens.metal.opacity(0.60))
                        .frame(width: markSize, height: markSize)
                } else {
                    // A plane does not fit a three-point column.
                    Capsule()
                        .fill(Self.overlayMarkValue(for: tokens).color.opacity(Self.overlayMarkOpacity))
                        .frame(width: max(1.5, layout.dotSize), height: markSize)
                }
            } else {
                Color.clear.frame(width: 1, height: 1)
            }
        }
    }

    /// The window's two ends, in dates rather than "earlier", and the
    /// one thing this card can do that nothing about it shows.
    private func timeAxis(layout: GestaltLayout) -> some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: layout.labelGutter, height: 1)
            if let first = axisStart {
                Text(first, format: .dateTime.month(.abbreviated).day())
            }
            Spacer(minLength: IhsanSpacing.sm)
            if onSelectColumn != nil {
                Text(period == .year ? "Tap a week" : "Tap a day")
                Spacer(minLength: IhsanSpacing.sm)
            }
            Text(period == .year ? "This week" : "Today")
        }
        .font(.caption2)
        .foregroundStyle(tokens.inkSecondary)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .frame(height: axisHeight)
    }

    private var axisStart: Date? {
        switch period {
        case .year: GestaltAggregation.yearWeekDayGroups(days: days).first?.first?.date
        default: days.first?.date
        }
    }

    // MARK: - Columns source

    /// For 7 / 30 / 90 days returns the `days`' five-prayer slates with
    /// their day states. For a year returns 52 week-aggregated columns —
    /// week columns carry no pause/travel footnote (the aggregation
    /// already abstracts the day).
    private var columns: [Column] {
        switch period {
        case .year:
            let newest = days.last?.date
            let weeks = GestaltAggregation.yearWeekDayGroups(days: days)
            return GestaltAggregation.yearWeekColumns(days: days).enumerated().map { index, slate in
                // A week counts its blanks unless it holds the current
                // day or wholly predates the record.
                let latest = weeks[index].last?.date
                let countsBlanks = latest.map {
                    PathTally.isCounted(dayDate: $0, newestDay: newest, recordBegan: recordBegan)
                } ?? true
                return Column(
                    slate: slate,
                    isPaused: false,
                    isTraveling: false,
                    countsBlanks: countsBlanks
                )
            }
        default:
            let newest = days.last?.date
            return days.map {
                Column(
                    slate: $0.prayerCompletions,
                    isPaused: $0.isPaused,
                    isTraveling: $0.isTraveling,
                    countsBlanks: PathTally.isCounted(
                        dayDate: $0.date, newestDay: newest, recordBegan: recordBegan
                    )
                )
            }
        }
    }

    // MARK: - Height

    /// The rows' height is independent of width, so the parent's VStack
    /// has a stable height before layout runs. Counts only the rows that
    /// will actually be drawn — a panel that reserves space for an
    /// empty presence row is a panel with a hole in it.
    private func gridHeight(layout: GestaltLayout) -> CGFloat {
        let extraRows = (showsNaflRow ? 1 : 0)
            + (showsDhikrRow ? 1 : 0)
            + (days.contains(where: \.isTraveling) && period != .year ? 1 : 0)
        return CGFloat(5 + extraRows) * layout.rowHeight
            + (extraRows > 0 ? Self.overlayGap : 0)
    }

    private var patternHeight: CGFloat {
        // Width plays no part in the height; any width will do.
        let layout = GestaltLayout(
            period: period,
            availableWidth: 400,
            labelGutter: labelGutter,
            labelHeight: labelHeight
        )
        return gridHeight(layout: layout) + IhsanSpacing.xs + axisHeight
    }

    // MARK: - Accessibility

    /// "4 of the last 30" — a count of days with a record, never a
    /// share of them. A presence row has no denominator, because a
    /// denominator is the first half of a score.
    private func presenceSummary(_ columns: [Bool]?) -> String {
        let marked = columns?.filter { $0 }.count ?? 0
        return marked == 1 ? "one day" : "\(marked) days"
    }

    private var accessibilityLabel: String {
        let span: String
        switch period {
        case .sevenDays: span = "the last 7 days"
        case .thirtyDays: span = "the last 30 days"
        case .ninetyDays: span = "the last 90 days"
        case .year: span = "the last year, by week"
        }
        var label = "Your prayers across \(span). Five rows, Fajr at top through Isha at bottom. Today is the rightmost column."
        if days.contains(where: \.isPaused) {
            label += " Paused days show as neutral dashes and are not counted."
        }
        if days.contains(where: \.isTraveling) {
            label += " Traveling days carry a small plane mark."
        }
        if showsNaflRow {
            label += " A row labelled Nafl marks the days"
                + " carrying voluntary prayer: \(presenceSummary(naflColumns))."
        }
        if showsDhikrRow {
            label += " A row labelled Dhikr marks the days carrying a recorded"
                + " sitting: \(presenceSummary(dhikrColumns))."
        }
        return label
    }
}

// MARK: - The selection, for VoiceOver

/// The grid is one element under VoiceOver. A hundred and fifty buttons,
/// one per mark, is a wall to walk; an adjustable element that says what
/// the day holds, and moves a day at a time, is a conversation.
private struct AdjustableSelection: ViewModifier {
    let value: String?
    let onStepDay: ((Int) -> Void)?

    func body(content: Content) -> some View {
        if let value, let onStepDay {
            content
                .accessibilityValue(value)
                .accessibilityHint("Swipe up for a later day, down for an earlier one.")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: onStepDay(1)
                    case .decrement: onStepDay(-1)
                    @unknown default: break
                    }
                }
        } else {
            content
        }
    }
}

// MARK: - Scrubbing

/// A pan that begins only when the finger starts sideways, reporting the
/// touch's x. SwiftUI's `DragGesture` cannot make that choice before it
/// has already taken the touch from the scroll view around it.
private struct HorizontalScrubGesture: UIGestureRecognizerRepresentable {
    let onChange: (CGFloat) -> Void

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        return pan
    }

    func handleUIGestureRecognizerAction(
        _ recognizer: UIPanGestureRecognizer, context: Context
    ) {
        switch recognizer.state {
        case .began, .changed:
            onChange(context.converter.localLocation.x)
        default:
            break
        }
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer else { return true }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y)
        }
    }
}

// MARK: - Dhikr presence mark

/// One cell of the dhikr row: a small filled bead where the day (or
/// week) holds a recorded sitting, and nothing at all where it does
/// not — absence in a presence row is empty space, never an outline.
///
/// Filled rather than hollow, deliberately: a hollow ring is exactly
/// what an UNLOGGED fardh cell draws, so an outlined dhikr mark said
/// "nothing happened here" in the one row where it means the
/// opposite.
private struct DhikrPresenceMark: View {
    let present: Bool
    let size: CGFloat
    let tokens: SkyPaletteTokens

    var body: some View {
        Group {
            if present {
                Circle()
                    .fill(
                        GestaltGrid.overlayMarkValue(for: tokens).color
                            .opacity(GestaltGrid.overlayMarkOpacity)
                    )
                    .padding(size * 0.26)
            } else {
                Color.clear
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Nafl presence mark

/// One cell of the nafl row: a short rounded stroke where the
/// day (or week) holds any voluntary record — empty space where it
/// does not.
///
/// Filled at every size now. The stroked form above 8 pt was the row's
/// legibility problem: a hairline star at dot scale reads as debris on
/// the panel rather than as a mark in a row, which is how a row of
/// them came to look like marks floating in empty space.
private struct NaflPresenceMark: View {
    let present: Bool
    let size: CGFloat
    let tokens: SkyPaletteTokens

    var body: some View {
        Group {
            if present {
                RoundedRectangle(cornerRadius: size, style: .continuous)
                    .fill(
                        GestaltGrid.overlayMarkValue(for: tokens).color
                            .opacity(GestaltGrid.overlayMarkOpacity)
                    )
                    .frame(width: size * 0.78, height: max(2, size * 0.30))
            } else {
                Color.clear
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - GestaltDot

/// A single mark in the gestalt grid — the ornament-state language at
/// dot scale. Static treatment functions expose the exact values so
/// `PathPatternContrastTests` audits what the dots render.
struct GestaltDot: View {
    let completion: PrayerCompletion
    /// The whole day is excused: every mark in the column renders the
    /// calm neutral dash.
    var isPausedDay: Bool = false
    /// A blank that is not a gap: drawn as a small pip. See `PathTally`.
    var isUncounted: Bool = false
    let size: CGFloat
    let tokens: SkyPaletteTokens

    /// The qadā body at dot scale — the sheet's lifted-lapis rule.
    static func qadaBodyValue(for tokens: SkyPaletteTokens) -> SRGBValue {
        tokens.panelFillValue.relativeLuminance < 0.5
            ? tokens.lapisValue.scalingLightness(by: 1.4)
            : tokens.lapisValue
    }

    /// The missed outline — quiet secondary ink, present but subdued.
    static func missedOutlineValue(for tokens: SkyPaletteTokens) -> SRGBValue {
        tokens.inkSecondaryValue
    }

    /// Below `keylineFloor` the dot drops its keyline — at 3 pt a
    /// 0.5 pt stroke has no line to draw. That matters, because on the
    /// near-white day panels a gilded body is only resolvable BECAUSE
    /// of its dark edge: bare `leafGold` measures ~2.4:1 there, and
    /// lifted lapis ~2.5:1 on sunset's panel. So where the edge cannot
    /// be drawn, the body carries the separation itself.
    ///
    /// Same rule as `lateOutlineValue` and corrective H's almucantars:
    /// the same value buys less on a near-white field, so the day
    /// states deepen toward the keyline. The large-size rendering is
    /// untouched — there the edge still does the work.
    static let keylineFloor: CGFloat = 6

    /// The on-time body as drawn when no keyline accompanies it.
    static func onTimeBodyValue(for tokens: SkyPaletteTokens, size: CGFloat) -> SRGBValue {
        guard size < keylineFloor else { return tokens.leafGoldValue }
        return tokens.panelFillValue.relativeLuminance < 0.5
            ? tokens.leafGoldValue
            : SRGBValue.mix(tokens.leafGoldValue, tokens.keylineValue, amount: 0.40)
    }

    /// The qadā body as drawn when no keyline accompanies it.
    static func qadaBodyValue(for tokens: SkyPaletteTokens, size: CGFloat) -> SRGBValue {
        let base = qadaBodyValue(for: tokens)
        guard size < keylineFloor else { return base }
        return base.contrastRatio(against: tokens.panelFillValue) >= 3.0
            ? base
            : SRGBValue.mix(base, tokens.inkValue, amount: 0.35)
    }

    /// The late outline — the sheet's rule at dot scale: warm metal on
    /// jewel panels; deepened toward the keyline on the near-white
    /// days, where plain metal falls under the 3:1 floor.
    static func lateOutlineValue(for tokens: SkyPaletteTokens) -> SRGBValue {
        tokens.panelFillValue.relativeLuminance < 0.5
            ? tokens.metalValue
            : SRGBValue.mix(tokens.metalValue, tokens.keylineValue, amount: 0.30)
    }

    var body: some View {
        Group {
            if isPausedDay {
                // The excused dash: calm neutral, excluded, never
                // negative.
                RoundedRectangle(cornerRadius: size, style: .continuous)
                    .fill(tokens.inkSecondary.opacity(0.35))
                    .frame(width: size, height: max(1, size * 0.22))
                    .frame(width: size, height: size)
            } else if isUncounted {
                Circle()
                    .fill(tokens.metal.opacity(0.45))
                    .frame(width: max(2, size * 0.26), height: max(2, size * 0.26))
            } else {
                mark
            }
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private var mark: some View {
        let keylineWidth = max(0.5, size * 0.09)
        switch (completion.status, completion.withJamaah) {
        case (.onTime, true):
            // The jamāʿah halo: the gilded form ringed in bright metal.
            // At tiny scales the ring has no room — the brighter
            // highlight fill carries the distinction instead.
            if size >= 10 {
                ZStack {
                    Circle()
                        .fill(tokens.leafGold)
                        .overlay {
                            Circle().strokeBorder(
                                tokens.keyline.opacity(0.9), lineWidth: keylineWidth
                            )
                        }
                        .padding(size * 0.18)
                    Circle().strokeBorder(
                        tokens.metalHighlight.opacity(0.95),
                        lineWidth: max(0.6, size * 0.08)
                    )
                }
            } else {
                Circle().fill(tokens.metalHighlight)
            }
        case (.onTime, _):
            if size >= Self.keylineFloor {
                Circle()
                    .fill(tokens.leafGold)
                    .overlay {
                        Circle().strokeBorder(
                            tokens.keyline.opacity(0.9), lineWidth: keylineWidth
                        )
                    }
            } else {
                Circle().fill(Self.onTimeBodyValue(for: tokens, size: size).color)
            }
        case (.qada, _):
            if size >= Self.keylineFloor {
                Circle()
                    .fill(Self.qadaBodyValue(for: tokens).color)
                    .overlay {
                        Circle().strokeBorder(
                            tokens.metal.opacity(0.9), lineWidth: keylineWidth
                        )
                    }
            } else {
                Circle().fill(Self.qadaBodyValue(for: tokens, size: size).color)
            }
        case (.late, _):
            Circle()
                .strokeBorder(
                    Self.lateOutlineValue(for: tokens).color.opacity(0.95),
                    lineWidth: max(0.6, size * 0.20)
                )
        case (.missed, _):
            Circle()
                .strokeBorder(
                    Self.missedOutlineValue(for: tokens).color.opacity(0.60),
                    lineWidth: max(0.5, size * 0.16)
                )
        case (.none, _):
            Circle()
                .strokeBorder(
                    tokens.metal.opacity(0.28),
                    lineWidth: max(0.5, size * 0.16)
                )
        }
    }
}

// MARK: - GestaltTick

/// The mark at the long periods, where a column is a few points wide
/// and a hollow ring has no room to be hollow. Colour still says which
/// state, from `GestaltDot`'s audited values, and height says how much
/// happened: a stroke the full height of its row for a prayer offered
/// on time or made up, a shorter one for delayed, and a low stub where
/// nothing was prayed. Read along a row, a steady prayer is an unbroken
/// band, and a gap is a visible dip.
struct GestaltTick: View {
    let completion: PrayerCompletion
    var isPausedDay: Bool = false
    var isUncounted: Bool = false
    let width: CGFloat
    let height: CGFloat
    let tokens: SkyPaletteTokens

    var body: some View {
        Capsule(style: .continuous)
            .fill(color)
            .frame(width: max(1, width), height: height * heightShare)
            .frame(width: max(1, width), height: height, alignment: .bottom)
    }

    private var heightShare: CGFloat {
        if isPausedDay || isUncounted { return 0.14 }
        switch completion.status {
        case .onTime, .qada: return 1
        case .late: return 0.6
        case .missed, nil: return 0.26
        }
    }

    private var color: Color {
        if isPausedDay { return tokens.inkSecondary.opacity(0.35) }
        if isUncounted { return tokens.metal.opacity(0.45) }
        // At a tick's width there is no keyline, so the bodies use the
        // same keyline-less values the small dots do.
        switch (completion.status, completion.withJamaah) {
        case (.onTime, true):
            return tokens.metalHighlight
        case (.onTime, _):
            return GestaltDot.onTimeBodyValue(for: tokens, size: width).color
        case (.qada, _):
            return GestaltDot.qadaBodyValue(for: tokens, size: width).color
        case (.late, _):
            return GestaltDot.lateOutlineValue(for: tokens).color.opacity(0.95)
        case (.missed, _):
            return GestaltDot.missedOutlineValue(for: tokens).color.opacity(0.60)
        case (.none, _):
            return tokens.metal.opacity(0.28)
        }
    }
}
