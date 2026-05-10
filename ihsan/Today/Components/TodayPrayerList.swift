import SwiftUI
import SwiftData
import IhsanCore
import IhsanDesignSystem
import IhsanPrayerTimes

struct TodayPrayerList: View {
    let snapshot: TodayState.Snapshot
    let onSetStatus: (Prayer, PrayerStatus) -> Void
    let onToggleJamaah: (Prayer) -> Void
    let onToggleAdhan: (Prayer) -> Void

    @Query private var todaysLogs: [PrayerLog]
    @Query private var settingsRows: [UserSettings]

    @State private var sheetSelection: LogSheetSelection?

    init(
        snapshot: TodayState.Snapshot,
        onSetStatus: @escaping (Prayer, PrayerStatus) -> Void,
        onToggleJamaah: @escaping (Prayer) -> Void,
        onToggleAdhan: @escaping (Prayer) -> Void
    ) {
        self.snapshot = snapshot
        self.onSetStatus = onSetStatus
        self.onToggleJamaah = onToggleJamaah
        self.onToggleAdhan = onToggleAdhan

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: .now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        let predicate = #Predicate<PrayerLog> { log in
            log.prayerDate >= startOfDay && log.prayerDate < endOfDay
        }
        self._todaysLogs = Query(filter: predicate, sort: \PrayerLog.prayerDate)
    }

    var body: some View {
        VStack(spacing: IhsanSpacing.sm) {
            ForEach(snapshot.dayTimes.allFardh, id: \.prayer) { prayerTime in
                let log = todaysLogs.first { $0.prayer == prayerTime.prayer }
                let windowEnd = windowEndTime(for: prayerTime.prayer)
                let isActive = snapshot.activePrayer == prayerTime.prayer

                PrayerRowComposable(
                    prayer: prayerTime.prayer,
                    scheduledTime: prayerTime.scheduledTime,
                    windowEndTime: windowEnd,
                    log: log,
                    isActive: isActive,
                    isJamaah: log?.withJamaah ?? false,
                    onTap: { openSheet(for: prayerTime.prayer) }
                )

                if prayerTime.prayer == .fajr {
                    SunriseBoundaryRow(sunriseTime: snapshot.dayTimes.sunrise)
                }
            }
        }
        .sheet(item: $sheetSelection) { selection in
            logSheet(for: selection.prayer)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.thinMaterial)
        }
    }

    // MARK: - Sheet wiring

    private func openSheet(for prayer: Prayer) {
        Haptics.impact(.light)
        sheetSelection = LogSheetSelection(prayer: prayer)
    }

    @ViewBuilder
    private func logSheet(for prayer: Prayer) -> some View {
        let prayerTime = snapshot.dayTimes.allFardh.first { $0.prayer == prayer }
        let log = todaysLogs.first { $0.prayer == prayer }
        let adhanEnabled = settingsRows.first?.adhanEnabled(for: prayer) ?? true

        if let prayerTime {
            PrayerLogSheet(
                prayer: prayer,
                scheduledTime: prayerTime.scheduledTime,
                windowEndTime: windowEndTime(for: prayer),
                currentStatus: log?.status,
                isJamaah: log?.withJamaah ?? false,
                adhanEnabled: adhanEnabled,
                onSelect: { choice in handleSheetChoice(choice, for: prayer) },
                onToggleAdhan: { onToggleAdhan(prayer) },
                onCancel: {}
            )
        }
    }

    private func handleSheetChoice(_ choice: PrayerLogSheet.Choice, for prayer: Prayer) {
        let currentJamaah = todaysLogs.first { $0.prayer == prayer }?.withJamaah ?? false

        switch choice {
        case .inJamaah:
            onSetStatus(prayer, .onTime)
            if !currentJamaah { onToggleJamaah(prayer) }
        case .onTime:
            onSetStatus(prayer, .onTime)
            if currentJamaah { onToggleJamaah(prayer) }
        case .late:
            onSetStatus(prayer, .late)
        case .qada:
            onSetStatus(prayer, .qada)
        case .missed:
            onSetStatus(prayer, .missed)
        }
    }

    // MARK: - Window helpers

    /// The end of `prayer`'s window. Fajr ends at sunrise, Dhuhr–
    /// Maghrib at the next prayer, and Isha returns `nil` because
    /// the window extends past midnight (the row inscription drops
    /// the "WINDOW ENDS …" clause when this is nil).
    private func windowEndTime(for prayer: Prayer) -> Date? {
        switch prayer {
        case .fajr: return snapshot.dayTimes.sunrise
        case .dhuhr: return snapshot.dayTimes.asr.scheduledTime
        case .asr: return snapshot.dayTimes.maghrib.scheduledTime
        case .maghrib: return snapshot.dayTimes.isha.scheduledTime
        case .isha: return nil
        }
    }
}

