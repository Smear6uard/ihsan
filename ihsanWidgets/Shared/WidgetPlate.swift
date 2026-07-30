import IhsanCore
import IhsanDesignSystem
import SwiftUI

/// The widget's view of the day's arc.
///
/// The drawing itself is `CompactPlate` in the design system, so the
/// widget, the nightstand face, and the app's own gallery all render
/// one arc rather than three that drift. This is only the translation
/// from a timeline entry into what that component needs.
struct WidgetPlate: View {
    let entry: PrayerTimelineEntry
    let tokens: SkyPaletteTokens
    var ornamentSize: CGFloat = 18

    var body: some View {
        CompactPlate(
            model: entry.compactPlateModel,
            tokens: tokens,
            ornamentSize: ornamentSize
        )
    }
}

extension PrayerTimelineEntry {
    var compactPlateModel: CompactPlate.Model {
        CompactPlate.Model(
            marks: todayPrayerTimes.map { slot in
                CompactPlate.Model.Mark(
                    prayer: slot.prayer,
                    time: slot.scheduledTime,
                    state: markerState(for: slot)
                )
            },
            sunrise: sunrise
        )
    }

    func markerState(for slot: PrayerSlot) -> PrayerMarkerState {
        if currentPrayer == slot.prayer { return .current }
        if let status = loggedStatus(for: slot.prayer), status != .missed {
            return .logged
        }
        return slot.scheduledTime <= date ? .passedUnlogged : .upcoming
    }
}
