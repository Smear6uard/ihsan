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
/// sit the presence overlays — nafl and dhikr — with a key underneath
/// naming each by the mark it draws. Nothing switches them on: they
/// follow the data, because the switches that used to govern them could
/// be flipped without changing a single pixel.
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

    /// One rendered column: the five-prayer slate plus the day-level
    /// state that colors it.
    private struct Column {
        let slate: [PrayerCompletion]
        let isPaused: Bool
        let isTraveling: Bool
    }

    var body: some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
            GeometryReader { proxy in
                let metrics = Metrics(period: period, availableWidth: proxy.size.width)
                let columns = self.columns

                VStack(spacing: IhsanSpacing.sm) {
                    grid(columns: columns, metrics: metrics)
                    annotationRow(columns: columns, metrics: metrics)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: patternHeight)

            // The key, drawn only when there is a presence row to
            // explain. This is the repair: the rows themselves are
            // deliberately quiet, and a quiet mark nobody can name is
            // just noise. A row-by-row gutter cannot work here — at 90D
            // the rows are 4pt apart and a label is eleven — so the
            // naming goes underneath, where it has room.
            if showsNaflRow || showsDhikrRow {
                keyRow
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Key

    /// Each presence row's own mark at legible size, beside its name.
    /// The marks are the same units the rows draw, not approximations
    /// of them, so the key can never describe something the grid does
    /// not show.
    private var keyRow: some View {
        HStack(spacing: IhsanSpacing.md) {
            if showsNaflRow {
                keyEntry("NAFL") {
                    NaflOverlayDot(present: true, size: Self.keyMarkSize, tokens: tokens)
                }
            }
            if showsDhikrRow {
                keyEntry("DHIKR") {
                    DhikrOverlayDot(present: true, size: Self.keyMarkSize, tokens: tokens)
                }
            }
            Spacer(minLength: 0)
        }
    }

    /// Mark size in the key. Larger than any period's dot on purpose —
    /// the key is read once, up close, and the pattern is read at arm's
    /// length.
    private static let keyMarkSize: CGFloat = 11

    private func keyEntry<Mark: View>(
        _ name: String, @ViewBuilder mark: () -> Mark
    ) -> some View {
        HStack(spacing: 5) {
            mark()
            Text(name)
                .font(IhsanFont.inscription)
                .tracking(1.3)
                .foregroundStyle(tokens.inkSecondary)
        }
        .fixedSize()
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

    /// Gap between the five fardh rows and the presence overlays.
    private static let overlayGap: CGFloat = IhsanSpacing.xs

    @ViewBuilder
    private func grid(
        columns: [Column],
        metrics: Metrics
    ) -> some View {
        VStack(spacing: metrics.spacing) {
            ForEach(0..<5, id: \.self) { row in
                HStack(spacing: metrics.spacing) {
                    ForEach(0..<columns.count, id: \.self) { col in
                        GestaltDot(
                            completion: columns[col].slate[row],
                            isPausedDay: columns[col].isPaused,
                            size: metrics.dotSize,
                            tokens: tokens
                        )
                    }
                }
            }

            if showsNaflRow || showsDhikrRow {
                // The overlay rows are a different register from the
                // five fardh rows — presence, not status. A row at the
                // grid's own spacing read as a sixth prayer.
                Color.clear.frame(height: Self.overlayGap)
            }

            if showsNaflRow, let naflColumns, naflColumns.count == columns.count {
                HStack(spacing: metrics.spacing) {
                    ForEach(0..<naflColumns.count, id: \.self) { col in
                        NaflOverlayDot(
                            present: naflColumns[col],
                            size: metrics.dotSize,
                            tokens: tokens
                        )
                    }
                }
            }

            if showsDhikrRow, let dhikrColumns, dhikrColumns.count == columns.count {
                HStack(spacing: metrics.spacing) {
                    ForEach(0..<dhikrColumns.count, id: \.self) { col in
                        DhikrOverlayDot(
                            present: dhikrColumns[col],
                            size: metrics.dotSize,
                            tokens: tokens
                        )
                    }
                }
            }
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
    private var naflColumns: [Bool]? {
        naflDays.map {
            GestaltAggregation.presenceColumns(
                days: days, period: period, daysWithRecord: $0
            )
        }
    }

    private var dhikrColumns: [Bool]? {
        dhikrDays.map {
            GestaltAggregation.presenceColumns(
                days: days, period: period, daysWithRecord: $0
            )
        }
    }

    /// The under-column annotations: the four-pointed star under the
    /// rightmost column ("you are here"), and the engraved plane mark
    /// under travel columns when the scale gives it room. Mirrors the
    /// grid's HStack structure 1:1 so marks land under their columns.
    private func annotationRow(
        columns: [Column],
        metrics: Metrics
    ) -> some View {
        let starSize: CGFloat = max(6, min(10, metrics.dotSize + 4))
        let planeVisible = metrics.dotSize >= 5
        return HStack(spacing: metrics.spacing) {
            ForEach(0..<columns.count, id: \.self) { col in
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
                .frame(width: metrics.dotSize, alignment: .center)
            }
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

    // MARK: - Layout metrics

    private struct Metrics {
        let dotSize: CGFloat
        let spacing: CGFloat

        init(period: TrajectoryPeriod, availableWidth: CGFloat) {
            let cols = CGFloat(Self.columnCount(for: period))
            let spec = Self.spec(for: period)
            let idealRowWidth = spec.dot * cols + spec.dot * spec.spacingRatio * (cols - 1)

            if availableWidth >= idealRowWidth {
                self.dotSize = spec.dot
                self.spacing = spec.dot * spec.spacingRatio
            } else {
                // Squeeze the dot proportionally so 90 / 52 columns still
                // fit on narrower iPhones rather than overflowing the panel.
                let proportional = availableWidth / (cols + spec.spacingRatio * (cols - 1))
                self.dotSize = max(spec.minDot, min(spec.dot, proportional))
                let remaining = max(0, availableWidth - self.dotSize * cols)
                self.spacing = max(spec.minSpacing, remaining / (cols - 1))
            }
        }

        private struct Spec {
            let dot: CGFloat
            let minDot: CGFloat
            let spacingRatio: CGFloat
            let minSpacing: CGFloat
        }

        private static func columnCount(for period: TrajectoryPeriod) -> Int {
            switch period {
            case .sevenDays:  return 7
            case .thirtyDays: return 30
            case .ninetyDays: return 90
            case .year:       return 52
            }
        }

        private static func spec(for period: TrajectoryPeriod) -> Spec {
            switch period {
            case .sevenDays:
                return Spec(dot: 16, minDot: 12, spacingRatio: 0.50, minSpacing: 4)
            case .thirtyDays:
                return Spec(dot: 7,  minDot: 5,  spacingRatio: 0.43, minSpacing: 1.5)
            case .ninetyDays:
                return Spec(dot: 3,  minDot: 2,  spacingRatio: 0.30, minSpacing: 0.3)
            case .year:
                return Spec(dot: 5,  minDot: 3,  spacingRatio: 0.40, minSpacing: 0.5)
            }
        }
    }

    /// The pattern block needs a stable height for the parent's VStack
    /// layout; the inner GeometryReader recomputes spacing per device,
    /// but height barely varies across the supported widths so we pin to
    /// the spec dot size + the annotation block.
    ///
    /// Counts only the rows that will actually be drawn — a panel that
    /// reserves space for an empty overlay is a panel with a hole in it.
    private var patternHeight: CGFloat {
        let dot: CGFloat
        let spacing: CGFloat
        switch period {
        case .sevenDays:  dot = 16; spacing = 8
        case .thirtyDays: dot = 7;  spacing = 3
        case .ninetyDays: dot = 3;  spacing = 1.0
        case .year:       dot = 5;  spacing = 1.5
        }
        let overlayRows = (showsNaflRow ? 1 : 0) + (showsDhikrRow ? 1 : 0)
        let rowCount = CGFloat(5 + overlayRows)
        let rows = rowCount * dot + (rowCount - 1) * spacing
        let starSize = max(6, min(10, dot + 4))
        let gap = overlayRows == 0 ? 0 : Self.overlayGap
        return rows + gap + IhsanSpacing.sm + starSize
    }

    // MARK: - Accessibility

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
            label += " A quieter sixth row, keyed NAFL, marks days with voluntary prayer."
        }
        if showsDhikrRow {
            label += " A quieter row, keyed DHIKR, marks days with recorded dhikr."
        }
        return label
    }
}

// MARK: - Dhikr overlay dot

/// One cell of the optional dhikr row: a small outlined ring — the
/// One cell of the optional dhikr row: a small filled BEAD where the
/// day (or week) holds a recorded sitting. A bead, not a ring — the
/// ring is what an unlogged fardh cell already draws, so an outlined
/// dhikr mark said "nothing happened here" in the one row where it
/// means the opposite.
private struct DhikrOverlayDot: View {
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

// MARK: - Nafl overlay dot

/// One cell of the optional sixth row: a small four-pointed star where
/// the day (or week) holds any voluntary record, empty space where it
/// doesn't. Filled rather than stroked below 8 pt, where a stroke at
/// this scale has no line to draw.
private struct NaflOverlayDot: View {
    let present: Bool
    let size: CGFloat
    let tokens: SkyPaletteTokens

    var body: some View {
        Group {
            if present {
                let tint = GestaltGrid.overlayMarkValue(for: tokens).color
                    .opacity(GestaltGrid.overlayMarkOpacity)
                if size >= 8 {
                    FourPointedStar()
                        .stroke(tint, lineWidth: max(0.9, size * 0.16))
                } else {
                    FourPointedStar().fill(tint)
                }
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