// MARK: - Sheet selection wrapper

/// `Prayer` is a plain enum, so it can't drive `.sheet(item:)`
/// directly. Wrapping it in an `Identifiable` lets the sheet
/// re-present cleanly when the user taps a different row.
private struct LogSheetSelection: Identifiable, Hashable {
    let prayer: Prayer
    var id: Prayer { prayer }
}

// MARK: - Row

/// One illuminated row in the prayer list. Reads as a parchment
/// panel with the prayer's name (English + Arabic) and a small-caps
/// state inscription beneath it; trailing chevron signals "tap to
/// log". The active prayer card pulls a stronger iridescent border
/// and an inner gold halo via `.ihsanIlluminatedPanel(isActive:)`.
private struct PrayerRowComposable: View {
    let prayer: Prayer
    let scheduledTime: Date
    let windowEndTime: Date?
    let log: PrayerLog?
    let isActive: Bool
    let isJamaah: Bool
    let onTap: () -> Void

    var body: some View {
        let now = Date.now
        let foreground = IhsanColor.cardForegroundPrimary(at: now)
        let foregroundSecondary = IhsanColor.cardForegroundSecondary(at: now)
        let prayerSymbolColor = isActive
            ? IhsanColor.gold
            : IhsanColor.brass.opacity(0.70)
        let inscription = PrayerRowInscription.text(
            for: prayer,
            scheduledTime: scheduledTime,
            windowEndTime: windowEndTime,
            log: log,
            isActive: isActive,
            now: now
        )

        Button(action: onTap) {
            HStack(spacing: IhsanSpacing.md) {
                PrayerSymbol(
                    prayer,
                    size: 22,
                    tint: prayerSymbolColor,
                    weight: isActive ? .semibold : .regular
                )
                .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: IhsanSpacing.sm) {
                        Text(prayer.displayNameEnglish)
                            .font(IhsanFont.rowPrayerName)
                            .foregroundStyle(foreground)
                        Text(prayer.displayNameArabic)
                            .font(IhsanFont.bodyArabic)
                            .foregroundStyle(foregroundSecondary)
                    }
                    Text(inscription)
                        .font(IhsanFont.inscription)
                        .tracking(1.4)
                        .foregroundStyle(IhsanColor.brassDark.opacity(isActive ? 0.95 : 0.80))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: IhsanSpacing.sm)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(IhsanColor.brassDark.opacity(0.55))
            }
            .padding(.horizontal, IhsanSpacing.md)
            .padding(.vertical, IhsanSpacing.sm)
            .frame(minHeight: IhsanSpacing.prayerRowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .ihsanIlluminatedPanel(intensity: .prayerRow, isActive: isActive)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Tap to log this prayer")
        .accessibilityAddTraits(.isButton)
    }

    private var accessibilityLabel: String {
        var parts: [String] = [prayer.displayNameEnglish]
        let timeText = scheduledTime.formatted(date: .omitted, time: .shortened)
        parts.append("scheduled \(timeText)")
        if let status = log?.status {
            parts.append(status.spokenLabel)
        } else {
            parts.append("not yet logged")
        }
        if isJamaah {
            parts.append("jama'ah")
        }
        if isActive {
            parts.append("active prayer")
        }
        return parts.joined(separator: ", ")
    }
}

private extension PrayerStatus {
    var spokenLabel: String {
        switch self {
        case .onTime: return "on time"
        case .late: return "late"
        case .missed: return "missed"
        case .qada: return "qada, made up later"
        }
    }
}
