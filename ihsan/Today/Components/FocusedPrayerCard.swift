import IhsanCore
import IhsanDesignSystem
import SwiftUI

/// The focused-prayer card on the celestial Today screen.
///
/// Replaces the legacy hero countdown + prayer-list + modal-log-sheet
/// flow. One illuminated panel at the bottom of the screen showing a
/// single prayer at a time; tapping a prayer marker on the celestial
/// scene above swaps the focused prayer. Logging happens inline — no
/// modal sheet for the 90 % case.
///
/// Three visual states:
///
/// 1. **Default** — prayer name, an inscription describing window
///    state ("PRAYING WINDOW OPENS IN", "PRAYING NOW · WINDOW ENDS
///    IN", etc.), and the countdown / time. A right-side chevron
///    opens the existing prayer log sheet for the rare edit / qadā /
///    missed flows.
/// 2. **Expanded** — appears on card-body tap. Shows a jamaʿah toggle
///    pill and two timing commit buttons (`On Time`, `Late`). A
///    "More options..." link opens the full log sheet for the long
///    tail (qadā, retroactive missed, edit). A close glyph collapses
///    the card without logging. Auto-collapses after 12 sec of no
///    interaction.
/// 3. **Logged** — once the prayer is logged, the icon switches to a
///    status indicator (brass square with `J` + `✓` / `L` overlay)
///    and the inscription summarises the combined status
///    ("JAMA·AH · ON TIME · 4:18 PM"). The chevron now opens the
///    edit sheet.
///
/// The two-axis logging respects the existing orthogonal storage:
/// jamaʿah is a Bool, timing is a `PrayerStatus`. The card simply
/// exposes them through orthogonal controls (toggle + commit buttons)
/// rather than the previous flat five-option list.
struct FocusedPrayerCard: View {
    /// The focused prayer's rawatib, present only when the user enabled
    /// the sunnah layer's rawatib component. `nil` renders the card
    /// exactly as it was before the layer existed.
    struct RawatibChips: Equatable {
        let beforeCount: Int
        let afterCount: Int
        let beforeLogged: Bool
        let afterLogged: Bool

        var hasAnySlot: Bool { beforeCount > 0 || afterCount > 0 }
    }

    /// The night set offered after Isha, present only when the user
    /// enabled the night component and the night has begun.
    struct NightChips: Equatable {
        let qiyamLogged: Bool
        let witrLogged: Bool
        /// Informational only — the ledger is never mutated from here.
        let witrBridge: WitrNightState
    }

    let prayer: Prayer
    let scheduledTime: Date
    let windowEndTime: Date?
    let currentStatus: PrayerStatus?
    let isJamaah: Bool
    let isInWindow: Bool

    /// Sunnah-layer surfaces; all default off so the five-prayer card
    /// is untouched until the user opts in.
    var rawatib: RawatibChips?
    var nightSet: NightChips?
    var onToggleNafl: ((NaflKind) -> Void)?

    /// Commit a `(timing, jamaʿah)` pair. The parent translates this
    /// into a `setStatus` + `toggleJamaah` pair against the view
    /// model.
    let onCommit: (PrayerStatus, Bool) -> Void

    /// Tap on the chevron, or on "More options..." — opens the full
    /// existing log sheet for edge cases (qadā, retroactive missed,
    /// edit, notes).
    let onMoreOptions: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var mode: Mode = .collapsed
    @State private var jamaahPending: Bool = false
    @State private var autoCollapseTask: Task<Void, Never>?
    @State private var rawatibRevealed: Bool = false

    /// Time the user must be idle in the expanded state before the
    /// card auto-collapses without committing. 12 sec per spec.
    private static let autoCollapseInterval: TimeInterval = 12

    enum Mode { case collapsed, expanded }

    /// Fixed card height — the card never expands upward into the
    /// celestial scene above when transitioning between prayers or
    /// modes. All three states (default / expanded / logged) lay out
    /// within this bound.
    static let cardHeight: CGFloat = 140

