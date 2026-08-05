import IhsanCore
import IhsanDesignSystem
import SwiftUI

/// The widget's view of the day's arc.
///
/// The drawing itself is `CompactPlate` in the design system, so the
/// widget, the nightstand face, and the app's own gallery all render
/// one arc rather than three that drift. This is only the translation
/// from a live entry into what that component needs.
struct WidgetPlate: View {
    let day: PrayerTimelineEntry.LiveDay
    let date: Date
    let tokens: SkyPaletteTokens
    var ornamentSize: CGFloat = 18

    var body: some View {
        CompactPlate(
            model: CompactPlate.Model(
                marks: day.slots.map { slot in
                    CompactPlate.Model.Mark(
                        prayer: slot.prayer,
                        time: slot.scheduledTime,
                        state: day.markerState(for: slot, at: date)
                    )
                },
                sunrise: day.sunrise
            ),
            tokens: tokens,
            ornamentSize: ornamentSize
        )
    }
}
