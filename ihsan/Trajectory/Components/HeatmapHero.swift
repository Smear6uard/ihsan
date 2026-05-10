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
            .accessibilityHidden(true)

            // Single roll-up element so VoiceOver users get the headline
            // before paging into the per-dot stops below.
            Text(accessibilityDescription)
                .frame(width: 0, height: 0)
                .accessibilityElement()
                .accessibilityLabel(accessibilityDescription)

            grid
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(IhsanSpacing.lg)
        .ihsanGlass(intensity: .regular)
    }

    private var grid: some View {
        let columns = Array(
            repeating: GridItem(.fixed(dotDiameter), spacing: dotSpacing),
            count: columnCount
        )
        return LazyVGrid(columns: columns, spacing: dotSpacing) {
            ForEach(snapshot.days) { day in
                DayDot(day: day, diameter: dotDiameter) {
                    // Haptics audit: the dot itself is the intentional
                    // mapped surface. Do not layer an additional sheet-
                    // presentation haptic for the day popover.
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
///
/// On tap the dot does a brief 1.0→1.12→1.0 bounce so the gesture has a
/// felt-out target, then runs `onTap` to surface the popover.
private struct DayDot: View {
    let day: DayCompletion
    let diameter: CGFloat
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tapBeat: Int = 0

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
        .contentShape(Rectangle())
        .keyframeAnimator(
            initialValue: 1.0,
            trigger: tapBeat
        ) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(1.12, duration: 0.10)
                SpringKeyframe(1.0, spring: .bouncy(duration: 0.30, extraBounce: 0.08))
            }
        }
        .onTapGesture {
            if !reduceMotion {
                tapBeat &+= 1
            }
            onTap()
        }
        // Each dot is its own VoiceOver stop, since color/opacity is the
        // only visual encoding and VO can't see it.
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    private var accessibilityLabel: String {
        let dateText = day.date.formatted(date: .abbreviated, time: .omitted)
        var parts: [String] = [dateText]
        if isToday {
            parts.append("today")
        }
        if day.isPaused {
            parts.append("paused day, excluded from totals")
        } else {
            let count = day.onTimeCount
            let total = day.prayerCompletions.count
            if count == total {
                parts.append("all \(total) prayers on time")
            } else if count == 0 {
                parts.append("no prayers logged on time")
            } else {
                parts.append("\(count) of \(total) prayers on time")
            }
        }
        if day.isTraveling {
            parts.append("traveling")
        }
        return parts.joined(separator: ", ")
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
