import SwiftUI
import IhsanCore
import IhsanDesignSystem

/// A short subtle-glass row carrying one prayer's pattern across the period:
/// symbol + name on the left, a horizontal mini dot grid in the middle, and
/// a tabular count on the right. The mini dots use the same opacity ramp as
/// the hero so the visual language reads as one system.
struct PerPrayerRow: View {
    let aggregate: TrajectoryAggregate.PrayerAggregate

    var body: some View {
        HStack(spacing: IhsanSpacing.md) {
            PrayerSymbol(aggregate.prayer, size: 20)
                .frame(width: 28)

            HStack(spacing: IhsanSpacing.sm) {
                Text(aggregate.prayer.displayNameEnglish)
                    .font(IhsanFont.bodyEnglishBold)
                    .foregroundStyle(IhsanColor.textPrimary)
                Text(aggregate.prayer.displayNameArabic)
                    .font(.system(size: 15))
                    .foregroundStyle(IhsanColor.textSecondary)
            }
            .frame(width: 120, alignment: .leading)

            miniGrid
                .frame(maxWidth: .infinity, alignment: .center)

            Text("\(aggregate.onTimeCount)/\(aggregate.totalActiveDays)")
                .font(IhsanFont.tabular)
                .foregroundStyle(IhsanColor.textMuted)
                .monospacedDigit()
                .frame(width: 72, alignment: .trailing)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, IhsanSpacing.md)
        .padding(.vertical, IhsanSpacing.sm + 2)
        .ihsanGlass(intensity: .subtle)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(aggregate.prayer.displayNameEnglish): "
            + "\(aggregate.onTimeCount) of \(aggregate.totalActiveDays) days on time"
        )
    }

    /// Mini dot grid. Sized down from the hero — tight 6pt dots so a year of
    /// dots fits without dominating the row. Paused days collapse to a short
    /// dash, just like the hero.
    private var miniGrid: some View {
        let dotSize: CGFloat = miniDotSize
        let spacing: CGFloat = miniDotSpacing
        return GeometryReader { proxy in
            let visibleCount = max(
                1,
                Int((proxy.size.width + spacing) / (dotSize + spacing))
            )
            // If the period is larger than the row can fit, drop the oldest
            // dots so today stays anchored on the right edge. Year view will
            // hit this; 30D and shorter shouldn't.
            let trimmed = Array(
                aggregate.dailyFractions.suffix(visibleCount)
            )
            HStack(spacing: spacing) {
                Spacer(minLength: 0)
                ForEach(Array(trimmed.enumerated()), id: \.offset) { _, fraction in
                    if let f = fraction {
                        Circle()
                            .fill(IhsanColor.textPrimary.opacity(0.15 + f * 0.85))
                            .frame(width: dotSize, height: dotSize)
                    } else {
                        Rectangle()
                            .fill(IhsanColor.textMuted.opacity(0.4))
                            .frame(width: dotSize * 0.7, height: 1.5)
                            .frame(width: dotSize, height: dotSize)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .trailing)
        }
        .frame(height: 12)
    }

    private var miniDotSize: CGFloat {
        switch aggregate.dailyFractions.count {
        case ...7: return 8
        case ...30: return 6
        case ...90: return 5
        default: return 3
        }
    }

    private var miniDotSpacing: CGFloat {
        switch aggregate.dailyFractions.count {
        case ...7: return 5
        case ...30: return 3
        case ...90: return 2
        default: return 1
        }
    }
}
