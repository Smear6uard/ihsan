import IhsanCore
import IhsanDesignSystem
import IhsanPrayerTimes
import SwiftUI

/// The focused-prayer card on the celestial Today screen — an
/// illuminated v2 panel that shares the plate's ornament language.
///
/// One panel at the bottom of the screen showing a single prayer at a
/// time; tapping a prayer marker on the celestial scene above swaps
/// the focused prayer. Logging happens inline — no modal sheet for
/// the 90% case.
///
/// State hierarchy (per the corrective spec):
///
/// 1. **Upcoming** — the prayer's *time* is the primary numeral; the
///    countdown ticks quietly as an inscription ("OPENS IN · 2:14:09").
/// 2. **Active** — the prayer *name* (Latin + Arabic pair) is primary;
///    the window is described in small caps inkSecondary
///    ("NOW · UNTIL 6:15 AM"). No giant ticking numerals.
/// 3. **Expanded** — on card tap: jamaʿah toggle, two timing commits,
///    a quiet MORE OPTIONS link for the long tail (qadā, missed, edit).
/// 4. **Logged** — the prayer's ornament renders in its logged state
///    and the inscription summarises ("JAMĀ'AH · ON TIME · 4:18 PM").
///    Tapping the card opens the edit sheet.
///
/// Copy rule: the card describes the *window*, never the user's act —
/// "NOW", not "PRAYING NOW".
///
/// The card owns no clock: the screen's single timeline hands it the
/// resolved `now`, and every derived state comes from
/// `FocusedCardModel`, whose tests pin the no-resting-zero and
/// atomic-boundary guarantees.
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
        /// Present only during Ramadan: tarāwīḥ joins the night set.
        var tarawihLogged: Bool? = nil
    }

    let prayer: Prayer
    let scheduledTime: Date
    let windowEndTime: Date?
    /// The resolved moment from the screen's single clock.
    let now: Date
    /// Timezone of the place, for every formatted time on the card.
    let timeZone: TimeZone
    /// Resolved v2 palette tokens for this moment.
    let tokens: SkyPaletteTokens
    let currentStatus: PrayerStatus?
    /// When the existing log was recorded — shown in the logged
    /// inscription instead of ever reading a clock.
    let loggedAt: Date?
    let isJamaah: Bool
    /// The exact temporal state from the shared resolver. The card
    /// performs no independent boundary comparisons.
    let windowState: PrayerWindowState

    /// Sunnah-layer surfaces; all default off so the five-prayer card
    /// is untouched until the user opts in.
    var rawatib: RawatibChips?
    var nightSet: NightChips?
    var onToggleNafl: ((NaflKind) -> Void)?

    /// Commit a `(timing, jamaʿah)` pair. The parent translates this
    /// into a `setStatus` + `toggleJamaah` pair against the view
    /// model.
    let onCommit: (PrayerStatus, Bool) -> Void

    /// Opens the full log sheet for edge cases (qadā, retroactive
    /// missed, edit, notes) — reached from the logged card's tap and
    /// the expanded state's MORE OPTIONS link.
    let onMoreOptions: () -> Void

    /// Opens the tasbīḥ instrument — the logged card's quiet link,
    /// the natural post-prayer moment. `nil` renders no link.
    var onTasbih: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var mode: Mode = DebugLaunch.flag("-IhsanDebugExpandCard")
        ? .expanded : .collapsed
    @State private var jamaahPending: Bool = false
    @State private var autoCollapseTask: Task<Void, Never>?
    @State private var rawatibRevealed: Bool = false

    /// Time the user must be idle in the expanded state before the
    /// card auto-collapses without committing. 12 sec per spec.
    private static let autoCollapseInterval: TimeInterval = 12

    enum Mode { case collapsed, expanded }

    /// Fixed card height — the card never expands upward into the
    /// celestial scene above when transitioning between prayers or
    /// modes. All states lay out within this bound.
    static let cardHeight: CGFloat = 140

    private var isLogged: Bool { currentStatus != nil }

    private var phase: FocusedCardModel.Phase {
        FocusedCardModel.resolve(
            windowState: windowState,
            isLogged: isLogged
        )
    }

    private var isInWindow: Bool { windowState.isCurrent }

    private var inscription: String {
        FocusedCardModel.inscription(
            for: phase,
            status: currentStatus,
            loggedAt: loggedAt,
            isJamaah: isJamaah,
            windowEndTime: windowEndTime,
            scheduledTime: scheduledTime,
            now: now,
            timeZone: timeZone,
            windowEndDescriptor: PrayerWindowRule.windowEndDescriptor(for: prayer)
        )
    }

    var body: some View {
        contentForMode
            .padding(14)
            .frame(maxWidth: .infinity)
            .frame(height: Self.cardHeight)
            .celestialPanel(tokens: tokens, cornerRadius: 20, isActive: isInWindow)
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

    private var isWindowClosed: Bool {
        if case .windowClosed = phase { return true }
        return false
    }

    @ViewBuilder
    private var contentForMode: some View {
        if isLogged {
            loggedContent
                .transition(.opacity)
                .onTapGesture {
                    Haptics.impact(.light)
                    onMoreOptions()
                }
        } else if isWindowClosed {
            // A passed, unlogged prayer goes straight to the sheet —
            // the expanded quick buttons speak the open window's
            // language (On Time), which can no longer be true here.
            // The sheet's tiles carry the temporal-availability rule.
            defaultContent
                .transition(.opacity)
                .onTapGesture {
                    Haptics.impact(.light)
                    onMoreOptions()
                }
        } else if mode == .expanded, FocusedCardModel.allowsLogging(phase) {
            expandedContent
                .transition(.opacity)
        } else if FocusedCardModel.allowsLogging(phase) {
            defaultContent
                .transition(.opacity)
                .onTapGesture {
                    Haptics.impact(.light)
                    mode = .expanded
                }
        } else {
            // Pre-window: the upcoming state replaces commit controls
            // entirely — no expansion, no sheet, nothing to press.
            defaultContent
                .transition(.opacity)
        }
    }

    // MARK: - Ornament (shared plate language)

    /// The prayer's own ornament, in the same lifecycle state the
    /// plate's marker shows — the card and the plate visibly share
    /// one language.
    private var ornamentState: PrayerMarkerState {
        switch phase {
        case .logged: return .logged
        case .active: return .current
        case .upcoming: return .upcoming
        case .windowClosed: return .passedUnlogged
        }
    }

    private var ornament: some View {
        PrayerMarkerOrnament(
            prayer: prayer,
            size: 30,
            state: ornamentState,
            tokens: tokens
        )
        .frame(width: 38, height: 38)
        .accessibilityHidden(true)
    }

    // MARK: - Default (collapsed) state

    @ViewBuilder
    private var defaultContent: some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
            VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
                HStack(spacing: IhsanSpacing.md) {
                    ornament
                    prayerNameRow
                    Spacer()
                }
                phaseDetail
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabelForDefaultState)
            .accessibilityHint("Double-tap to log this prayer.")

            if let nightSet {
                nightRow(nightSet)
            }
        }
    }

    /// The card's second line, per the state hierarchy: upcoming keeps
    /// the prayer time as the primary numeral with the countdown as an
    /// inscription; the active window is described in small caps only.
    @ViewBuilder
    private var phaseDetail: some View {
        switch phase {
        case .upcoming:
            VStack(alignment: .leading, spacing: 4) {
                Text(PlateTimeFormat.time(scheduledTime, in: timeZone))
                    .font(.system(.title, design: .monospaced).monospacedDigit())
                    .fontWeight(.light)
                    .foregroundStyle(tokens.ink)
                    .contentTransition(.numericText())
                    .inkKeyline(tokens)
                Text(inscription.uppercased())
                    .font(IhsanFont.inscription)
                    .monospacedDigit()
                    .tracking(1.4)
                    .foregroundStyle(tokens.inkSecondary)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .inkKeyline(tokens)
            }
        case .windowClosed:
            // The passed prayer still asks to be recorded: the
            // inscription states the fact, and a gilded LOG chip
            // makes the affordance unmistakable — the card is a way
            // in, not a status plaque.
            HStack(spacing: IhsanSpacing.sm) {
                Text(inscription.uppercased())
                    .font(IhsanFont.inscription)
                    .tracking(1.4)
                    .foregroundStyle(tokens.inkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .inkKeyline(tokens)
                Text("LOG")
                    .font(IhsanFont.inscription)
                    .tracking(1.8)
                    .foregroundStyle(tokens.keyline)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background { Capsule().fill(tokens.leafGold) }
                    .overlay {
                        Capsule().strokeBorder(
                            tokens.keyline.opacity(0.55), lineWidth: 0.8
                        )
                    }
            }
        case .active, .logged:
            Text(inscription.uppercased())
                .font(IhsanFont.inscription)
                .tracking(1.4)
                .foregroundStyle(tokens.inkSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .inkKeyline(tokens)
        }
    }

    /// Combined VoiceOver label for the default-state card, phrased by
    /// the same copy rule the visual inscription follows.
    private var accessibilityLabelForDefaultState: String {
        var parts: [String] = ["\(prayer.displayNameEnglish) prayer"]
        switch phase {
        case .active(let until):
            if let descriptor = PrayerWindowRule.windowEndDescriptor(for: prayer) {
                parts.append("in its window until \(descriptor) at \(PlateTimeFormat.time(until, in: timeZone))")
            } else {
                parts.append("in its window until \(PlateTimeFormat.time(until, in: timeZone))")
            }
        case .upcoming(let opensAt):
            parts.append("opens in \(FocusedCardModel.spokenCountdown(until: opensAt, now: now))")
            parts.append("scheduled at \(PlateTimeFormat.time(scheduledTime, in: timeZone))")
        case .windowClosed(let end):
            if let end {
                parts.append("window closed at \(PlateTimeFormat.time(end, in: timeZone))")
            } else {
                parts.append("window closed")
            }
        case .logged:
            break
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Expanded state

    /// Expanded, tightened: name row, jamāʿah toggle, the two commit
    /// buttons, then a slim footer — rawatib leading, MORE OPTIONS
    /// trailing. Every region exactly as tall as its content; no
    /// floating elements, no dead middle.
    @ViewBuilder
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: IhsanSpacing.sm) {
                ornament
                prayerNameRow
                Spacer()
                Button {
                    Haptics.impact(.light)
                    mode = .collapsed
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(tokens.metal.opacity(0.85))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }

            JamaahToggleControl(isOn: $jamaahPending, tokens: tokens)
                .frame(maxWidth: .infinity, alignment: .center)
                .onChange(of: jamaahPending) { _, _ in
                    scheduleAutoCollapse()
                }

            HStack(spacing: 8) {
                TimingCommitButton(
                    label: "On Time",
                    prominent: true,
                    tokens: tokens
                ) {
                    commit(.onTime)
                }
                TimingCommitButton(
                    label: "Late",
                    prominent: false,
                    tokens: tokens
                ) {
                    commit(.late)
                }
            }

            HStack(spacing: IhsanSpacing.sm) {
                if let rawatib, rawatib.hasAnySlot {
                    rawatibStrip(rawatib)
                }
                Spacer(minLength: 0)
                Button {
                    Haptics.impact(.light)
                    onMoreOptions()
                } label: {
                    Text("MORE OPTIONS")
                        .font(IhsanFont.inscription)
                        .tracking(1.6)
                        .foregroundStyle(tokens.metal.opacity(0.60))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("More options")
                .accessibilityHint("Opens the full prayer log sheet.")
            }
            .frame(height: 18)
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
                    .foregroundStyle(tokens.metal.opacity(0.60))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Rawatib")
                .accessibilityHint("Shows the before and after chips.")
            }
        }
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
            if let tarawihLogged = nightSet.tarawihLogged {
                naflChip(
                    kind: .tarawih,
                    ornament: .isha,
                    logged: tarawihLogged,
                    caption: "TARĀWĪḤ"
                )
            }
            if nightSet.witrBridge == .current {
                Text("TONIGHT'S WITR · CURRENT")
                    .font(IhsanFont.inscription)
                    .tracking(1.2)
                    .foregroundStyle(tokens.inkSecondary.opacity(0.75))
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
            Haptics.settle()
            onToggleNafl?(kind)
        } label: {
            HStack(spacing: 5) {
                ZStack {
                    if logged {
                        // Recorded = the gilded body, same unit the
                        // plate's logged markers use, at chip scale.
                        GildedOrnamentGlyph(prayer: ornament, size: 14, tokens: tokens)
                    } else {
                        PrayerOrnamentShape(prayer: ornament, mode: .outline)
                            .stroke(
                                tokens.metal.opacity(0.55),
                                lineWidth: 0.9
                            )
                    }
                }
                .frame(width: 14, height: 14)

                Text(caption)
                    .font(IhsanFont.inscription)
                    .tracking(1.2)
                    .foregroundStyle(
                        tokens.metal.opacity(logged ? 0.95 : 0.65)
                    )
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .overlay {
                Capsule()
                    .strokeBorder(
                        tokens.metal.opacity(logged ? 0.55 : 0.30),
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
                HStack(spacing: IhsanSpacing.md) {
                    ornament
                    VStack(alignment: .leading, spacing: 4) {
                        prayerNameRow
                        Text(inscription.uppercased())
                            .font(IhsanFont.inscription)
                            .tracking(1.4)
                            .foregroundStyle(tokens.inkSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .inkKeyline(tokens)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(accessibilityLabelForLoggedState)
                .accessibilityHint("Double-tap to edit.")

                Spacer()

                if let onTasbih {
                    Button {
                        Haptics.impact(.light)
                        onTasbih()
                    } label: {
                        Text("TASBĪḤ")
                            .font(IhsanFont.inscription)
                            .tracking(1.6)
                            .foregroundStyle(tokens.metal.opacity(0.70))
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Tasbīḥ")
                    .accessibilityHint("Opens the tasbīḥ counter.")
                }
            }

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
            parts.append("in \(IhsanVocabulary.jamaah)")
        }
        if let status = currentStatus {
            parts.append(status.spokenLabel)
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Shared subviews

    @ViewBuilder
    private var prayerNameRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: IhsanSpacing.sm) {
            Text(prayer.displayNameEnglish)
                .font(IhsanFont.heroPrayerName)
                .foregroundStyle(tokens.ink)
            Text(prayer.displayNameArabic)
                .font(IhsanFont.bodyArabic)
                .foregroundStyle(tokens.ink.opacity(0.72))
        }
        .inkKeyline(tokens)
    }

    // MARK: - State transitions

    private func commit(_ status: PrayerStatus) {
        Haptics.settle()
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
}

// MARK: - Jamaʿah toggle pill

/// A horizontal pill that toggles jamaʿah. Off state outlines the
/// pill in metal; on state fills flat metal with deep ink text —
/// flat + luminous, no iridescence, no depth.
private struct JamaahToggleControl: View {
    @Binding var isOn: Bool
    let tokens: SkyPaletteTokens

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            Haptics.impact(.light)
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.18)) {
                isOn.toggle()
            }
        } label: {
            Text(IhsanVocabulary.jamaahInscription)
                .font(IhsanFont.inscription)
                .tracking(2.0)
                .foregroundStyle(isOn ? tokens.panelFill : tokens.metal)
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
                .frame(minWidth: 110)
                .background {
                    Capsule()
                        .fill(tokens.metal)
                        .opacity(isOn ? 1 : 0)
                }
                .overlay {
                    Capsule()
                        .strokeBorder(
                            tokens.metal.opacity(isOn ? 0.95 : 0.55),
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(IhsanVocabulary.jamaahTitle) toggle")
        .accessibilityValue(isOn ? "on" : "off")
        .accessibilityHint("Double-tap to toggle \(IhsanVocabulary.jamaah) selection.")
    }
}

// MARK: - Timing commit button

/// One of the two pill buttons in the expanded state — labels only,
/// no glyphs, in the panel language. On the press, On Time takes the
/// primary gilded fill (leaf bounded by keyline ink); Late fills in
/// base metal. The fill plays just ahead of the logged transition,
/// synchronized with the ornament's materialize pour.
private struct TimingCommitButton: View {
    let label: String
    let prominent: Bool
    let tokens: SkyPaletteTokens
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
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 120_000_000)
                action()
            }
        } label: {
            Text(label.uppercased())
                .font(IhsanFont.inscription)
                .tracking(1.8)
                .foregroundStyle(pressedForeground)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity)
                .background {
                    Capsule()
                        .fill(prominent ? AnyShapeStyle(tokens.leafGold) : AnyShapeStyle(tokens.metal))
                        .opacity(isPressing ? 1 : 0)
                }
                .overlay {
                    Capsule()
                        .strokeBorder(
                            prominent
                                ? tokens.metalHighlight.opacity(0.95)
                                : tokens.metal.opacity(0.75),
                            lineWidth: prominent ? 1.1 : 1
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log as \(label)")
        .accessibilityHint("Double-tap to log as \(label.lowercased()).")
    }

    private var pressedForeground: Color {
        guard isPressing else { return tokens.ink }
        return prominent ? tokens.keyline : tokens.panelFill
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