    private var isLogged: Bool { currentStatus != nil }

    var body: some View {
        contentForMode
            .padding(14)
            .frame(maxWidth: .infinity)
            .frame(height: Self.cardHeight)
            .celestialPanel(cornerRadius: 20, isActive: isInWindow)
            .padding(.horizontal, IhsanSpacing.md)
            .animation(
                reduceMotion ? nil : .smooth(duration: 0.28),
                value: mode
            )
            .animation(
                reduceMotion ? nil : .smooth(duration: 0.30),
                value: isLogged
            )
            .onChange(of: mode) { _, newMode in
                if newMode == .expanded {
                    jamaahPending = isJamaah
                    scheduleAutoCollapse()
                } else {
                    autoCollapseTask?.cancel()
                    rawatibRevealed = false
                }
            }
            .onChange(of: prayer) { _, _ in
                // Marker tap switches the focused prayer; collapse
                // any in-progress expansion since the controls now
                // reference a different prayer.
                rawatibRevealed = false
                if mode == .expanded {
                    mode = .collapsed
                }
            }
            .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var contentForMode: some View {
        if isLogged {
            loggedContent
                .transition(.opacity)
        } else if mode == .expanded {
            expandedContent
                .transition(.opacity)
        } else {
            defaultContent
                .transition(.opacity)
                .onTapGesture {
                    Haptics.impact(.light)
                    mode = .expanded
                }
        }
    }

    // MARK: - Default state

    @ViewBuilder
    private var defaultContent: some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
            VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
                HStack(spacing: IhsanSpacing.md) {
                    PrayerSymbolBadge(prayer: prayer)
                    prayerNameStack
                    Spacer()
                    chevronButton
                }
                inscriptionAndCountdown
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabelForDefaultState)
            .accessibilityHint("Double-tap to log this prayer.")

