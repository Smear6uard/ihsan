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
/// - **Late** — the warm metal outline, hollow centre.
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
struct GestaltGrid: View {
    let days: [DayCompletion]
    let period: TrajectoryPeriod
    /// Resolved page tokens — the grid never picks its own colors.
    let tokens: SkyPaletteTokens
    /// Days carrying any voluntary record. Non-nil only when the user
    /// turned the Path overlay on; it adds a sixth, quieter row beneath
    /// the five fardh rows — presence only, no denominator, no figure.
    var naflDays: Set<Date>? = nil
    /// Days carrying a recorded tasbīḥ sitting. Non-nil only when the
    /// dhikr overlay is on — the same quiet presence-only register.
    var dhikrDays: Set<Date>? = nil

    /// One rendered column: the five-prayer slate plus the day-level
    /// state that colors it.
    private struct Column {
        let slate: [PrayerCompletion]
        let isPaused: Bool
        let isTraveling: Bool
    }

    var body: some View {
        GeometryReader { proxy in
            let metrics = Metrics(period: period, availableWidth: proxy.size.width)
            let columns = self.columns

            VStack(spacing: IhsanSpacing.sm) {
                grid(columns: columns, metrics: metrics)
                annotationRow(columns: columns, metrics: metrics)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: gridHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Grid

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

            if let naflColumns, naflColumns.count == columns.count {
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

            if let dhikrColumns, dhikrColumns.count == columns.count {
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

    /// Per-column presence of any voluntary record, aligned 1:1 with the
    /// fardh columns.
    private var naflColumns: [Bool]? {
        guard let naflDays else { return nil }
        return presenceColumns(for: naflDays)
    }

    private var dhikrColumns: [Bool]? {
        guard let dhikrDays else { return nil }
        return presenceColumns(for: dhikrDays)
    }

    private func presenceColumns(for daysWithRecord: Set<Date>) -> [Bool] {
        switch period {
        case .year:
            return GestaltAggregation.yearWeekDayGroups(days: days).map { week in
                week.contains { daysWithRecord.contains($0.date) }
            }
        default:
            return days.map { daysWithRecord.contains($0.date) }
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

    /// The grid needs a stable height for the parent's VStack layout; the
    /// inner GeometryReader recomputes spacing per device, but height
    /// barely varies across the supported widths so we pin to the spec
    /// dot size + the annotation block.
    private var gridHeight: CGFloat {
        let dot: CGFloat
        let spacing: CGFloat
        switch period {
        case .sevenDays:  dot = 16; spacing = 8
        case .thirtyDays: dot = 7;  spacing = 3
        case .ninetyDays: dot = 3;  spacing = 1.0
        case .year:       dot = 5;  spacing = 1.5
        }
        let rowCount: CGFloat = 5
            + (naflDays == nil ? 0 : 1)
            + (dhikrDays == nil ? 0 : 1)
        let rows = rowCount * dot + (rowCount - 1) * spacing
        let starSize = max(6, min(10, dot + 4))
        return rows + IhsanSpacing.sm + starSize
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
        if naflDays != nil {
            label += " A quieter sixth row marks days with voluntary prayer."
        }
        if dhikrDays != nil {
            label += " A quieter row marks days with recorded dhikr."
        }
        return label
    }
}

// MARK: - Dhikr overlay dot

/// One cell of the optional dhikr row: a small outlined ring — the
/// tasbīḥ ring at dot scale — where the day (or week) holds a
/// recorded sitting. Outline only, never a fill: visible if sought,
/// invisible if not.
private struct DhikrOverlayDot: View {
    let present: Bool
    let size: CGFloat
    let tokens: SkyPaletteTokens

    var body: some View {
        Group {
            if present {
                Circle()
                    .stroke(
                        tokens.metal.opacity(0.40),
                        lineWidth: max(0.5, size * 0.14)
                    )
                    .padding(size * 0.12)
            } else {
                Color.clear
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Nafl overlay dot

/// One cell of the optional sixth row: a small outlined four-pointed
/// star where the day (or week) holds any voluntary record, empty space
/// where it doesn't. Always the quieter state — outline only, never a
/// fill — so the row is visible if sought and invisible if not.
private struct NaflOverlayDot: View {
    let present: Bool
    let size: CGFloat
    let tokens: SkyPaletteTokens

    var body: some View {
        Group {
            if present {
                FourPointedStar()
                    .stroke(
                        tokens.metal.opacity(0.40),
                        lineWidth: max(0.5, size * 0.14)
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
            if size >= 6 {
                Circle()
                    .fill(tokens.leafGold)
                    .overlay {
                        Circle().strokeBorder(
                            tokens.keyline.opacity(0.9), lineWidth: keylineWidth
                        )
                    }
            } else {
                Circle().fill(tokens.leafGold)
            }
        case (.qada, _):
            if size >= 6 {
                Circle()
                    .fill(Self.qadaBodyValue(for: tokens).color)
                    .overlay {
                        Circle().strokeBorder(
                            tokens.metal.opacity(0.9), lineWidth: keylineWidth
                        )
                    }
            } else {
                Circle().fill(Self.qadaBodyValue(for: tokens).color)
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
