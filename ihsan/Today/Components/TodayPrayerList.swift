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
                let adhanEnabled = settingsRows.first?.adhanEnabled(for: prayerTime.prayer) ?? true

                PrayerRowComposable(
                    prayer: prayerTime.prayer,
                    scheduledTime: prayerTime.scheduledTime,
                    status: log?.status,
                    isJamaah: log?.withJamaah ?? false,
                    isActive: snapshot.activePrayer == prayerTime.prayer,
                    adhanEnabled: adhanEnabled,
                    onSetStatus: { onSetStatus(prayerTime.prayer, $0) },
                    onToggleJamaah: { onToggleJamaah(prayerTime.prayer) },
                    onToggleAdhan: { onToggleAdhan(prayerTime.prayer) }
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
    let adhanEnabled: Bool
    let onSetStatus: (PrayerStatus) -> Void
    let onToggleJamaah: () -> Void
    let onToggleAdhan: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingActionDialog = false

    var body: some View {
        // The foreground colours track the illuminated panel material —
        // dark ink on cream panels during the day, bone cream on amber
        // panels at night — so every text element on the row stays WCAG
        // AAA against the surface it sits on. Brass becomes the prayer-
        // symbol tint, the prayer-name English uses the manuscript
        // serif, the time uses tabular monospace.
        let now = Date.now
        let foreground = IhsanColor.cardForegroundPrimary(at: now)
        let foregroundSecondary = IhsanColor.cardForegroundSecondary(at: now)
        let foregroundMuted = IhsanColor.cardForegroundMuted(at: now)
        let prayerSymbolColor = isActive
            ? IhsanColor.gold
            : IhsanColor.brass.opacity(0.70)

        HStack(spacing: IhsanSpacing.md) {
            PrayerSymbol(
                prayer,
                size: 22,
                tint: prayerSymbolColor,
                weight: isActive ? .semibold : .regular
            )
            .frame(width: 28)

            VStack(alignment: .leading, spacing: IhsanSpacing.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: IhsanSpacing.sm) {
                    Text(prayer.displayNameEnglish)
                        .font(IhsanFont.rowPrayerName)
                        .foregroundStyle(foreground)
                    Text(prayer.displayNameArabic)
                        .font(IhsanFont.bodyArabic)
                        .foregroundStyle(foregroundSecondary)
                }
                Text(scheduledTime, format: .dateTime.hour().minute())
                    .font(IhsanFont.tabular)
                    .foregroundStyle(foregroundMuted)
            }

            Spacer(minLength: IhsanSpacing.sm)

            Button {
                showingActionDialog = true
            } label: {
                statusContent(foreground: foreground)
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)

            AdhanMuteToggle(
                adhanEnabled: .constant(adhanEnabled),
                accessibilityPrayerName: prayer.displayNameEnglish,
                onToggle: { onToggleAdhan() },
                tint: foreground
            )
            .accessibilityHidden(true)

            JamaahToggle(
                isJamaah: .constant(isJamaah),
                onToggle: { onToggleJamaah() },
                tint: foreground
            )
            .accessibilityHidden(true)
        }
        .padding(.horizontal, IhsanSpacing.md)
        .padding(.vertical, IhsanSpacing.sm)
        .frame(minHeight: IhsanSpacing.prayerRowHeight)
        .ihsanIlluminatedPanel(intensity: .prayerRow, isActive: isActive)
        .confirmationDialog(
            prayer.displayNameEnglish,
            isPresented: $showingActionDialog,
            titleVisibility: .visible
        ) {
            Button("On Time") { setStatus(.onTime) }
            Button("Late") { setStatus(.late) }
            Button("Missed", role: .destructive) { setStatus(.missed) }
            Button("Qada") { setStatus(.qada) }
            Button("Cancel", role: .cancel) {}
        }
        // The row reads as one composite element to VoiceOver — name,
        // scheduled time, status, jama'ah, plus active flag — and exposes
        // the three interactive controls as custom actions on the rotor
        // instead of as separate focus stops.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rowAccessibilityLabel)
        .accessibilityAction(named: statusActionLabel) {
            showingActionDialog = true
        }
        .accessibilityAction(named: isJamaah ? "Mark as individual" : "Mark as jama'ah") {
            onToggleJamaah()
        }
        .accessibilityAction(named: adhanEnabled ? "Mute adhan for \(prayer.displayNameEnglish)" : "Unmute adhan for \(prayer.displayNameEnglish)") {
            onToggleAdhan()
        }
    }

    private func setStatus(_ status: PrayerStatus) {
        Haptics.impact(.light)
        onSetStatus(status)
    }

    /// Status pill / placeholder, with a subtle scale + opacity beat on
    /// status change so the pill never hard-cuts to a new colour. The
    /// `foreground` colour flows from the row's surrounding warm card
    /// material — passing it into `StatusPill` keeps the pill's text
    /// rebased on dark ink during the day and bone cream at night.
    @ViewBuilder
    private func statusContent(foreground: Color) -> some View {
        Group {
            if let status {
                StatusPill(status, foreground: foreground)
            } else {
                StatusPlaceholder(foreground: foreground)
            }
        }
        .modifier(StatusPillBeat(trigger: status, reduceMotion: reduceMotion))
    }

    private var statusAccessibilityLabel: String {
        if let status {
            return "Status: \(status.spokenLabel), tap to change"
        }
        return "Tap to log \(prayer.displayNameEnglish)"
    }

    private var statusActionLabel: String {
        status == nil ? "Log prayer" : "Change status"
    }

    /// One spoken sentence describing the row. VoiceOver reads:
    ///   "Asr, scheduled 4:32 PM, on time, jama'ah, adhan muted, active prayer."
    private var rowAccessibilityLabel: String {
        var parts: [String] = [prayer.displayNameEnglish]
        let timeText = scheduledTime.formatted(date: .omitted, time: .shortened)
        parts.append("scheduled \(timeText)")
        if let status {
            parts.append(status.spokenLabel)
        } else {
            parts.append("not yet logged")
        }
        if isJamaah {
            parts.append("jama'ah")
        }
        if !adhanEnabled {
            parts.append("adhan muted")
        }
        if isActive {
            parts.append("active prayer")
        }
        return parts.joined(separator: ", ")
    }
}