            if let nightSet {
                nightRow(nightSet)
            }
        }
    }

    /// Combined VoiceOver label for the default-state card. Reads as
    /// one phrase so the user gets the full prayer status in a single
    /// rotor stop — e.g. "Asr prayer, praying now, window ends in 1
    /// hour 23 minutes. Double-tap to log this prayer."
    private var accessibilityLabelForDefaultState: String {
        var parts: [String] = ["\(prayer.displayNameEnglish) prayer"]

        if isInWindow {
            parts.append("praying now")
        }

        if shouldShowCountdown {
            let remaining = max(0, countdownTarget.timeIntervalSince(.now))
            let direction = isInWindow ? "window ends in" : "starts in"
            parts.append("\(direction) \(spokenCountdown(seconds: remaining))")
        } else if shouldShowScheduledTime {
            parts.append("scheduled at \(scheduledTimeFormatted)")
        } else if let end = windowEndTime, end < .now {
            parts.append("window closed at \(timeFormatted(end))")
        }

        return parts.joined(separator: ", ")
    }

    @ViewBuilder
    private var inscriptionAndCountdown: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(defaultInscription.uppercased())
                .font(IhsanFont.inscription)
                .tracking(1.4)
                .foregroundStyle(IhsanCelestialPalette.current().accent)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if shouldShowCountdown {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = max(0, countdownTarget.timeIntervalSince(context.date))
                    Text(formattedCountdown(seconds: remaining))
                        .font(.system(.title, design: .monospaced).monospacedDigit())
                        .fontWeight(.light)
                        .foregroundStyle(IhsanCelestialPalette.current().text)
                        .contentTransition(.numericText())
                        .accessibilityLabel(spokenCountdown(seconds: remaining))
                }
            } else if shouldShowScheduledTime {
                Text(scheduledTimeFormatted)
                    .font(.system(.title, design: .monospaced).monospacedDigit())
                    .fontWeight(.light)
                    .foregroundStyle(IhsanCelestialPalette.current().text)
            }
        }
    }

    // MARK: - Expanded state

    @ViewBuilder
    private var expandedContent: some View {
        // The expanded state lays out tightly so the prayer name,
        // jamaʿah toggle, and two timing commit buttons all fit
        // within the card's fixed 140pt bound. The "HOW DID YOU
        // PRAY?" inscription and "More options…" link from prior
        // iterations are omitted here — the prayer name and the
        // chevron on the collapsed card already deliver that
        // information / affordance.
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: IhsanSpacing.sm) {
                PrayerSymbolBadge(prayer: prayer)
                prayerNameStack
                Spacer()
                Button {
                    Haptics.impact(.light)
                    mode = .collapsed
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(IhsanCelestialPalette.current().accent.opacity(0.85))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }

            if let rawatib, rawatib.hasAnySlot {
                rawatibStrip(rawatib)
            }

            Spacer(minLength: 0)

            JamaahToggle(isOn: $jamaahPending)
                .frame(maxWidth: .infinity, alignment: .center)
                .onChange(of: jamaahPending) { _, _ in
                    scheduleAutoCollapse()
                }

            HStack(spacing: 8) {
                TimingCommitButton(
                    label: "On Time",
                    glyph: "checkmark",
                    accent: .gold
                ) {
                    commit(.onTime)
                }
                TimingCommitButton(
                    label: "Late",
                    glyph: "L",
                    accent: .brass
                ) {
                    commit(.late)
                }
            }
        }
    }

    // MARK: - Sunnah chips
    //
    // Both rows render only when the parent hands them a model, which it
    // does only after the user turns the layer on. One tap records; a
    // second tap removes. Filled ornament = recorded, outline = not —
    // the same vocabulary as the plate's markers.

    /// One slim row inside the expanded state. Collapsed by default: a
    /// small inscription affordance; revealed: the before/after ornament
    /// chips in place.
    @ViewBuilder
    private func rawatibStrip(_ rawatib: RawatibChips) -> some View {
        HStack(spacing: IhsanSpacing.sm) {
            if rawatibRevealed {
                if rawatib.beforeCount > 0 {
                    naflChip(
                        kind: .rawatibBefore(prayer),
                        ornament: prayer,
                        logged: rawatib.beforeLogged,
                        caption: "\(rawatib.beforeCount) BEFORE"
                    )
                }
                if rawatib.afterCount > 0 {
                    naflChip(
                        kind: .rawatibAfter(prayer),
                        ornament: prayer,
                        logged: rawatib.afterLogged,
                        caption: "\(rawatib.afterCount) AFTER"
                    )
                }
                Spacer(minLength: 0)
            } else {
                Button {
                    Haptics.impact(.light)
                    rawatibRevealed = true
                    scheduleAutoCollapse()
                } label: {
                    HStack(spacing: 5) {
                        Text("RAWATIB")
                            .font(IhsanFont.inscription)
                            .tracking(1.6)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .semibold))
                    }
                    .foregroundStyle(IhsanCelestialPalette.current().accent.opacity(0.60))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Rawatib")
                .accessibilityHint("Shows the before and after chips.")
                Spacer(minLength: 0)
            }
        }
        .frame(height: 20)
    }

    @ViewBuilder
    private func nightRow(_ nightSet: NightChips) -> some View {
        HStack(spacing: IhsanSpacing.sm) {
            naflChip(
                kind: .qiyam,
                ornament: .isha,
                logged: nightSet.qiyamLogged,
                caption: "QIYAM"
            )
            naflChip(
                kind: .witr,
                ornament: .maghrib,
                logged: nightSet.witrLogged,
                caption: "WITR"
            )
            if nightSet.witrBridge == .current {
                Text("TONIGHT'S WITR · CURRENT")
                    .font(IhsanFont.inscription)
                    .tracking(1.2)
                    .foregroundStyle(IhsanCelestialPalette.current().text.opacity(0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .frame(height: 20)
    }

    @ViewBuilder
    private func naflChip(
        kind: NaflKind,
        ornament: Prayer,
        logged: Bool,
        caption: String
    ) -> some View {
        Button {
            Haptics.impact(.soft)
            onToggleNafl?(kind)
        } label: {
            HStack(spacing: 5) {
                ZStack {
                    if logged {
                        PrayerOrnamentShape(prayer: ornament, mode: .filled)
                            .fill(
                                IhsanCelestialPalette.current().accent,
                                style: FillStyle(eoFill: true)
                            )
                    } else {
                        PrayerOrnamentShape(prayer: ornament, mode: .outline)
                            .stroke(
                                IhsanCelestialPalette.current().accent.opacity(0.55),
                                lineWidth: 0.9
                            )
                    }
                }
                .frame(width: 14, height: 14)

                Text(caption)
                    .font(IhsanFont.inscription)
                    .tracking(1.2)
                    .foregroundStyle(
                        IhsanCelestialPalette.current().accent.opacity(logged ? 0.95 : 0.65)
                    )
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .overlay {
                Capsule()
                    .strokeBorder(
                        IhsanCelestialPalette.current().accent.opacity(logged ? 0.55 : 0.30),
                        lineWidth: 0.8
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(kind.displayNameEnglish)
        .accessibilityValue(logged ? "recorded" : "not recorded")
        .accessibilityHint("Double-tap to \(logged ? "remove" : "record").")
    }

    // MARK: - Logged state

    @ViewBuilder
    private var loggedContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: IhsanSpacing.md) {
                LoggedStatusIndicator(
                    status: currentStatus ?? .missed,
                    isJamaah: isJamaah
                )
                VStack(alignment: .leading, spacing: 4) {
                    prayerNameRow
                    Text(loggedInscription.uppercased())
                        .font(IhsanFont.inscription)
                        .tracking(1.4)
                        .foregroundStyle(IhsanCelestialPalette.current().accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer()
                chevronButton
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabelForLoggedState)

            if let nightSet {
                nightRow(nightSet)
            }
        }
    }

    private var accessibilityLabelForLoggedState: String {
        var parts: [String] = []
        parts.append("\(prayer.displayNameEnglish) prayer")
        parts.append("logged")
        if isJamaah {
            parts.append("in jamaʿah")
        }
        if let status = currentStatus {
            parts.append(status.spokenLabel)
        }
        parts.append("Double-tap to edit")
        return parts.joined(separator: ", ")
    }

    // MARK: - Shared subviews

    @ViewBuilder
    private var prayerNameStack: some View {
        VStack(alignment: .leading, spacing: 2) {
            prayerNameRow
        }
    }

    @ViewBuilder
    private var prayerNameRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: IhsanSpacing.sm) {
            Text(prayer.displayNameEnglish)
                .font(IhsanFont.heroPrayerName)
                .foregroundStyle(IhsanCelestialPalette.current().text)
            Text(prayer.displayNameArabic)
                .font(IhsanFont.bodyArabic)
                .foregroundStyle(IhsanCelestialPalette.current().text.opacity(0.72))
        }
    }

    @ViewBuilder
    private var chevronButton: some View {
        Button {
            Haptics.impact(.light)
            onMoreOptions()
        } label: {
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(IhsanCelestialPalette.current().accent.opacity(0.65))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open prayer log options")
    }

    // MARK: - State transitions

    private func commit(_ status: PrayerStatus) {
        Haptics.success()
        let jamaah = jamaahPending
        onCommit(status, jamaah)
        mode = .collapsed
    }

    private func scheduleAutoCollapse() {
        autoCollapseTask?.cancel()
        autoCollapseTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(Self.autoCollapseInterval * 1_000_000_000))
            if !Task.isCancelled && mode == .expanded {
                mode = .collapsed
            }
        }
    }

    // MARK: - Inscription strings

    private var defaultInscription: String {
        if isInWindow {
            if windowEndTime != nil {
                return "Praying now · window ends in"
            }
            return "Praying now"
        }
        if scheduledTime > .now {
            return "Praying window opens in"
        }
        if let end = windowEndTime, end < .now {
            return "Missed · window closed \(timeFormatted(end))"
        }
        return "Scheduled at"
    }

    private var loggedInscription: String {
        guard let status = currentStatus else { return "" }
        let jamaahPrefix = isJamaah ? "JAMA·AH · " : ""
        switch status {
        case .onTime:
            return "\(jamaahPrefix)ON TIME · \(timeFormatted(.now))"
        case .late:
            return "\(jamaahPrefix)LATE · \(timeFormatted(.now))"
        case .qada:
            return "QADĀ · LOGGED \(dateFormatted(.now))"
        case .missed:
            return "MISSED · WINDOW CLOSED \(timeFormatted(windowEndTime ?? scheduledTime))"
        }
    }

    private var shouldShowCountdown: Bool {
        // Show a countdown when the user is waiting for an event:
        // either the prayer's window to open, or the window's end
        // if currently in it.
        if isInWindow, windowEndTime != nil { return true }
        if scheduledTime > .now { return true }
        return false
    }

    private var shouldShowScheduledTime: Bool {
        // No countdown to show, and the prayer hasn't opened yet.
        scheduledTime > .now && !shouldShowCountdown
    }

    private var countdownTarget: Date {
        if isInWindow, let end = windowEndTime {
            return end
        }
        return scheduledTime
    }

    // MARK: - Formatting helpers

    private var scheduledTimeFormatted: String {
        timeFormatted(scheduledTime)
    }

    private func timeFormatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func dateFormatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date).uppercased()
    }

    private func formattedCountdown(seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%d:%02d:%02d", h, m, s)
    }

    private func spokenCountdown(seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        var parts: [String] = []
        if h > 0 { parts.append("\(h) hour\(h == 1 ? "" : "s")") }
        if m > 0 { parts.append("\(m) minute\(m == 1 ? "" : "s")") }
        if h == 0 { parts.append("\(s) second\(s == 1 ? "" : "s")") }
        return parts.isEmpty ? "0 seconds" : parts.joined(separator: ", ")
    }
}

// MARK: - Prayer symbol badge (left side of card)

/// A small SF Symbol badge for the prayer — sunrise, zenith, sunset
/// glyph at 28pt, brass tint at 80% opacity. Reads as the unlogged
/// state on the card's left side.
private struct PrayerSymbolBadge: View {
    let prayer: Prayer

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: 22, weight: .regular))
            .foregroundStyle(IhsanCelestialPalette.current().accent.opacity(0.85))
            .frame(width: 36, height: 36)
            .accessibilityHidden(true)
    }

    private var symbolName: String {
        switch prayer {
        case .fajr: return "sunrise.fill"
        case .dhuhr: return "sun.max.fill"
        case .asr: return "sun.haze.fill"
        case .maghrib: return "sunset.fill"
        case .isha: return "moon.stars.fill"
        }
    }
}

