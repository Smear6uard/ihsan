import IhsanCore
import SwiftUI

/// The lock-screen accessory faces.
///
/// Accessories render in vibrant material: colour is discarded and
/// only luminance survives. Every face here is therefore designed as
/// a luminance drawing first — ornament linework as the identity,
/// `.primary` for the one thing the glance is about, `.secondary` and
/// `.tertiary` for everything that supports it. No SF Symbol ever
/// stands in for a prayer.

// MARK: - Circular A · Next Prayer

/// The next prayer's ornament over its hour — the app's mark on the
/// lock screen, legible as pure form.
public struct AccessoryNextPrayerFace: View {
    public let prayer: Prayer
    public let time: Date
    public let timeZoneIdentifier: String
    public let isCurrent: Bool

    public init(prayer: Prayer, time: Date, timeZoneIdentifier: String, isCurrent: Bool) {
        self.prayer = prayer
        self.time = time
        self.timeZoneIdentifier = timeZoneIdentifier
        self.isCurrent = isCurrent
    }

    public var body: some View {
        VStack(spacing: 2) {
            OrnamentLinework(prayer: prayer, size: 24, isEmphasised: isCurrent)
            Text(clockShort(time, timeZoneIdentifier))
                .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .widgetFaceAccent(.accented)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(prayer.displayNameEnglish) at \(clockShort(time, timeZoneIdentifier))"
        )
    }
}

// MARK: - Circular B · Window Gauge

/// How much of the current prayer's window remains — a ring that
/// fills as the window elapses, the prayer's own ornament at its
/// centre. Between windows (the forenoon gap) the ring stands empty
/// around the next prayer's mark.
public struct AccessoryWindowGaugeFace: View {
    public let prayer: Prayer
    /// The open window, or nil in a gap.
    public let window: ClosedRange<Date>?
    public let isCurrent: Bool

    public init(prayer: Prayer, window: ClosedRange<Date>?, isCurrent: Bool) {
        self.prayer = prayer
        self.window = window
        self.isCurrent = isCurrent
    }

    public var body: some View {
        Group {
            if let window {
                // Self-updating: the system advances the ring without
                // a single extra timeline entry.
                ProgressView(timerInterval: window, countsDown: false) {
                    Text(prayer.displayNameEnglish)
                } currentValueLabel: {
                    OrnamentLinework(prayer: prayer, size: 20, isEmphasised: isCurrent)
                }
                .progressViewStyle(.circular)
            } else {
                ZStack {
                    Circle()
                        .stroke(.tertiary, lineWidth: 4)
                    OrnamentLinework(prayer: prayer, size: 20, isEmphasised: false)
                }
                .padding(2)
            }
        }
        .widgetFaceAccent(.accented)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if window != nil {
            return "\(prayer.displayNameEnglish) window in progress"
        }
        return "Next, \(prayer.displayNameEnglish)"
    }
}

// MARK: - Rectangular A · Now & Next

/// Two lines in the inscription register: the prayer standing now,
/// and the one being waited for with its hour.
public struct AccessoryNowNextFace: View {
    public let current: Prayer?
    public let next: Prayer
    public let nextTime: Date
    public let timeZoneIdentifier: String