private extension PrayerStatus {
    /// Human-spoken form of the status. The raw values ("onTime",
    /// "qada") read as one robotic word in VoiceOver; this expands them.
    var spokenLabel: String {
        switch self {
        case .onTime: return "on time"
        case .late: return "late"
        case .missed: return "missed"
        case .qada: return "qada, made up later"
        }
    }
}

/// Briefly compresses the status pill to 0.95 / 0.65 opacity then springs
/// back to 1.0 / 1.0 whenever the status changes. Reduce-motion users get
/// the new pill without any motion.
private struct StatusPillBeat: ViewModifier {
    let trigger: PrayerStatus?
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .keyframeAnimator(
                    initialValue: PillBeat(),
                    trigger: trigger
                ) { view, value in
                    view
                        .scaleEffect(value.scale)
                        .opacity(value.opacity)
                } keyframes: { _ in
                    KeyframeTrack(\.scale) {
                        CubicKeyframe(0.95, duration: 0.08)
                        SpringKeyframe(1.0, spring: .smooth(duration: 0.32))
                    }
                    KeyframeTrack(\.opacity) {
                        CubicKeyframe(0.65, duration: 0.08)
                        CubicKeyframe(1.0, duration: 0.22)
                    }
                }
        }
    }

    private struct PillBeat {
        var scale: Double = 1.0
        var opacity: Double = 1.0
    }
}

private struct StatusPlaceholder: View {
    let foreground: Color

    var body: some View {
        HStack(spacing: IhsanSpacing.xs) {
            Image(systemName: "circle.dashed")
                .font(.system(size: 11, weight: .semibold))
            Text("Log")
                .font(IhsanFont.smallCaps)
        }
        .foregroundStyle(foreground.opacity(0.55))
        .padding(.horizontal, IhsanSpacing.sm + 2)
        .padding(.vertical, IhsanSpacing.xs + 2)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule().strokeBorder(foreground.opacity(0.22), lineWidth: 0.5)
                }
        }
    }
}
