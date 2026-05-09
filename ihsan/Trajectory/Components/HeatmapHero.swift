import SwiftUI
import IhsanDesignSystem

/// The hero card. A field of dots whose opacity carries the entire signal:
/// a near-invisible ghost mark for an unlogged day, a fully-lit dot for a
/// 5/5 day, gradients in between. Pause days appear as a short horizontal
/// dash to make their exclusion legible without coloring it as failure.
/// Travel days keep their dot and gain a small airplane glyph.
struct HeatmapHero: View {
    let snapshot: TrajectoryState.Snapshot
    let onDayTap: (DayCompletion) -> Void

    private var columnCount: Int {
        HeatmapLayout.columns(for: snapshot.period)
    }
    private var dotDiameter: CGFloat {
        HeatmapLayout.dotDiameter(for: snapshot.period)
    }
    private var dotSpacing: CGFloat {
        HeatmapLayout.dotSpacing(for: snapshot.period)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.md) {
            HStack {
                Text("OLDEST")
                    .font(IhsanFont.smallCaps)
                    .tracking(0.8)
                    .foregroundStyle(IhsanColor.textMuted.opacity(0.6))
                Spacer()
                Text("TODAY")
                    .font(IhsanFont.smallCaps)
                    .tracking(0.8)
                    .foregroundStyle(IhsanColor.textMuted.opacity(0.6))
            }

            grid
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(IhsanSpacing.lg)
        .ihsanGlass(intensity: .regular)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var grid: some View {
        let columns = Array(
            repeating: GridItem(.fixed(dotDiameter), spacing: dotSpacing),
            count: columnCount
        )
        return LazyVGrid(columns: columns, spacing: dotSpacing) {
            ForEach(snapshot.days) { day in
                DayDot(day: day, diameter: dotDiameter)
                    .frame(width: dotDiameter, height: dotDiameter)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Haptics.tap()
                        onDayTap(day)
                    }
            }
        }
    }

    private var accessibilityDescription: String {
        let total = snapshot.aggregate.totalActiveDays
        let onTime = snapshot.aggregate.onTimeCount
        return "Heatmap of \(total) days, \(onTime) prayers on time."
    }
}

/// One dot in the hero grid. Renders three layers in z-order:
/// 1) the dot (or pause dash),
/// 2) the airplane glyph for travel days,
/// 3) a subtle ring for today.
private struct DayDot: View {
    let day: DayCompletion
    let diameter: CGFloat

    var body: some View {
        ZStack {
            if day.isPaused {
                pauseDash
            } else {
                Circle()
                    .fill(IhsanColor.textPrimary.opacity(opacity))
                    .frame(width: diameter, height: diameter)

                if day.isTraveling {
                    Image(systemName: "airplane")
                        .font(.system(size: max(6, diameter * 0.42), weight: .semibold))
                        .foregroundStyle(IhsanColor.textPrimary.opacity(0.6))
                        .offset(x: diameter * 0.32, y: -diameter * 0.32)
                        .accessibilityHidden(true)
                }
            }

            if isToday {
                Circle()
                    .strokeBorder(IhsanColor.textPrimary.opacity(0.5), lineWidth: 1)
                    .frame(width: diameter + 4, height: diameter + 4)
            }
        }
        .frame(width: diameter, height: diameter)
    }

    private var opacity: Double {
        let fraction = day.completionFraction ?? 0
        return 0.15 + fraction * 0.85
    }

    private var pauseDash: some View {
        Rectangle()
            .fill(IhsanColor.textMuted.opacity(0.4))
            .frame(width: diameter * 0.7, height: 1.5)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(day.date)
    }
}
