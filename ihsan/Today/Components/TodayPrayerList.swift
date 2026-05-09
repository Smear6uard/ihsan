import SwiftUI
import SwiftData
import IhsanCore
import IhsanDesignSystem
import IhsanPrayerTimes

struct TodayPrayerList: View {
    let snapshot: TodayState.Snapshot
    let onSetStatus: (Prayer, PrayerStatus) -> Void
    let onToggleJamaah: (Prayer) -> Void

    @Query private var todaysLogs: [PrayerLog]

    init(
        snapshot: TodayState.Snapshot,
        onSetStatus: @escaping (Prayer, PrayerStatus) -> Void,
        onToggleJamaah: @escaping (Prayer) -> Void
    ) {
        self.snapshot = snapshot
        self.onSetStatus = onSetStatus
        self.onToggleJamaah = onToggleJamaah

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

                PrayerRowComposable(
                    prayer: prayerTime.prayer,
                    scheduledTime: prayerTime.scheduledTime,
                    status: log?.status,
                    isJamaah: log?.withJamaah ?? false,
                    isActive: snapshot.activePrayer == prayerTime.prayer,
                    onSetStatus: { onSetStatus(prayerTime.prayer, $0) },
                    onToggleJamaah: { onToggleJamaah(prayerTime.prayer) }
                )

                if prayerTime.prayer == .fajr {
                    SunriseBoundaryRow(sunriseTime: snapshot.dayTimes.sunrise)
                }
            }
        }
    }
}

/// Custom row composing design-system primitives. We don't use the design-system
/// `PrayerRow` directly because that variant takes Bindings — here every state
/// mutation must flow through App Intents, so the row is callback-driven.
private struct PrayerRowComposable: View {
    let prayer: Prayer
    let scheduledTime: Date
    let status: PrayerStatus?
    let isJamaah: Bool
    let isActive: Bool
    let onSetStatus: (PrayerStatus) -> Void
    let onToggleJamaah: () -> Void

    @State private var showingActionDialog = false

    var body: some View {
        HStack(spacing: IhsanSpacing.md) {
            PrayerSymbol(prayer, size: 22)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: IhsanSpacing.xxs) {
                HStack(spacing: IhsanSpacing.sm) {
                    Text(prayer.displayNameEnglish)
                        .font(IhsanFont.bodyEnglishBold)
                        .foregroundStyle(isActive ? IhsanColor.textPrimary : IhsanColor.textPrimary.opacity(0.85))
                    Text(prayer.displayNameArabic)
                        .font(IhsanFont.bodyArabic)
                        .foregroundStyle(IhsanColor.textSecondary)
                }
                Text(scheduledTime, format: .dateTime.hour().minute())
                    .font(IhsanFont.tabular)
                    .foregroundStyle(IhsanColor.textMuted)
            }

            Spacer(minLength: IhsanSpacing.sm)

            Button {
                Haptics.tap()
                showingActionDialog = true
            } label: {
                if let status {
                    StatusPill(status)
                } else {
                    StatusPlaceholder()
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(statusAccessibilityLabel)

            JamaahToggle(
                isJamaah: .constant(isJamaah),
                onToggle: { onToggleJamaah() }
            )
        }
        .padding(.horizontal, IhsanSpacing.md)
        .frame(height: IhsanSpacing.prayerRowHeight)
        .ihsanGlass(intensity: isActive ? .hero : .regular)
        .confirmationDialog(
            prayer.displayNameEnglish,
            isPresented: $showingActionDialog,
            titleVisibility: .visible
        ) {
            Button("On Time") { onSetStatus(.onTime) }
            Button("Late") { onSetStatus(.late) }
            Button("Missed", role: .destructive) { onSetStatus(.missed) }
            Button("Qada") { onSetStatus(.qada) }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var statusAccessibilityLabel: String {
        if let status {
            return "Status: \(status.rawValue), tap to change"
        }
        return "Tap to log \(prayer.displayNameEnglish)"
    }
}

private struct StatusPlaceholder: View {
    var body: some View {
        HStack(spacing: IhsanSpacing.xs) {
            Image(systemName: "circle.dashed")
                .font(.system(size: 11, weight: .semibold))
            Text("Log")
                .font(IhsanFont.smallCaps)
        }
        .foregroundStyle(IhsanColor.textMuted)
        .padding(.horizontal, IhsanSpacing.sm + 2)
        .padding(.vertical, IhsanSpacing.xs + 2)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule().strokeBorder(IhsanColor.atmospheric, lineWidth: 0.5)
                }
        }
    }
}
