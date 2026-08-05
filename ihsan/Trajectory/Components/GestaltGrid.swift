import SwiftUI
import IhsanCore
import IhsanDesignSystem

/// The visual heart of the Path screen — a 5×N matrix of small marks
/// that lets the user read their pattern of prayer at a glance,
/// before any number is shown. The gestalt IS the headline: from
/// arm's length a month of mixed states reads as a texture; on
/// inspection each mark is one prayer on one day, speaking the
/// plate's ornament-state language at dot scale:
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
/// - **Unlogged / future** — the faintest metal ring.
/// - **Excused pause** — a calm neutral dash across the whole
///   column: excluded, never negative.
/// - **Travel** — the day's marks render normally and the column is
///   footnoted with the engraved plane mark.
///
/// Five rows, Fajr at top through Isha at bottom. 7D/30D/90D give a
/// column per day; YEAR gives a column per week (modal status).
///
/// Beneath the fardh rows, and only when there is something in them,
/// sit the two presence rows — NAFL and DHIKR — each named at the left
/// margin where a row label belongs. Nothing switches them on: they
/// follow the data, because the switches that used to govern them could
/// be flipped without changing a single pixel.
///
/// The rows share the fardh columns exactly: one `GestaltLayout`
/// positions all seven, so a mark cannot land off-grid. They earn a
/// label rather than a key underneath — a key names a mark, a label
/// names a ROW, and what these needed was to be read as rows.
struct GestaltGrid: View {
    let days: [DayCompletion]
    let period: TrajectoryPeriod
    /// Resolved page tokens — the grid never picks its own colors.
    let tokens: SkyPaletteTokens
    /// Days carrying any voluntary record. Non-nil when the sunnah
    /// layer is on; it adds a sixth, quieter row beneath the five fardh
    /// rows — presence only, no denominator, no figure.
    ///
    /// The row appears only if at least one day in the window actually
    /// carries a record. There is no switch for it and there should not
    /// be: the control this replaced could be toggled all day without
    /// changing a pixel, because an overlay of nothing looks exactly
    /// like no overlay.
    var naflDays: Set<Date>? = nil
    /// Days carrying a recorded tasbīḥ sitting — same quiet
    /// presence-only register, same appears-only-with-data rule.
    var dhikrDays: Set<Date>? = nil

    /// The label gutter and row height grow with the reader's type
    /// size: a row label that clips is a row nobody can name, which is
    /// the defect this card is being corrected for.
    @ScaledMetric(relativeTo: .caption2) private var labelGutter: CGFloat = 46
    @ScaledMetric(relativeTo: .caption2) private var labelHeight: CGFloat = 13

    /// One rendered column: the five-prayer slate plus the day-level
    /// state that colors it.
    private struct Column {
        let slate: [PrayerCompletion]
        let isPaused: Bool
        let isTraveling: Bool
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = self.layout(availableWidth: proxy.size.width)
            let columns = self.columns