    public init(current: Prayer?, next: Prayer, nextTime: Date, timeZoneIdentifier: String) {
        self.current = current
        self.next = next
        self.nextTime = nextTime
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let current {
                HStack(spacing: 5) {
                    OrnamentLinework(prayer: current, size: 14, isEmphasised: true)
                    Text("NOW")
                        .font(.system(size: 10, weight: .semibold).smallCaps())
                        .tracking(1.0)
                        .foregroundStyle(.secondary)
                    Text(current.displayNameEnglish)
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                }
                .widgetFaceAccent(.accented)
            } else {
                HStack(spacing: 5) {
                    Text("BEFORE")
                        .font(.system(size: 10, weight: .semibold).smallCaps())
                        .tracking(1.0)
                        .foregroundStyle(.secondary)
                    Text(next.displayNameEnglish)
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                }
                .widgetFaceAccent(.accented)
            }

            HStack(spacing: 5) {
                OrnamentLinework(prayer: next, size: 14, isEmphasised: false)
                Text("NEXT")
                    .font(.system(size: 10, weight: .semibold).smallCaps())
                    .tracking(1.0)
                    .foregroundStyle(.secondary)
                Text(next.displayNameEnglish)
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .foregroundStyle(.secondary)
                Text(clockShort(nextTime, timeZoneIdentifier))
                    .font(.system(size: 13, weight: .regular, design: .rounded).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var text = ""
        if let current { text += "\(current.displayNameEnglish) now. " }
        text += "Next, \(next.displayNameEnglish) at \(clockShort(nextTime, timeZoneIdentifier))"
        return text
    }
}

// MARK: - Rectangular B · The Day Row

/// The whole day on the lock screen: five mini ornaments in state,
/// each over its hour.
public struct AccessoryDayRowFace: View {
    public let slots: [WidgetDayModel.Slot]
    public let timeZoneIdentifier: String

    public init(slots: [WidgetDayModel.Slot], timeZoneIdentifier: String) {
        self.slots = slots
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(slots) { slot in
                VStack(spacing: 3) {
                    // Filled-vs-outline already says the state; a
                    // dimmed outline would vanish on a busy
                    // wallpaper, so only the passed-unlogged mark
                    // steps back, and only slightly.
                    OrnamentLinework(
                        prayer: slot.prayer,
                        size: 16,
                        isEmphasised: slot.state == .current || slot.state == .logged
                    )
                    .opacity(slot.state == .passedUnlogged ? 0.75 : 1)

                    Text(hourOnly(slot.time, timeZoneIdentifier))
                        .font(.system(size: 10, weight: slot.state == .current ? .semibold : .regular, design: .rounded).monospacedDigit())
                        .foregroundStyle(slot.state == .current ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .widgetFaceAccent(.accented)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            slots.map {
                "\($0.prayer.displayNameEnglish) \(clockShort($0.time, timeZoneIdentifier)), \($0.state.spokenDescription)"
            }.joined(separator: ", ")
        )
    }
}

// MARK: - Rectangular C · Night

/// The night's divisions — nisf al-layl and the last third — for the
/// one who rises. Between Maghrib and Fajr the current division
/// leads; through the day it quietly holds tonight's instants.
public struct AccessoryNightFace: View {
    public let night: WidgetNightModel
    public let date: Date
    public let timeZoneIdentifier: String

    public init(night: WidgetNightModel, date: Date, timeZoneIdentifier: String) {
        self.night = night
        self.date = date
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    private var isNight: Bool {
        date >= night.start && date < night.end
    }
    private var inLastThird: Bool {
        isNight && date >= night.lastThirdStart
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if inLastThird {
                headline("LAST THIRD", until: night.end, label: "UNTIL FAJR")
            } else if isNight, date >= night.nisfAlLayl {
                headline("LAST THIRD", at: night.lastThirdStart)
                subline("NISF AL-LAYL PASSED · \(clockShort(night.nisfAlLayl, timeZoneIdentifier))")
            } else if isNight {
                headline("NISF AL-LAYL", at: night.nisfAlLayl)
                subline("LAST THIRD · \(clockShort(night.lastThirdStart, timeZoneIdentifier))")
            } else {
                Text("TONIGHT")
                    .font(.system(size: 10, weight: .semibold).smallCaps())
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                subline("NISF \(clockShort(night.nisfAlLayl, timeZoneIdentifier)) · LAST THIRD \(clockShort(night.lastThirdStart, timeZoneIdentifier))")
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.65)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private func headline(_ title: String, at instant: Date) -> some View {
        HStack(spacing: 5) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .serif))
            Text("·")
                .foregroundStyle(.secondary)
            Text(clockShort(instant, timeZoneIdentifier))
                .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
        }
        .widgetFaceAccent(.accented)
    }

    @ViewBuilder
    private func headline(_ title: String, until end: Date, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                Text("· NOW")
                    .font(.system(size: 10, weight: .semibold).smallCaps())
                    .tracking(1.0)
                    .foregroundStyle(.secondary)
            }
            .widgetFaceAccent(.accented)
            subline("\(label) \(clockShort(end, timeZoneIdentifier))")
        }
    }

    private func subline(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .regular, design: .rounded).monospacedDigit())
            .foregroundStyle(.secondary)
    }

    private var accessibilityText: String {
        if inLastThird {
            return "Last third of the night, until Fajr at \(clockShort(night.end, timeZoneIdentifier))"
        }
        return "Nisf al-layl \(clockShort(night.nisfAlLayl, timeZoneIdentifier)), last third \(clockShort(night.lastThirdStart, timeZoneIdentifier))"
    }
}

