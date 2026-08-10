import IhsanCore
import IhsanDesignSystem
import IhsanLocation
import IhsanPrayerTimes
import SwiftData
import SwiftUI

/// The My Masjid editor.
///
/// Everything here is entered by hand. No masjid times are fetched from
/// anywhere, by design — the person types what they read off the board, and
/// each row shows them the time it produces today so a wrong entry is
/// visible where it was made.
struct MyMasjidEditorScreen: View {
    let masjid: MyMasjid
    let settings: UserSettings

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Today's calculated times for the resolved-today lines. Absent until
    /// the place resolves, and absent for good where it never does.
    @State private var today: DayPrayerTimes?
    @State private var timeZone: TimeZone = .autoupdatingCurrent
    @State private var isConfirmingRemoval = false

    private let provider = AdhanPrayerTimesProvider()

    var body: some View {
        let tokens = IhsanPageChrome.tokens(at: NowProvider.active.now())

        PickerScaffold(title: "My Masjid") {
            venueSection(tokens: tokens)
            iqamahSection(tokens: tokens)
            jumuahSection(tokens: tokens)
            remindersSection
            removalSection
        }
        .task { await loadTodaysTimes() }
        .confirmationDialog(
            "Remove your masjid?",
            isPresented: $isConfirmingRemoval,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) { remove() }
            Button("Keep", role: .cancel) {}
        } message: {
            Text("The times you entered will be cleared.")
        }
    }

    // MARK: - Sections

    private func venueSection(tokens: SkyPaletteTokens) -> some View {
        SettingsSectionCard("The masjid") {
            VStack(alignment: .leading, spacing: IhsanSpacing.xs) {
                TextField(
                    "Name",
                    text: Binding(
                        get: { masjid.name ?? "" },
                        set: {
                            masjid.name = $0.isEmpty ? nil : $0
                            masjid.modifiedAt = .now
                        }
                    )
                )
                .font(IhsanFont.bodyEnglish)
                .foregroundStyle(tokens.ink)
                .textInputAutocapitalization(.words)
                .accessibilityLabel("Masjid name")

                if let street = masjid.streetLabel {
                    Text(street.uppercased())
                        .font(IhsanFont.inscription)
                        .tracking(1.3)
                        .foregroundStyle(tokens.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .settingsControlInset()
            .padding(.vertical, IhsanSpacing.xs)
        }
    }

    private func iqamahSection(tokens: SkyPaletteTokens) -> some View {
        SettingsSectionCard("Iqamah") {
            ForEach(Prayer.allCases, id: \.self) { prayer in
                IqamahRow(
                    prayer: prayer,
                    adhan: today?.time(for: prayer),
                    timeZone: timeZone,
                    tokens: tokens,
                    entry: masjid.entry(for: prayer)
                ) { updated in
                    masjid.setEntry(updated)
                }
            }

            SettingsDescriptionText("Enter the times your masjid keeps. An offset follows the calculated adhan each day; a set time stays where you put it.")
        }
    }

    private func jumuahSection(tokens: SkyPaletteTokens) -> some View {
        SettingsSectionCard("Jumu'ah") {
            VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
                Divider().overlay(tokens.metal.opacity(0.18))

                if masjid.jumuahKhutbahMinutesFromMidnight == nil {
                    Button {
                        Haptics.impact(.light)
                        masjid.jumuahKhutbahMinutesFromMidnight = 13 * 60
                        masjid.modifiedAt = .now
                    } label: {
                        Text("SET THE KHUTBAH TIME")
                            .font(IhsanFont.inscription)
                            .tracking(1.6)
                            .foregroundStyle(tokens.metal)
                            .padding(.vertical, IhsanSpacing.sm)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Adds a Friday khutbah time.")
                } else {
                    HStack {
                        Text("Khutbah")
                            .font(IhsanFont.bodyEnglish)
                            .foregroundStyle(tokens.ink)
                        Spacer(minLength: IhsanSpacing.sm)
                        DatePicker(
                            "",
                            selection: khutbahBinding,
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .accessibilityLabel("Khutbah time")
                    }

                    Button {
                        Haptics.impact(.light)
                        masjid.jumuahKhutbahMinutesFromMidnight = nil
                        masjid.modifiedAt = .now
                    } label: {
                        Text("CLEAR")
                            .font(IhsanFont.inscription)
                            .tracking(1.6)
                            .foregroundStyle(tokens.inkSecondary)
                            .padding(.vertical, IhsanSpacing.xs)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear the khutbah time")
                }
            }
            .settingsControlInset()
            .padding(.vertical, IhsanSpacing.xs)

            SettingsDescriptionText("On Fridays this replaces the Dhuhr iqamah.")
        }
    }

    private var remindersSection: some View {
        SettingsSectionCard("Reminders") {
            HStack {
                miniCountControl(
                    label: "Remind me before iqamah (min)",
                    value: masjid.reminderLeadMinutes,
                    step: 5,
                    range: 0...60,
                    accessibilityLabel: "Minutes before iqamah to be reminded"
                ) {
                    masjid.reminderLeadMinutes = $0
                    masjid.modifiedAt = .now
                }
                Spacer()
            }
            .settingsControlInset()
            .padding(.vertical, IhsanSpacing.xs)

            SettingsDescriptionText("A reminder arrives only for the prayers you switched on above, and never during a pause or after you have logged that prayer.")
        }
    }

    private var removalSection: some View {
        SettingsSectionCard("Remove") {
            SettingsRow(
                title: "Remove my masjid",
                glyph: .remove,
                action: {
                    Haptics.impact(.light)
                    isConfirmingRemoval = true
                },
                accessory: { EmptyView() }
            )

            SettingsDescriptionText("Removing it takes the iqamah times off the card and the log sheet, and cancels any reminders.")
        }
    }

    // MARK: - Work

    private var khutbahBinding: Binding<Date> {
        Binding(
            get: {
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = timeZone
                let minutes = masjid.jumuahKhutbahMinutesFromMidnight ?? 13 * 60
                let midnight = calendar.startOfDay(
                    for: today?.dhuhr.scheduledTime ?? Date(timeIntervalSince1970: 0)
                )
                return midnight.addingTimeInterval(TimeInterval(minutes * 60))
            },
            set: { newDate in
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = timeZone
                let parts = calendar.dateComponents([.hour, .minute], from: newDate)
                masjid.jumuahKhutbahMinutesFromMidnight =
                    (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
                masjid.modifiedAt = .now
            }
        )
    }

    /// Today's schedule for the resolved lines, from the same place and the
    /// same tuning every other surface computes against. The coordinate is
    /// read and used here and never written anywhere.
    private func loadTodaysTimes() async {
        guard let place = CoreLocationCoordinator.shared.mostRecentResolvedPlace()
        else { return }
        timeZone = place.timeZone
        today = try? provider.dayTimes(
            for: NowProvider.active.now(),
            coordinates: place.coordinates,
            timeZone: place.timeZone,
            calculationMethod: settings.calculationMethod,
            madhab: settings.madhab,
            highLatitudeRule: settings.highLatitudeRule,
            tuning: settings.calculationTuning
        )
    }

    private func remove() {
        modelContext.delete(masjid)
        try? modelContext.save()
        dismiss()
    }
}
