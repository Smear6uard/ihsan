#if DEBUG
import IhsanCore
import IhsanDesignSystem
import SwiftUI

/// The widget faces, at their real sizes, inside the app.
///
/// A widget is drawn by WidgetKit on a home screen, which no test
/// harness can arrange reliably — so the faces themselves (which live
/// in IhsanDesignSystem and are exactly what the extension renders)
/// are shown here at the point sizes iOS gives each family, on the
/// same grounds. It used to re-draw approximations of the faces by
/// hand; approximations drift, and a review of a drifted copy proves
/// nothing. What this proves on a device is the drawing; the
/// WidgetKit container, tinted mode, and StandBy are verified on the
/// home and lock screens themselves.
///
/// Reached with `-IhsanDebugWidgetGallery`. DEBUG only.
struct WidgetFaceGallery: View {
    /// Point sizes for the iPhone 17 Pro's widget grid.
    private static let small = CGSize(width: 170, height: 170)
    private static let medium = CGSize(width: 364, height: 170)
    private static let large = CGSize(width: 364, height: 382)
    private static let circular = CGSize(width: 72, height: 72)
    private static let rectangular = CGSize(width: 172, height: 76)

    @State private var isNight = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: IhsanSpacing.lg) {
                Picker("Moment", selection: $isNight) {
                    Text("Night").tag(true)
                    Text("Afternoon").tag(false)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("gallery-moment")

                label("Small · Next Prayer")
                homeFace(size: Self.small) {
                    NextPrayerFace(model: model, tokens: tokens)
                }

                label("Small · Hijri Day")
                homeFace(size: Self.small) {
                    if let hijri = model.hijri {
                        HijriDayFace(hijri: hijri, tokens: tokens)
                    }
                }

                label("Medium · The Day Strip")
                homeFace(size: Self.medium) {
                    DayStripFace(model: model, tokens: tokens)
                }

                label("Medium · fasting")
                homeFace(size: Self.medium) {
                    DayStripFace(model: fastingModel, tokens: tokens)
                }

                label("Large · The Plate")
                homeFace(size: Self.large) {
                    PlateFace(model: model, tokens: tokens)
                }

                label("Lock screen")
                HStack(alignment: .top, spacing: IhsanSpacing.md) {
                    accessory(size: Self.circular) {
                        AccessoryNextPrayerFace(
                            prayer: model.nextPrayer,
                            time: model.nextTime,
                            timeZoneIdentifier: model.timeZoneIdentifier,
                            isCurrent: false
                        )
                    }
                    accessory(size: Self.circular) {
                        AccessoryWindowGaugeFace(
                            prayer: model.currentPrayer ?? model.nextPrayer,
                            window: model.currentWindow,
                            isCurrent: model.currentPrayer != nil
                        )
                    }
                    accessory(size: Self.circular) {
                        AccessoryFastingGaugeFace(
                            fasting: canonicalFasting,
                            date: model.date
                        )
                    }
                }
                accessory(size: Self.rectangular) {
                    AccessoryNowNextFace(
                        current: model.currentPrayer,
                        next: model.nextPrayer,
                        nextTime: model.nextTime,
                        timeZoneIdentifier: model.timeZoneIdentifier
                    )
                }
                accessory(size: Self.rectangular) {
                    AccessoryDayRowFace(
                        slots: model.slots,
                        timeZoneIdentifier: model.timeZoneIdentifier
                    )
                }
                if let night = model.night {
                    accessory(size: Self.rectangular) {
                        AccessoryNightFace(
                            night: night,
                            date: model.date,
                            timeZoneIdentifier: model.timeZoneIdentifier
                        )
                    }
                }
                accessory(size: Self.rectangular) {
                    AccessoryFastingRectFace(
                        fasting: canonicalFasting,
                        date: model.date,
                        timeZoneIdentifier: model.timeZoneIdentifier
                    )
                }
            }
            .padding(IhsanSpacing.md)
        }
        .ihsanManuscriptPage()
        .accessibilityIdentifier("widget-face-gallery")
    }

    // MARK: - Scaffolding

    private func label(_ text: String) -> some View {
        Text(text.uppercased())
            .font(IhsanFont.inscription)
            .tracking(1.2)
            .foregroundStyle(IhsanPageChrome.tokens(at: NowProvider.active.now()).inkSecondary)
    }

    private func homeFace(
        size: CGSize, @ViewBuilder content: () -> some View
    ) -> some View {
        ZStack {
            WidgetSkyGround(tokens: tokens)
            content().padding(16)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private func accessory(
        size: CGSize, @ViewBuilder content: () -> some View
    ) -> some View {
        ZStack {
            Color(white: 0.1)
            content().foregroundStyle(.white).padding(6)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(
            cornerRadius: size.width == size.height ? size.width / 2 : 16
        ))
        .environment(\.colorScheme, .dark)
    }

    // MARK: - The canonical day

    private static let zone = TimeZone(identifier: "America/Chicago")!

    private static func at(_ hour: Int, _ minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let day = calendar.date(from: DateComponents(year: 2026, month: 7, day: 30))!
        return calendar.date(byAdding: DateComponents(hour: hour, minute: minute), to: day)!
    }

    private var moment: Date { isNight ? Self.at(23, 15) : Self.at(15, 10) }

    private var tokens: SkyPaletteTokens {
        PaletteState.resolved(for: SkyPhase.resolve(at: moment, events: Self.events))
    }

    private static let events = SolarDayEvents(
        fajr: at(4, 10),
        sunrise: at(5, 42),
        solarNoon: at(12, 58),
        maghrib: at(20, 11),
        isha: at(21, 43)
    )

    private var canonicalFasting: WidgetFastingModel {
        WidgetFastingModel(
            suhoorEnds: Self.at(4, 10), iftar: Self.at(20, 11), isRamadan: true
        )
    }

    private var model: WidgetDayModel {
        let date = moment
        let times: [(Prayer, Date)] = [
            (.fajr, Self.at(4, 10)), (.dhuhr, Self.at(12, 58)), (.asr, Self.at(16, 53)),
            (.maghrib, Self.at(20, 11)), (.isha, Self.at(21, 43)),
        ]
        let slots = times.map { prayer, time in
            let state: PrayerMarkerState
            if isNight {
                state = prayer == .isha ? .current : .logged
            } else {
                switch prayer {
                case .fajr, .dhuhr: state = .logged
                default: state = .upcoming
                }
            }
            return WidgetDayModel.Slot(prayer: prayer, time: time, state: state)
        }
        let next: (Prayer, Date) = isNight ? (.fajr, Self.at(28, 11)) : (.asr, Self.at(16, 53))
        return WidgetDayModel(
            date: date,
            slots: slots,
            nextPrayer: next.0,
            nextTime: next.1,
            countdown: WidgetTimerInterval.countdown(from: date, to: next.1),
            currentPrayer: isNight ? .isha : .dhuhr,
            currentWindow: isNight
                ? Self.at(21, 43)...Self.at(28, 11)
                : Self.at(12, 58)...Self.at(16, 53),
            sunrise: Self.at(5, 42),
            cityName: "Madinah",
            timeZoneIdentifier: Self.zone.identifier,
            isPaused: false,
            hijri: WidgetHijriModel(
                day: 13, monthName: "Safar", year: 1448,
                significantLine: "White day · Safar 13", isRamadan: false
            ),
            fasting: nil,
            night: WidgetNightModel(
                start: Self.at(20, 11), end: Self.at(28, 11),
                nisfAlLayl: Self.at(24, 11), lastThirdStart: Self.at(25, 31)
            )
        )
    }

    private var fastingModel: WidgetDayModel {
        let base = model
        return WidgetDayModel(
            date: base.date,
            slots: base.slots,
            nextPrayer: base.nextPrayer,
            nextTime: base.nextTime,
            countdown: base.countdown,
            currentPrayer: base.currentPrayer,
            currentWindow: base.currentWindow,
            sunrise: base.sunrise,
            cityName: base.cityName,
            timeZoneIdentifier: base.timeZoneIdentifier,
            isPaused: false,
            hijri: base.hijri,
            fasting: canonicalFasting,
            night: base.night
        )
    }
}
#endif
