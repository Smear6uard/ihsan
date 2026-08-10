import IhsanCore
import IhsanDesignSystem
import SwiftUI

/// One prayer's iqamah: the rule, and the time that rule produces today.
///
/// The resolved line is the point of this row. An iqamah entered wrong — a
/// fixed time that lands before its adhan, an offset with a stray digit —
/// is invisible in the rule and obvious in the answer, so the answer is
/// always on screen. Nothing here silently corrects anything.
///
/// No gold appears in this row. Gilding means *committed* everywhere else
/// in the app — the logged ornament, the On Time button, the LOG chip — and
/// an informational time may not borrow that meaning.
struct IqamahRow: View {
    let prayer: Prayer
    /// Today's adhan for this prayer. `nil` where no schedule is in hand;
    /// the resolved line then prints nothing rather than a guess.
    let adhan: Date?
    let timeZone: TimeZone
    let tokens: SkyPaletteTokens
    let entry: IqamahEntry
    let onChange: (IqamahEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
            Divider()
                .overlay(tokens.metal.opacity(0.18))

            HStack(alignment: .firstTextBaseline) {
                Text(prayer.displayNameEnglish)
                    .font(IhsanFont.bodyEnglish)
                    .foregroundStyle(tokens.ink)
                Spacer(minLength: IhsanSpacing.sm)
                modePicker
            }

            valueControl

            if let resolvedLine {
                Text(resolvedLine)
                    .font(IhsanFont.inscription)
                    .tracking(1.3)
                    .foregroundStyle(tokens.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(spokenResolvedLine ?? resolvedLine)
            }

            if entry.isSet {
                Toggle(isOn: reminderBinding) {
                    Text("Remind me")
                        .font(IhsanFont.bodyEnglish)
                        .foregroundStyle(tokens.inkSecondary)
                }
                .tint(tokens.leafGold)
                .accessibilityLabel(
                    "Remind me before \(prayer.displayNameEnglish) iqamah"
                )
            }
        }
        .settingsControlInset()
        .padding(.vertical, IhsanSpacing.sm)
    }

    // MARK: - Controls

    private var modePicker: some View {
        Picker("", selection: modeBinding) {
            Text("None").tag(IqamahEntry.Mode.none)
            Text("Time").tag(IqamahEntry.Mode.fixed)
            Text("Offset").tag(IqamahEntry.Mode.offset)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(maxWidth: 220)
        .accessibilityLabel("\(prayer.displayNameEnglish) iqamah kind")
    }

    @ViewBuilder
    private var valueControl: some View {
        switch entry.mode {
        case .none:
            EmptyView()

        case .fixed:
            // The platform's own time entry: localized to 12- or 24-hour
            // by the reader's settings, Dynamic Type correct, and already
            // known to VoiceOver. Hand-rolling one would lose all three.
            DatePicker(
                "",
                selection: fixedTimeBinding,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .accessibilityLabel("\(prayer.displayNameEnglish) iqamah time")

        case .offset:
            miniCountControl(
                label: "Minutes after the adhan",
                value: entry.offsetMinutes ?? 0,
                step: 5,
                range: 0...90,
                accessibilityLabel:
                    "Minutes after the \(prayer.displayNameEnglish) adhan"
            ) { newValue in
                var updated = entry
                updated.offsetMinutes = newValue
                onChange(updated)
            }
        }
    }

    // MARK: - The resolved answer

    private var resolvedIqamah: Date? {
        guard let adhan else { return nil }
        return IqamahSchedule.resolve(entry: entry, adhan: adhan, timeZone: timeZone)
    }

    private var resolvedLine: String? {
        guard let resolvedIqamah else { return nil }
        return "TODAY · \(PlateTimeFormat.time(resolvedIqamah, in: timeZone))"
    }

    private var spokenResolvedLine: String? {
        guard let resolvedIqamah else { return nil }
        return "Today, \(PlateTimeFormat.time(resolvedIqamah, in: timeZone))"
    }

    // MARK: - Bindings

    private var modeBinding: Binding<IqamahEntry.Mode> {
        Binding(
            get: { entry.mode },
            set: { newMode in
                var updated = entry
                updated.mode = newMode
                // Give a freshly chosen mode something to show. Landing on
                // an empty control reads as a broken row.
                switch newMode {
                case .fixed where updated.fixedMinutesFromMidnight == nil:
                    updated.fixedMinutesFromMidnight = defaultFixedMinutes
                case .offset where updated.offsetMinutes == nil:
                    updated.offsetMinutes = 10
                default:
                    break
                }
                onChange(updated)
            }
        )
    }

    /// A fixed row opens at this prayer's own adhan rounded to the next
    /// five minutes — the nearest thing to a sensible guess — or at a plain
    /// hour when no schedule is in hand.
    private var defaultFixedMinutes: Int {
        guard let adhan else { return 13 * 60 }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.hour, .minute], from: adhan)
        let minutes = (parts.hour ?? 12) * 60 + (parts.minute ?? 0)
        return min(1435, ((minutes + 4) / 5) * 5)
    }

    private var fixedTimeBinding: Binding<Date> {
        Binding(
            get: {
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = timeZone
                let minutes = entry.fixedMinutesFromMidnight ?? defaultFixedMinutes
                let midnight = calendar.startOfDay(for: adhan ?? Date(timeIntervalSince1970: 0))
                return midnight.addingTimeInterval(TimeInterval(minutes * 60))
            },
            set: { newDate in
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = timeZone
                let parts = calendar.dateComponents([.hour, .minute], from: newDate)
                var updated = entry
                updated.fixedMinutesFromMidnight =
                    (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
                onChange(updated)
            }
        )
    }

    private var reminderBinding: Binding<Bool> {
        Binding(
            get: { entry.reminderEnabled },
            set: { newValue in
                var updated = entry
                updated.reminderEnabled = newValue
                onChange(updated)
            }
        )
    }
}