            VStack(spacing: IhsanSpacing.sm) {
                grid(columns: columns, layout: layout)
                annotationRow(columns: columns, layout: layout)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: patternHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    /// The one layout every row on this card is positioned from.
    ///
    /// The gutter exists only when there is a row to name. A card with
    /// no voluntary record in the window keeps its full width for the
    /// pattern and shows no labels at all — pristine, which is the
    /// state most cards are in.
    private func layout(availableWidth: CGFloat) -> GestaltLayout {
        GestaltLayout(
            period: period,
            availableWidth: availableWidth,
            labelGutter: showsAnyPresenceRow ? labelGutter : 0,
            labelHeight: showsAnyPresenceRow ? labelHeight : 0
        )
    }

    private var showsAnyPresenceRow: Bool { showsNaflRow || showsDhikrRow }

    // MARK: - Row labels

    /// Small caps at the left margin, where the fardh rows' own labels
    /// would sit if the pattern named them. `inkSecondary`: present to
    /// anyone who looks for it, quiet to anyone reading the texture.
    private func rowLabel(_ name: String, layout: GestaltLayout) -> some View {
        Text(name)
            .font(IhsanFont.inscription)
            .tracking(1.3)
            .foregroundStyle(tokens.inkSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(
                width: max(0, layout.labelGutter - Self.labelInset),
                alignment: .trailing
            )
            .padding(.trailing, Self.labelInset)
    }

    /// Breathing room between a label and the first column.
    private static let labelInset: CGFloat = 6


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

    /// Gap between the five fardh rows and the presence overlays.
    private static let overlayGap: CGFloat = IhsanSpacing.xs

    @ViewBuilder
    private func grid(
        columns: [Column],
        layout: GestaltLayout
    ) -> some View {
        VStack(spacing: GestaltLayout.rowSpacing(for: period)) {
            ForEach(0..<5, id: \.self) { row in
                columnRow(layout: layout, count: columns.count) { col in
                    GestaltDot(
                        completion: columns[col].slate[row],
                        isPausedDay: columns[col].isPaused,
                        size: layout.dotSize,
                        tokens: tokens
                    )
                }
            }

            if showsAnyPresenceRow {
                // The presence rows are a different register from the
                // five fardh rows — presence, not status. A row at the
                // grid's own spacing read as a sixth prayer.
                Color.clear.frame(height: Self.overlayGap)
            }

            if showsNaflRow, let naflColumns, naflColumns.count == columns.count {
                presenceRow(
                    label: "NAFL", present: naflColumns, layout: layout
                ) { present in
                    NaflPresenceMark(
                        present: present, size: layout.presenceMarkSize, tokens: tokens
                    )
                }
            }

            if showsDhikrRow, let dhikrColumns, dhikrColumns.count == columns.count {
                presenceRow(
                    label: "DHIKR", present: dhikrColumns, layout: layout
                ) { present in
                    DhikrPresenceMark(
                        present: present, size: layout.presenceMarkSize, tokens: tokens
                    )
                }
            }
        }
    }

    /// One row of the card: the label gutter, then one cell per column
    /// at the layout's pitch. Every row on the card is built here, so
    /// no row can acquire a spacing or an origin of its own.
    private func columnRow<Cell: View>(
        layout: GestaltLayout,
        count: Int,
        label: String? = nil,
        rowHeight: CGFloat? = nil,
        @ViewBuilder cell: @escaping (Int) -> Cell
    ) -> some View {
        // The gutter sits OUTSIDE the spaced stack. Inside it, the
        // stack's own spacing would be added after the label and every
        // column would start one gap further right than
        // `GestaltLayout` says it does — the layout value has to
        // describe the view exactly, or the test that holds the rows
        // together is testing arithmetic nobody renders.
        HStack(spacing: 0) {
            if layout.labelGutter > 0 {
                if let label {
                    rowLabel(label, layout: layout)
                } else {
                    Color.clear.frame(width: layout.labelGutter, height: 1)
                }
            }
            HStack(spacing: layout.spacing) {
                ForEach(0..<count, id: \.self) { column in
                    cell(column)
                        .frame(width: layout.dotSize)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(height: rowHeight)
    }

    /// A named presence row. Its marks are dot-sized and dot-centred;
    /// only the row's HEIGHT differs, so an eleven-point label has
    /// somewhere to sit at the periods where the dots are three points
    /// apart.
    private func presenceRow<Mark: View>(
        label: String,
        present: [Bool],
        layout: GestaltLayout,
        @ViewBuilder mark: @escaping (Bool) -> Mark
    ) -> some View {
        columnRow(
            layout: layout,
            count: present.count,
            label: label,
            rowHeight: layout.presenceRowHeight
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

    /// The under-column annotations: the four-pointed star under the
    /// rightmost column ("you are here"), and the engraved plane mark
    /// under travel columns when the scale gives it room. Built through
    /// the same row helper as every other row, so the marks land under
    /// their columns by construction rather than by agreement.
    private func annotationRow(
        columns: [Column],
        layout: GestaltLayout
    ) -> some View {
        let starSize: CGFloat = max(6, min(10, layout.dotSize + 4))
        let planeVisible = layout.dotSize >= 5
        return columnRow(layout: layout, count: columns.count) { col in
            Group {
                if col == columns.count - 1 {
                    FourPointedStar()
                        .fill(tokens.metal.opacity(0.95))
                        .frame(width: starSize, height: starSize)
                } else if columns[col].isTraveling, planeVisible {
                    TravelPlaneMark()
                        .fill(tokens.metal.opacity(0.60))
                        .frame(width: starSize, height: starSize)
                } else {
                    Color.clear
                        .frame(width: 1, height: 1)
                }
            }
            .frame(width: layout.dotSize, alignment: .center)
        }
    }

    // MARK: - Columns source

    /// For 7D / 30D / 90D returns the `days`' five-prayer slates with
    /// their day states. For YEAR returns 52 week-aggregated columns —
    /// week columns carry no pause/travel footnote (the aggregation
    /// already abstracts the day).
    private var columns: [Column] {
        switch period {
        case .year:
            return GestaltAggregation.yearWeekColumns(days: days).map {
                Column(slate: $0, isPaused: false, isTraveling: false)
            }
        default:
            return days.map {
                Column(
                    slate: $0.prayerCompletions,
                    isPaused: $0.isPaused,
                    isTraveling: $0.isTraveling
                )
            }
        }
    }

    // MARK: - Height

    /// The pattern block needs a stable height for the parent's VStack
    /// before layout runs; `GestaltLayout` recomputes spacing per
    /// device inside, but height barely varies across the supported
    /// widths, so it is derived from the spec sizes here.
    ///
    /// Counts only the rows that will actually be drawn — a panel that
    /// reserves space for an empty presence row is a panel with a hole
    /// in it.
    private var patternHeight: CGFloat {
        let layout = GestaltLayout(
            period: period,
            availableWidth: .greatestFiniteMagnitude,
            labelGutter: showsAnyPresenceRow ? labelGutter : 0,
            labelHeight: showsAnyPresenceRow ? labelHeight : 0
        )
        let spacing = GestaltLayout.rowSpacing(for: period)
        let presenceRows = (showsNaflRow ? 1 : 0) + (showsDhikrRow ? 1 : 0)
        let rowCount = CGFloat(5 + presenceRows)

        var height = 5 * layout.dotSize
            + CGFloat(presenceRows) * layout.presenceRowHeight
            + (rowCount - 1) * spacing
        if presenceRows > 0 { height += Self.overlayGap }

        let starSize = max(6, min(10, layout.dotSize + 4))
        return height + IhsanSpacing.sm + starSize
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
        case .sevenDays: span = "the last seven days"
        case .thirtyDays: span = "the last thirty days"
        case .ninetyDays: span = "the last ninety days"
        case .year: span = "the last year, aggregated by week"
        }
        var label = "Pattern of prayer across \(span). Five rows, Fajr at top through Isha at bottom. Today is the rightmost column."
        if days.contains(where: \.isPaused) {
            label += " Paused days show as neutral dashes and are excluded from totals."
        }
        if days.contains(where: \.isTraveling) {
            label += " Traveling days carry a small plane mark."
        }
        if showsNaflRow {
            label += " A quieter row beneath, labelled NAFL, marks the days"
                + " carrying voluntary prayer: \(presenceSummary(naflColumns))."
        }
        if showsDhikrRow {
            label += " A row labelled DHIKR marks the days carrying a recorded"
                + " sitting: \(presenceSummary(dhikrColumns))."
        }
        return label
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

/// One cell of the nafl row: the four-pointed mark, filled, where the
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
                FourPointedStar().fill(
                    GestaltGrid.overlayMarkValue(for: tokens).color
                        .opacity(GestaltGrid.overlayMarkOpacity)
                )
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
