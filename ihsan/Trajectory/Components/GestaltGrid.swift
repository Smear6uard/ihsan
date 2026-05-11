import SwiftUI
import IhsanCore
import IhsanDesignSystem

/// The visual heart of the Trajectory screen — a 5×N matrix of small
/// dots that lets the user read their pattern of prayer at a glance,
/// before any number is shown.
///
/// Five rows, top to bottom, are the five fardh prayers in chronological
/// order through the day (Fajr at top, Isha at bottom). Each column is
/// one unit of time:
///
/// - **7D**: 7 columns, one per day. Dot is large enough to read each
///   day individually.
/// - **30D**: 30 columns, one per day. Dots compact.
/// - **90D**: 90 columns, one per day. Dots tiny — the long-term pattern
///   becomes the figure.
/// - **YEAR**: 52 columns, one per week. Each dot encodes the *modal*
///   status the user logged for that prayer across the seven days in
///   that week.
///
/// A small brass four-pointed star ornament sits beneath the rightmost
/// column as the manuscript equivalent of "you are here".
struct GestaltGrid: View {
    let days: [DayCompletion]
    let period: TrajectoryPeriod

    var body: some View {
        GeometryReader { proxy in
            let metrics = Metrics(period: period, availableWidth: proxy.size.width)
            let columns = self.columns

            VStack(spacing: IhsanSpacing.sm) {
                grid(columns: columns, metrics: metrics)
                todayMarker(columnCount: columns.count, metrics: metrics)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: gridHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Grid

    private func grid(
        columns: [[PrayerCompletion]],
        metrics: Metrics
    ) -> some View {
        VStack(spacing: metrics.spacing) {
            ForEach(0..<5, id: \.self) { row in
                HStack(spacing: metrics.spacing) {
                    ForEach(0..<columns.count, id: \.self) { col in
                        GestaltDot(
                            completion: columns[col][row],
                            size: metrics.dotSize
                        )
                    }
                }
            }
        }
    }

    /// A small brass four-pointed star centred under the rightmost
    /// column. Mirrors the grid's HStack structure 1:1 so the star
    /// lands exactly under the last dot's centre regardless of period
    /// or device width.
    private func todayMarker(
        columnCount: Int,
        metrics: Metrics
    ) -> some View {
        let starSize: CGFloat = max(6, min(10, metrics.dotSize + 4))
        return HStack(spacing: metrics.spacing) {
            ForEach(0..<columnCount, id: \.self) { col in
                Group {
                    if col == columnCount - 1 {
                        FourPointedStar()
                            .fill(IhsanIridescence.brassStroke(opacity: 0.95))
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

    /// For 7D / 30D / 90D returns the `days`' five-prayer slates directly.
    /// For YEAR returns 52 week-aggregated columns via `GestaltAggregation`.
    private var columns: [[PrayerCompletion]] {
        switch period {
        case .year:
            return GestaltAggregation.yearWeekColumns(days: days)
        default:
            return days.map { $0.prayerCompletions }
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
    /// dot size + the today-marker block.
    private var gridHeight: CGFloat {
        let dot: CGFloat
        let spacing: CGFloat
        switch period {
        case .sevenDays:  dot = 16; spacing = 8
        case .thirtyDays: dot = 7;  spacing = 3
        case .ninetyDays: dot = 3;  spacing = 1.0
        case .year:       dot = 5;  spacing = 1.5
        }
        let rows = 5 * dot + 4 * spacing
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
        return "Pattern of prayer across \(span). Five rows, Fajr at top through Isha at bottom. Today is the rightmost column."
    }
}

// MARK: - GestaltDot

/// A single dot in the gestalt grid. Encodes one prayer's status:
///
/// - **Jamaʿah** (on-time, congregational): filled gold — the highest tier.
/// - **On Time** (alone): filled brass.
/// - **Qadā** (made up later): filled twilight indigo at 80% opacity.
/// - **Late**: an outlined brass ring at 60% opacity, hollow centre.
/// - **Missed**: filled vermillion at 70% opacity.
/// - **Unlogged / future**: an outlined ring at 30% opacity.
///
/// The fills come straight from the manuscript palette so the grid sits
/// in the same chromatic key as the rest of the page. The hollow rings
/// for "late" and "unlogged" are deliberate — at small sizes the eye
/// reads them as the absence of solid presence, which matches the
/// semantics.
private struct GestaltDot: View {
    let completion: PrayerCompletion
    let size: CGFloat

    var body: some View {
        Group {
            switch (completion.status, completion.withJamaah) {
            case (.onTime, true):
                Circle()
                    .fill(IhsanColor.gold)
            case (.onTime, _):
                Circle()
                    .fill(IhsanColor.brass)
            case (.qada, _):
                Circle()
                    .fill(IhsanColor.indigoQada.opacity(0.80))
            case (.missed, _):
                Circle()
                    .fill(IhsanColor.vermillion.opacity(0.70))
            case (.late, _):
                Circle()
                    .strokeBorder(
                        IhsanColor.brass.opacity(0.60),
                        lineWidth: lateStrokeWidth
                    )
            case (.none, _):
                Circle()
                    .strokeBorder(
                        IhsanColor.brass.opacity(0.30),
                        lineWidth: unloggedStrokeWidth
                    )
            }
        }
        .frame(width: size, height: size)
    }

    /// Hollow rings need a stroke proportional to the dot size — too thin
    /// and they disappear at 3pt; too thick and the 16pt 7D dots look
    /// like Os instead of rings.
    private var lateStrokeWidth: CGFloat {
        max(0.6, size * 0.22)
    }

    private var unloggedStrokeWidth: CGFloat {
        max(0.5, size * 0.18)
    }
}

// MARK: - Preview

#Preview("Gestalt grid — 7D / 30D / 90D / YEAR") {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    let buildDays: (Int) -> [DayCompletion] = { count in
        (0..<count).reversed().map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let statuses: [PrayerStatus?] = [
                .onTime, .onTime, .late, .missed,
                [.qada, .onTime, .onTime, nil].randomElement() ?? nil
            ]
            let completions = zip(Prayer.allCases, statuses).map { prayer, status in
                PrayerCompletion(
                    prayer: prayer,
                    status: status,
                    withJamaah: prayer == .fajr && status == .onTime && Bool.random()
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
    }

    return ScrollView {
        VStack(spacing: IhsanSpacing.lg) {
            ForEach([TrajectoryPeriod.sevenDays, .thirtyDays, .ninetyDays, .year], id: \.self) { period in
                VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
                    Text(period.label.uppercased())
                        .font(IhsanFont.inscription)
                        .tracking(1.6)
                        .foregroundStyle(IhsanColor.brassDark)
                    GestaltGrid(days: buildDays(period.dayCount), period: period)
                }
                .padding(IhsanSpacing.lg)
                .frame(maxWidth: .infinity)
                .ihsanIlluminatedPanel(intensity: .regular)
                .padding(.horizontal, IhsanSpacing.md)
            }
        }
        .padding(.vertical)
    }
    .ihsanManuscriptPage()
}