// MARK: - Logged status indicator

/// A small brass-filled square containing the status glyph(s).
/// `J + ✓` for jamaʿah on-time, `J + L` for jamaʿah late, plain `✓`
/// or `L` for individual, `Q` for qadā, `—` for missed.
private struct LoggedStatusIndicator: View {
    let status: PrayerStatus
    let isJamaah: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        ZStack {
            shape.fill(IhsanIridescence.brassStroke(opacity: 0.95))
            shape.strokeBorder(
                IhsanIridescence.brassStroke(opacity: 0.95),
                lineWidth: 0.8
            )
            glyphStack
                .foregroundStyle(IhsanColor.inkDeep)
        }
        .frame(width: 36, height: 36)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var glyphStack: some View {
        if isJamaah {
            HStack(spacing: 1) {
                Text("J")
                    .font(.system(size: 13, weight: .bold, design: .serif))
                timingGlyph(size: 11)
            }
        } else {
            timingGlyph(size: 14)
        }
    }

    @ViewBuilder
    private func timingGlyph(size: CGFloat) -> some View {
        switch status {
        case .onTime:
            Image(systemName: "checkmark")
                .font(.system(size: size, weight: .bold))
        case .late:
            Text("L")
                .font(.system(size: size + 1, weight: .bold, design: .serif))
        case .qada:
            Text("Q")
                .font(.system(size: size + 1, weight: .bold, design: .serif))
        case .missed:
            Image(systemName: "minus")
                .font(.system(size: size + 2, weight: .bold))
        }
    }
}

