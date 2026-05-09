import SwiftUI
import IhsanDesignSystem

/// The five-prayer stack below the hero. Each row is a quiet subtle-glass
/// pill so the rhythm reads as a column without any of them shouting over
/// the others.
struct PerPrayerList: View {
    let aggregate: TrajectoryAggregate

    var body: some View {
        VStack(spacing: IhsanSpacing.sm) {
            ForEach(aggregate.perPrayer, id: \.prayer) { p in
                PerPrayerRow(aggregate: p)
            }
        }
    }
}
