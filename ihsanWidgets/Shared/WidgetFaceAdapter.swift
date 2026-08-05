import Foundation
import IhsanCore
import IhsanDesignSystem
import SwiftUI
import WidgetKit

/// Translation from a timeline entry to the design system's face
/// models — the only thing the extension adds to a face is data.
extension PrayerTimelineEntry.LiveDay {

    /// The face model for this entry. `fixedPrayer` pins the focus to
    /// one prayer's next occurrence (the configurable small widget);
    /// nil follows the day.
    func faceModel(at date: Date, fixedPrayer: Prayer? = nil) -> WidgetDayModel {
        let focusPrayer: Prayer
        let focusTime: Date
        if let fixedPrayer,
           let occurrence = nextOccurrenceByPrayerRaw[fixedPrayer.rawValue] {
            focusPrayer = fixedPrayer
            focusTime = occurrence
        } else {
            focusPrayer = nextPrayer
            focusTime = nextPrayerTime
        }

        return WidgetDayModel(
            date: date,
            slots: slots.map {
                WidgetDayModel.Slot(
                    prayer: $0.prayer,
                    time: $0.scheduledTime,
                    state: markerState(for: $0, at: date)
                )
            },
            nextPrayer: focusPrayer,
            nextTime: focusTime,
            countdown: WidgetTimerInterval.countdown(from: date, to: focusTime),
            currentPrayer: currentPrayer,
            currentWindow: currentWindow,
            sunrise: sunrise,
            cityName: cityName,
            timeZoneIdentifier: timeZoneIdentifier,
            isPaused: isPaused,
            hijri: hijri.map {
                WidgetHijriModel(
                    day: $0.day,
                    monthName: $0.monthName,
                    year: $0.year,
                    significantLine: $0.significantLine,
                    isRamadan: $0.isRamadan
                )
            },
            fasting: fastingModel,
            night: night.map {
                WidgetNightModel(
                    start: $0.start,
                    end: $0.end,
                    nisfAlLayl: $0.nisfAlLayl,
                    lastThirdStart: $0.lastThirdStart
                )
            }
        )
    }

    /// Fasting joins a face only on a day that carries a fast —
    /// recorded, or any Ramadan day.
    private var fastingModel: WidgetFastingModel? {
        guard let fasting, fasting.isFasting || fasting.isRamadan else { return nil }
        guard
            let fajr = slots.first(where: { $0.prayer == .fajr })?.scheduledTime,
            let maghrib = slots.first(where: { $0.prayer == .maghrib })?.scheduledTime
        else { return nil }
        return WidgetFastingModel(
            suhoorEnds: fajr,
            iftar: maghrib,
            isRamadan: fasting.isRamadan
        )
    }
}

/// The placement a widget is actually rendering into, decided from
/// both WidgetKit signals so the states can no longer be conflated:
/// tinted and clear modes are `accented` whatever the container says;
/// StandBy is full-colour without a container.
struct WidgetPlacement {
    let faceMode: WidgetFaceMode
    let isStandBy: Bool

    init(renderingMode: WidgetRenderingMode, showsContainer: Bool) {
        if renderingMode == .accented {
            faceMode = .accented
            isStandBy = false
        } else {
            faceMode = .fullColor
            isStandBy = !showsContainer
        }
    }
}
