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
/// 3. **Expanded** — on card tap: the window line, two timing commits
///    (On Time and Delayed, both in-window states), the jamāʿah chip,
///    and the ways onward. Swiping the card up opens the full log sheet
///    for the long tail (qadā, missed, edit); swiping down closes it.
///    The grabber at the top is what says the card can be dragged, and
///    the MORE link is the same door for anyone who does not swipe.
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

    /// Mirrors the parent's sheet selection so the source card can
    /// hold its upward momentum until the destination has arrived,
    /// then return to rest only after the sheet is dismissed.
    var isMoreOptionsPresented: Bool = false

    /// Opens the tasbīḥ instrument — the logged card's quiet link,
    /// the natural post-prayer moment. `nil` renders no link.
    var onTasbih: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var mode: Mode = DebugLaunch.flag("-IhsanDebugExpandCard")
        ? .expanded : .collapsed
    @State private var jamaahPending: Bool = false
    @State private var autoCollapseTask: Task<Void, Never>?
    @State private var rawatibRevealed: Bool = false
    /// Live vertical translation of the expanded card's drag, in
    /// points. Negative is upward, toward the sheet.
    @State private var dragOffset: CGFloat = 0
    /// True after an upward commit and until the sheet is dismissed.
    /// This prevents the source card from bouncing back down before
    /// the native presentation begins its own upward travel.
    @State private var isHandingOffToSheet = false

    /// Time the user must be idle in the expanded state before the
    /// card auto-collapses without committing. 12 sec per spec.
    private static let autoCollapseInterval: TimeInterval = 12

    enum Mode { case collapsed, expanded }

    /// The card's resting height, and the one the celestial composition
    /// above is measured against. Every non-expanded state lays out
    /// within this bound, so switching prayers never moves the card.
    static let cardHeight: CGFloat = 140

    /// The expanded height. Taller than the resting card on purpose:
    /// the growth is a direct answer to a tap, animated, and it is what
    /// buys the commit buttons and the jamāʿah chip room to be read.
    /// The scene above is still laid out against `cardHeight`, so it
    /// does not reflow when the card opens — the card simply covers a
    /// little more sky while it is open.
    ///
    /// Sized to the content and no further. The point of the rebuild
    /// was that the old expanded state was crowded; answering that with
    /// a card of slack would only have moved the problem, and a void
    /// above a lone trailing link reads as an unfinished layout.
    static let expandedCardHeight: CGFloat = 176

    /// How far the card must travel before the gesture commits. Short
    /// enough to feel willing, long enough that a wobble during a tap
    /// on ON TIME is not read as a swipe.
    private static let swipeThreshold: CGFloat = 40

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

    /// True when the expanded controls are the ones on screen. Drives
    /// the height, the grabber, and whether the swipe is listening.
    private var isExpandedLayout: Bool {
        !isLogged
            && !isWindowClosed
            && mode == .expanded
            && FocusedCardModel.allowsLogging(phase)
    }

    var body: some View {
        contentForMode
            .padding(14)
            .frame(maxWidth: .infinity)
            .frame(height: isExpandedLayout ? Self.expandedCardHeight : Self.cardHeight)
            .celestialPanel(tokens: tokens, cornerRadius: 20, isActive: isInWindow)
            .padding(.horizontal, IhsanSpacing.md)
            // The card follows the finger a little on the way to its
            // destination, so the sheet does not arrive out of nowhere.
            .offset(y: reduceMotion ? 0 : dragOffset)
            .opacity(dragFade)
            .scaleEffect(
                isHandingOffToSheet && !reduceMotion ? 0.985 : 1,
                anchor: .bottom
            )
            .gesture(expandGesture, isEnabled: isExpandedLayout)
            .animation(
                reduceMotion ? nil : .smooth(duration: 0.28),
                value: mode
            )
            .animation(
                reduceMotion ? nil : .smooth(duration: 0.30),
                value: isLogged
            )
            .onChange(of: mode) { _, newMode in
                dragOffset = 0
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
                dragOffset = 0
                if mode == .expanded {
                    mode = .collapsed
                }
            }
            .onChange(of: isMoreOptionsPresented) { _, isPresented in
                if isPresented {
                    autoCollapseTask?.cancel()
                } else if isHandingOffToSheet {
                    // Return to the expanded source after the native
                    // sheet has completed its downward dismissal.
                    // The reverse transition therefore ends where the
                    // forward transition began, without a hidden reset.
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.24)) {
                        dragOffset = 0
                        isHandingOffToSheet = false
                    }
                    scheduleAutoCollapse()
                }
            }
            .accessibilityElement(children: .contain)
            // Nobody using VoiceOver or Switch Control can swipe this
            // card, so both destinations are actions as well. The
            // visible MORE link is the third way in.
            .accessibilityAction(named: "More options") { presentMoreOptions() }
            .accessibilityAction(named: "Collapse") { mode = .collapsed }
    }

    // MARK: - The swipe

    /// One vertical axis, two destinations: up opens the full log
    /// sheet, down closes the card. The grabber at the top of the
    /// expanded state is what says so.
    ///
    /// Threshold-based with a continuous handoff: the card tracks the
    /// finger, preserves that upward momentum across the release, and
    /// lets the native sheet finish the same movement from below.
    private var expandGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard !isHandingOffToSheet else { return }
                // Damped, so the card reads as resisting rather than
                // sliding away, and the finger never outruns it.
                dragOffset = value.translation.height * 0.45
                // A slow, deliberate drag must not be interrupted by
                // the idle timer firing underneath it.
                scheduleAutoCollapse()
            }
            .onEnded { value in
                let travel = value.translation.height
                if travel <= -Self.swipeThreshold {
                    Haptics.impact(.light)
                    presentMoreOptions()
                } else if travel >= Self.swipeThreshold {
                    Haptics.impact(.light)
                    mode = .collapsed
                } else {
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.20)) {
                        dragOffset = 0
                    }
                }
            }
    }

    /// Carries the card farther in the direction of the committed
    /// gesture instead of snapping it back to zero before presentation.
    /// The offset is deliberately bounded: enough to connect the two
    /// surfaces, never enough to make the source disappear.
    private func presentMoreOptions() {
        autoCollapseTask?.cancel()
        if isExpandedLayout, !reduceMotion {
            withAnimation(.smooth(duration: 0.18)) {
                isHandingOffToSheet = true
                dragOffset = max(-88, min(-56, dragOffset - 18))
            }
        }
        onMoreOptions()
    }

    /// The card dims slightly as it travels — the visual half of "this
    /// is on its way somewhere", and it caps well short of invisible.
    private var dragFade: Double {
        guard !reduceMotion, dragOffset != 0 else { return 1 }
        let progress = min(1, abs(dragOffset) / Self.swipeThreshold)
        return 1 - 0.15 * progress
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
                    presentMoreOptions()
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
                    presentMoreOptions()
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
                    .inkKeyline(tokens)
                    // Position here is cosmetic: `contentTransition` is
                    // an environment value, so it reaches both of the
                    // keyline's copies of the glyph either side of the
                    // modifier. Kept next to it only so the two numeric
                    // fields below read the same way.
                    .contentTransition(.numericText())
                Text(inscription.uppercased())
                    .font(IhsanFont.inscription)
                    .monospacedDigit()
                    .tracking(1.4)
                    .foregroundStyle(tokens.inkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .inkKeyline(tokens)
                    .contentTransition(.numericText())
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

    /// Expanded, rebuilt to breathe.
    ///
    /// Reading order top to bottom: what prayer and until when, the two
    /// commits, the one modifier, then the ways onward. Each band does
    /// one job and is left-aligned to the same rule, which the previous
    /// version's centred jamāʿah pill broke for no reason.
    ///
    /// The window line is the piece that was missing: On Time versus
    /// Delayed is only a real choice if you can see how much window is
    /// left.
    @ViewBuilder
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            grabber
                .padding(.bottom, 6)

            HStack(alignment: .top, spacing: IhsanSpacing.sm) {
                ornament
                VStack(alignment: .leading, spacing: 2) {
                    prayerNameRow
                    Text(inscription.uppercased())
                        .font(IhsanFont.inscription)
                        .tracking(1.4)
                        .monospacedDigit()
                        .foregroundStyle(tokens.inkSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .inkKeyline(tokens)
                }
                Spacer(minLength: 0)
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

            Spacer(minLength: IhsanSpacing.xxs)

            HStack(spacing: IhsanSpacing.sm) {
                TimingCommitButton(
                    label: PrayerStatus.onTime.displayName,
                    prominent: true,
                    tokens: tokens
                ) {
                    commit(.onTime)
                }
                TimingCommitButton(
                    label: PrayerStatus.late.displayName,
                    prominent: false,
                    tokens: tokens
                ) {
                    commit(.late)
                }
            }

            JamaahChip(isOn: $jamaahPending, tokens: tokens)
                .padding(.top, IhsanSpacing.xs + 2)
                .onChange(of: jamaahPending) { _, _ in
                    scheduleAutoCollapse()
                }

            Spacer(minLength: IhsanSpacing.xxs)

            HStack(spacing: IhsanSpacing.sm) {
                if let rawatib, rawatib.hasAnySlot {
                    rawatibStrip(rawatib)
                }
                Spacer(minLength: 0)
                Button {
                    Haptics.impact(.light)
                    presentMoreOptions()
                } label: {
                    HStack(spacing: 4) {
                        Text("MORE")
                            .font(IhsanFont.inscription)
                            .tracking(1.6)
                        Image(systemName: "chevron.up")
                            .font(.system(size: 8, weight: .semibold))
                    }
                    .foregroundStyle(tokens.metal.opacity(0.70))
                    .padding(.leading, IhsanSpacing.sm)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("More options")
                .accessibilityHint("Opens the full prayer log sheet. You can also swipe the card up.")
            }
            .frame(height: 18)
        }
    }

    /// The grabber: the one mark that says this card can be dragged.
    /// Without it the swipe is a secret, and a secret gesture is not an
    /// affordance.
    private var grabber: some View {
        Capsule()
            .fill(tokens.metal.opacity(0.45))
            .frame(width: 34, height: 3.5)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityHidden(true)
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
                .inkKeyline(tokens)
            // Keylined on its own so the 0.72 can sit OUTSIDE the
            // modifier: it draws its content twice, so a translucent
            // foreground composites with itself and takes a near-black
            // wash from the upper copy's ring. Fading the finished mark
            // — glyph and rings together — is what was meant anyway.
            Text(prayer.displayNameArabic)
                .font(IhsanFont.bodyArabic)
                .foregroundStyle(tokens.ink)
                .inkKeyline(tokens)
                .opacity(0.72)
        }
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

// MARK: - Jamaʿah chip

/// The congregation modifier, in the app's own marker vocabulary: a
/// hollow ring when off, the gilded ring when on, with its name beside
/// it. Left-aligned like everything else in the expanded card.
///
/// It replaced a centred pill whose entire state was a background fill
/// — off read as "a button", on read as "a slightly different button",
/// and neither read as a setting. Filled-versus-hollow is the same
/// distinction the plate's markers and the nafl chips already make, so
/// there is nothing new to learn here.
private struct JamaahChip: View {
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
            HStack(spacing: 7) {
                ZStack {
                    Circle()
                        .fill(tokens.leafGold)
                        .opacity(isOn ? 1 : 0)
                    Circle()
                        .strokeBorder(
                            isOn ? tokens.keyline.opacity(0.85) : tokens.metal.opacity(0.65),
                            lineWidth: isOn ? 1.2 : 1
                        )
                }
                .frame(width: 13, height: 13)

                Text("IN \(IhsanVocabulary.jamaahInscription)")
                    .font(IhsanFont.inscription)
                    .tracking(1.7)
                    .foregroundStyle(isOn ? tokens.ink : tokens.inkSecondary)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .overlay {
                Capsule()
                    .strokeBorder(
                        tokens.metal.opacity(isOn ? 0.75 : 0.35),
                        lineWidth: 0.9
                    )
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(IhsanVocabulary.inJamaahTitle)
        .accessibilityValue(isOn ? "on" : "off")
        .accessibilityAddTraits(.isToggle)
        .accessibilityHint("Double-tap to toggle \(IhsanVocabulary.jamaah) selection.")
    }
}

// MARK: - Timing commit button

/// One of the two commit buttons in the expanded state — labels only,
/// no glyphs, in the panel language.
///
/// **On Time rests filled**: leaf gold bounded by the keyline, with
/// keyline ink on top — the same recipe the log sheet's commit bar
/// uses, so the two surfaces read as one system. Previously both
/// buttons rested as identical outlined capsules and the `prominent`
/// flag did not become visible until the finger was already down,
/// which is exactly too late for a hierarchy to be useful.
///
/// Delayed rests as a plain metal outline and fills on press. Its press
/// fill plays just ahead of the logged transition, synchronised with
/// the ornament's materialize pour.
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
            // Slight delay so the press is visible before the card
            // transitions to the logged state.
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 120_000_000)
                action()
            }
        } label: {
            Text(label.uppercased())
                .font(IhsanFont.inscription)
                .tracking(1.8)
                .foregroundStyle(foreground)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background {
                    Capsule()
                        .fill(prominent ? AnyShapeStyle(tokens.leafGold) : AnyShapeStyle(tokens.metal))
                        .opacity(prominent || isPressing ? 1 : 0)
                }
                .overlay {
                    Capsule()
                        .strokeBorder(
                            prominent
                                ? tokens.keyline.opacity(0.55)
                                : tokens.metal.opacity(0.75),
                            lineWidth: prominent ? 1.1 : 1
                        )
                }
                .scaleEffect(isPressing && !reduceMotion ? 0.97 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log as \(label)")
        .accessibilityHint("Double-tap to log as \(label.lowercased()).")
    }

    /// Gold demands the keyline on top; the outlined secondary keeps
    /// plain ink until its own fill arrives beneath it.
    private var foreground: Color {
        if prominent { return tokens.keyline }
        return isPressing ? tokens.panelFill : tokens.ink
    }
}

// The spoken labels now come from `PrayerStatus`'s own vocabulary in
// IhsanCore, so the card, the sheet, the Path counts, and Siri all say
// the same word.