// MARK: - Fasting · Circular gauge

/// The fast as a ring: filling from suhoor to iftar, the remaining
/// time at its centre. Before suhoor it counts the pre-dawn meal down
/// instead.
public struct AccessoryFastingGaugeFace: View {
    public let fasting: WidgetFastingModel
    public let date: Date

    public init(fasting: WidgetFastingModel, date: Date) {
        self.fasting = fasting
        self.date = date
    }

    private var towardSuhoor: Bool {
        date < fasting.suhoorEnds
    }

    public var body: some View {
        ProgressView(
            timerInterval: towardSuhoor
                ? WidgetTimerInterval.countdown(from: min(date, fasting.suhoorEnds), to: fasting.suhoorEnds)
                : fasting.suhoorEnds...max(fasting.iftar, fasting.suhoorEnds),
            countsDown: towardSuhoor
        ) {
            Text(towardSuhoor ? "Suhoor" : "Iftar")
        } currentValueLabel: {
            VStack(spacing: 0) {
                Text(towardSuhoor ? "SUHOOR" : "IFTAR")
                    .font(.system(size: 7, weight: .semibold).smallCaps())
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                Text(
                    timerInterval: WidgetTimerInterval.countdown(
                        from: date,
                        to: towardSuhoor ? fasting.suhoorEnds : fasting.iftar
                    ),
                    countsDown: true,
                    showsHours: true
                )
                .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                .minimumScaleFactor(0.5)
            }
            .lineLimit(1)
        }
        .progressViewStyle(.circular)
        .widgetFaceAccent(.accented)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            towardSuhoor ? "Fasting. Suhoor ends soon." : "Fasting. Iftar ahead."
        )
    }
}

// MARK: - Fasting · Rectangular

/// "FASTING · IFTAR 8:13 PM" with the remaining time ticking beneath.
public struct AccessoryFastingRectFace: View {
    public let fasting: WidgetFastingModel
    public let date: Date
    public let timeZoneIdentifier: String

    public init(fasting: WidgetFastingModel, date: Date, timeZoneIdentifier: String) {
        self.fasting = fasting
        self.date = date
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    private var towardSuhoor: Bool {
        date < fasting.suhoorEnds
    }
    private var target: Date {
        towardSuhoor ? fasting.suhoorEnds : fasting.iftar
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Text(fasting.isRamadan ? "RAMADAN" : "FASTING")
                    .font(.system(size: 10, weight: .semibold).smallCaps())
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                Text("\(towardSuhoor ? "SUHOOR ENDS" : "IFTAR") \(clockShort(target, timeZoneIdentifier))")
                    .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                    .widgetFaceAccent(.accented)
            }

            Text("in \(Text(timerInterval: WidgetTimerInterval.countdown(from: date, to: target), countsDown: true))")
                .font(.system(size: 12, weight: .regular, design: .rounded).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(fasting.isRamadan ? "Ramadan" : "Fasting"). \(towardSuhoor ? "Suhoor ends" : "Iftar") at \(clockShort(target, timeZoneIdentifier))"
        )
    }
}

// MARK: - Shared formatting

/// "4:53 PM" in the place timezone.
private func clockShort(_ date: Date, _ timeZoneIdentifier: String) -> String {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    formatter.dateStyle = .none
    formatter.timeZone = TimeZone(identifier: timeZoneIdentifier)
    return formatter.string(from: date)
}

/// "4:53" — the day row's tight column drops the meridiem; five
/// ascending hours need no AM/PM to read as a day. The hour cycle
/// still follows the person's locale.
private func hourOnly(_ date: Date, _ timeZoneIdentifier: String) -> String {
    let formatter = DateFormatter()
    formatter.timeZone = TimeZone(identifier: timeZoneIdentifier)
    formatter.setLocalizedDateFormatFromTemplate("jmm")
    formatter.amSymbol = ""
    formatter.pmSymbol = ""
    return formatter.string(from: date).trimmingCharacters(in: .whitespaces)
}