// MARK: - Jamaʿah toggle pill

/// A horizontal pill that toggles jamaʿah. Off state outlines the
/// pill in brass at 50% opacity; on state fills with the iridescent
/// brass angular gradient. State changes carry a soft haptic.
private struct JamaahToggle: View {
    @Binding var isOn: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            Haptics.impact(.light)
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.18)) {
                isOn.toggle()
            }
        } label: {
            Text("JAMA·AH")
                .font(IhsanFont.inscription)
                .tracking(2.0)
                .foregroundStyle(labelColor)
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
                .frame(minWidth: 110)
                .background {
                    Capsule()
                        .fill(filling)
                        .opacity(isOn ? 1 : 0)
                }
                .overlay {
                    Capsule()
                        .strokeBorder(
                            isOn
                                ? IhsanCelestialPalette.current().accent.opacity(0.95)
                                : IhsanCelestialPalette.current().accent.opacity(0.55),
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Jamaʿah toggle")
        .accessibilityValue(isOn ? "on" : "off")
        .accessibilityHint("Double-tap to toggle jamaʿah selection.")
    }

    private var labelColor: Color {
        isOn
            ? IhsanColor.inkDeep
            : IhsanCelestialPalette.current().accent
    }

    private var filling: some ShapeStyle {
        IhsanIridescence.brassStroke(opacity: 0.92)
    }
}

// MARK: - Timing commit button

/// One of the two pill buttons in the expanded state. Tap → fill
/// animation → call `action`. The two buttons are visually balanced;
/// On Time uses the gold accent and Late uses brass.
private struct TimingCommitButton: View {
    enum Accent { case gold, brass }

    let label: String
    let glyph: String
    let accent: Accent
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressing: Bool = false

    var body: some View {
        Button {
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.15)) {
                isPressing = true
            }
            // Slight delay so the fill animation is visible before
            // the card transitions to the logged state.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                action()
            }
        } label: {
            HStack(spacing: 8) {
                if glyph == "checkmark" {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                } else {
                    Text(glyph)
                        .font(.system(size: 14, weight: .bold, design: .serif))
                }
                Text(label.uppercased())
                    .font(IhsanFont.inscription)
                    .tracking(1.8)
            }
            .foregroundStyle(foregroundColor)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background {
                Capsule()
                    .fill(filling)
                    .opacity(isPressing ? 1 : 0)
            }
            .overlay {
                Capsule()
                    .strokeBorder(borderColor, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log as \(label)")
        .accessibilityHint("Double-tap to log as \(label.lowercased()).")
    }

    private var borderColor: Color {
        switch accent {
        case .gold:
            return IhsanCelestialPalette.current().accentBright.opacity(0.95)
        case .brass:
            return IhsanCelestialPalette.current().accent.opacity(0.75)
        }
    }

    private var foregroundColor: Color {
        if isPressing { return IhsanColor.inkDeep }
        return IhsanCelestialPalette.current().text
    }

    private var filling: some ShapeStyle {
        IhsanIridescence.brassStroke(opacity: 0.92)
    }
}

// MARK: - PrayerStatus spoken label

private extension PrayerStatus {
    var spokenLabel: String {
        switch self {
        case .onTime: return "on time"
        case .late: return "late"
        case .qada: return "as qadā"
        case .missed: return "missed"
        }
    }
}
