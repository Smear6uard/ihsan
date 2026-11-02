import IhsanCore
import IhsanDesignSystem
import IhsanPrayerTimes
import SwiftUI

/// The focused-prayer card on the celestial Today screen — an
/// illuminated panel that shares the plate's ornament language.
///
/// One panel at the bottom of the screen showing a single prayer at a
/// time; tapping a prayer marker on the plate swaps the focused prayer.
///
/// **The card is the commit.** Every recording happens here, in one tap,
/// and every recording can be taken back in one tap:
///
/// 1. **Upcoming** — the prayer's *time* is the primary numeral and the
///    countdown an inscription ("OPENS IN · 2:14:09"). Nothing to press:
///    a window that has not opened has nothing to record.
/// 2. **Open, unrecorded** — the window line ("NOW · UNTIL 6:15 AM") and
///    two seals on the card itself: On Time, gilded as the default, and
///    Delayed. Both are inside the window; one tap records.
/// 3. **Closed, unrecorded** (a marker tapped, a widget's link) — four
///    seals, each the ornament in the state it would leave on the plate.
///    No default: memory, not the clock, decides what happened.
/// 4. **Recorded** — the ornament in its recorded state, a summary, a
///    jamāʿah chip that applies at once, and for a few seconds Undo.
///    Tapping the card changes the record in place: the same seals with
///    the record's own marked, and Remove.
///
/// It replaced a card that had to be opened before it could commit, set
/// jamāʿah *before* the commit, folded itself away after twelve seconds,
/// and sent everything else up a hidden swipe to a separate sheet.
///
/// Copy rule: the card describes the *window*, never the user's act —
/// "NOW", not "PRAYING NOW".
///
/// The card owns no clock: the screen's single timeline hands it the
/// resolved `now`, and every derived state comes from
/// `FocusedCardModel`, whose tests pin the no-resting-zero and
/// atomic-boundary guarantees.
struct FocusedPrayerCard: View {
    struct KhatamMoment: Equatable {
        let count: Int
        let unit: KhatamUnit

        var inscription: String {
            let label = count == 1 ? unit.singularLabel : unit.pluralLabel
            return "\(count.formatted()) \(label)".uppercased()
        }
    }

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
    /// When the existing log was recorded — shown in the recorded
    /// inscription instead of ever reading a clock.
    let loggedAt: Date?
    let isJamaah: Bool
    /// The exact temporal state from the shared resolver. The card
    /// performs no independent boundary comparisons.
    let windowState: PrayerWindowState
    /// The timings that can be true at this moment for this prayer —
    /// `TimingAvailability`'s answer for an unrecorded prayer. The seals
    /// are exactly these, so the card can never offer what the clock
    /// rules out.
    let availableStatuses: Set<PrayerStatus>

    /// The congregation's time for this prayer, already resolved and
    /// formatted — "IQAMAH · 1:30 PM", or "KHUTBAH · 1:15 PM" on Friday.
    ///
    /// It joins the state line's register: same inscription face, same
    /// tracking, same `inkSecondary`. Deliberately not a badge, a chip, or
    /// gilded — gold means *committed* in this app, and an informational
    /// time may not borrow that meaning.
    ///
    /// `nil` renders the card exactly as it was before My Masjid existed.
    var iqamahInscription: String?
    /// The spoken form of the same line, for VoiceOver.
    var iqamahSpoken: String?

    /// Sunnah-layer surfaces; all default off so the five-prayer card
    /// is untouched until the user opts in.
    var rawatib: RawatibChips?
    var nightSet: NightChips?
    var onToggleNafl: ((NaflKind) -> Void)?

    /// Records a timing for this prayer — one tap, through the parent's
    /// funnel. Changing a record arrives here too.
    let onCommit: (PrayerStatus) -> Void
    /// Flips jamāʿah on the existing record, at once — a modifier of
    /// what happened, so it is set after the fact, not before.
    var onToggleJamaah: () -> Void = {}
    /// Takes the record away.
    var onRemove: () -> Void = {}
    /// Puts back what the last change to this prayer replaced. Non-nil
    /// only while that is still on offer.
    var onUndo: (() -> Void)? = nil
    /// Begins an excused pause. Offered from the card's long-press menu;
    /// it used to live only in the footer of a sheet behind a swipe.
    var onBeginPause: (() -> Void)? = nil
    /// Any touch on the card. The parent holds a marker-tapped focus for
    /// as long as the card is in use.
    var onInteraction: () -> Void = {}

    /// Opens the tasbīḥ instrument — the recorded card's quiet link,
    /// the natural post-prayer moment. `nil` renders no link.
    var onTasbih: (() -> Void)? = nil

    /// A numeric handoff to the person's own mushaf. It shares the
    /// post-prayer action rail and contains no reading content.
    var khatamMoment: KhatamMoment? = nil
    var onKhatam: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Changing a record in place. Debug: `-IhsanDebugChangeCard` opens
    /// a recorded card in this state for the capture harness.
    @State private var isChanging = DebugLaunch.flag("-IhsanDebugChangeCard")

    /// The card's resting height, and the one the celestial composition
    /// above is measured against.
    static let cardHeight: CGFloat = 140

    /// What a congregation line costs: one inscription row plus the
    /// spacing above it.
    ///
    /// The card grows rather than compressing, because the state it has
    /// least room in — `.upcoming`, which already carries a title-scale
    /// numeral above its inscription — is exactly the state where the
    /// iqamah is most useful: it is what a person plans their departure
    /// around.
    static let iqamahLineHeight: CGFloat = 20

    /// What the open card's sunnah row costs beneath its seals. A
    /// recorded card carries the same chips inside its resting height.
    static let naflRowHeight: CGFloat = 26

    /// The resting height for the card the screen is about to draw. The
    /// scene above is measured against this same number, so the page
    /// stays one composition instead of the card quietly covering more
    /// sky.
    static func cardHeight(
        hasIqamah: Bool,
        hasKhatam: Bool = false,
        hasNaflRow: Bool = false,
        accessibilityLayout: Bool = false
    ) -> CGFloat {
        cardHeight
            + (hasIqamah ? iqamahLineHeight : 0)
            + (hasKhatam ? (accessibilityLayout ? 46 : 26) : 0)
            + (hasNaflRow ? naflRowHeight : 0)
    }

    /// Whether an open, unrecorded card carries the sunnah row beneath
    /// its seals — asked by the screen, which lays the plate out against
    /// the answer.
    static func carriesNaflRow(
        phase: FocusedCardModel.Phase,
        rawatib: RawatibChips?,
        nightSet: NightChips?
    ) -> Bool {
        guard case .active = phase else { return false }
        let hasRawatib = rawatib.map {
            FocusedCardModel.showsRawatibChips(phase: phase, hasConfiguredSlot: $0.hasAnySlot)
        } ?? false
        return hasRawatib || nightSet != nil
    }

    private var isLogged: Bool { currentStatus != nil }

    /// The post-prayer handoff belongs to the moment just completed,
    /// not every historical log. A made-up or retroactive entry never
    /// pretends that the prayer's live window is still open.
    private var showsTasbihOffer: Bool {
        FocusedCardModel.offersPostPrayerTasbih(
            windowState: windowState,
            status: currentStatus,
            isAvailable: onTasbih != nil
        )
    }

    private var showsKhatamOffer: Bool {
        showsTasbihOffer && khatamMoment != nil && onKhatam != nil
    }

    private var phase: FocusedCardModel.Phase {
        FocusedCardModel.resolve(windowState: windowState, isLogged: isLogged)
    }

    /// The window's own phase, record aside — what a change is offered
    /// against.
    private var windowPhase: FocusedCardModel.Phase {
        FocusedCardModel.resolve(windowState: windowState, isLogged: false)
    }

    private var isInWindow: Bool { windowState.isCurrent }

    private var carriesNaflRow: Bool {
        Self.carriesNaflRow(phase: phase, rawatib: rawatib, nightSet: nightSet)
    }

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity)
            .frame(
                height: Self.cardHeight(
                    hasIqamah: iqamahInscription != nil,
                    hasKhatam: showsKhatamOffer,
                    hasNaflRow: carriesNaflRow,
                    accessibilityLayout: dynamicTypeSize.isAccessibilitySize
                )
            )
            .celestialPanel(tokens: tokens, cornerRadius: 20, isActive: isInWindow)
            .padding(.horizontal, IhsanSpacing.md)
            .contextMenu { menu }
            .animation(reduceMotion ? nil : .smooth(duration: 0.28), value: isChanging)
            .animation(reduceMotion ? nil : .smooth(duration: 0.30), value: isLogged)
            .onChange(of: prayer) { _, _ in isChanging = false }
            // A record that arrives or leaves — from this card, a widget,
            // the watch — ends a change in progress.
            .onChange(of: currentStatus) { _, _ in isChanging = false }
            .accessibilityElement(children: .contain)
            .accessibilityActions {
                if isLogged {
                    Button("Change") { beginChange() }
                    Button("Remove record") { remove() }
                }
                if let onUndo {
                    Button("Undo") { undo(onUndo) }
                }
                if let onBeginPause {
                    Button("Begin a pause") { onBeginPause() }
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if isLogged && isChanging {
            changingContent
                .transition(.opacity)
        } else if isLogged {
            recordedContent
                .transition(.opacity)
        } else if FocusedCardModel.allowsLogging(phase) {
            unrecordedContent
                .transition(.opacity)
        } else {
            upcomingContent
                .transition(.opacity)
        }
    }

    /// The long press: the record's two edits, and the excused pause.
    @ViewBuilder
    private var menu: some View {
        if isLogged && !isChanging {
            Button("Change", systemImage: "pencil") { beginChange() }
            Button("Remove record", systemImage: "trash", role: .destructive) { remove() }
        }
        if let onBeginPause {
            Button("Begin a pause", systemImage: "drop") { onBeginPause() }
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

    // MARK: - Upcoming

    @ViewBuilder
    private var upcomingContent: some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
            HStack(spacing: IhsanSpacing.md) {
                ornament
                prayerNameRow
                Spacer()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(PlateTimeFormat.time(scheduledTime, in: timeZone))
                    .font(.system(.title, design: .monospaced).monospacedDigit())
                    .fontWeight(.light)
                    .foregroundStyle(tokens.ink)
                    .inkKeyline(tokens)
                    .contentTransition(.numericText())
                inscriptionText(inscription(for: phase))
                    .contentTransition(.numericText())
                iqamahLine
            }
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabelForWindow)
    }

    // MARK: - Unrecorded: the seals

    private var commitSeals: [PrayerStatus] {
        FocusedCardModel.seals(available: availableStatuses)
    }

    @ViewBuilder
    private var unrecordedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            header(
                inscription: inscription(for: phase),
                accessibilityLabel: accessibilityLabelForWindow
            ) {
                if let onUndo { undoButton(onUndo) }
            }

            Spacer(minLength: IhsanSpacing.sm)

            TimingSealRow(
                prayer: prayer,
                seals: commitSeals,
                tokens: tokens,
                prominent: FocusedCardModel.prominentSeal(among: commitSeals),
                onChoose: commit
            )

            if carriesNaflRow {
                HStack(spacing: IhsanSpacing.sm) {
                    if let rawatib, rawatib.hasAnySlot {
                        rawatibChipSet(rawatib)
                    }
                    if let nightSet {
                        nightChipSet(nightSet)
                    }
                    Spacer(minLength: 0)
                }
                .frame(height: 22)
                .padding(.top, 6)
            }
        }
    }

    // MARK: - Recorded

    @ViewBuilder
    private var recordedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            header(
                inscription: inscription(for: .logged),
                accessibilityLabel: accessibilityLabelForRecord,
                accessibilityHint: "Double-tap to change.",
                onTap: beginChange
            ) {
                if let onUndo {
                    undoButton(onUndo)
                } else if showsTasbihOffer {
                    postPrayerColumn
                }
            }

            Spacer(minLength: IhsanSpacing.xs)

            HStack(spacing: IhsanSpacing.sm) {
                // A missed prayer was not offered, so it was not offered
                // in congregation.
                if currentStatus != .missed {
                    JamaahChip(isOn: isJamaah, tokens: tokens) {
                        Haptics.impact(.light)
                        onInteraction()
                        onToggleJamaah()
                    }
                }
                if showsRecordedRawatib, let rawatib {
                    rawatibChipSet(rawatib)
                }
                Spacer(minLength: 0)
            }
            .frame(height: 28)

            // The sunnah stays reachable after the fard is recorded —
            // the after-rawatib is prayed exactly then, and Isha's card
            // carries the night.
            if let nightSet {
                HStack(spacing: IhsanSpacing.sm) {
                    nightChipSet(nightSet)
                    Spacer(minLength: 0)
                }
                .frame(height: 22)
                .padding(.top, 6)
            }
        }
    }

    private var showsRecordedRawatib: Bool {
        guard let rawatib else { return false }
        return FocusedCardModel.showsRawatibChips(
            phase: phase, hasConfiguredSlot: rawatib.hasAnySlot
        )
    }

    @ViewBuilder
    private var postPrayerColumn: some View {
        VStack(alignment: .trailing, spacing: 5) {
            if let onTasbih {
                quietButton(
                    label: "TASBĪḤ",
                    accessibilityLabel: "Continue with tasbīḥ",
                    accessibilityHint: "Opens the tasbīḥ counter after this prayer.",
                    marked: true
                ) {
                    onTasbih()
                }
            }
            if showsKhatamOffer, let khatamMoment, let onKhatam {
                quietButton(
                    label: khatamMoment.inscription,
                    accessibilityLabel: "Log \(khatamMoment.count) \(khatamMoment.unit.pluralLabel) after \(prayer.displayNameEnglish)",
                    accessibilityHint: "Opens the numeric Khatam stepper, prefilled with this amount.",
                    marked: true
                ) {
                    onKhatam()
                }
            }
        }
    }

    // MARK: - Changing a record

    /// The seals for a change: what the window allows now, and the
    /// record's own timing whatever the window says — re-affirming what
    /// is recorded can never be blocked by the clock.
    private var changeSeals: [PrayerStatus] {
        var available = availableStatuses
        if let currentStatus { available.insert(currentStatus) }
        return FocusedCardModel.seals(available: available)
    }

    @ViewBuilder
    private var changingContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            header(
                inscription: inscription(for: windowPhase),
                accessibilityLabel: "Changing \(prayer.displayNameEnglish). \(accessibilityLabelForRecord)"
            ) {
                HStack(spacing: 2) {
                    Button {
                        remove()
                    } label: {
                        Text("REMOVE")
                            .font(IhsanFont.inscription)
                            .tracking(1.4)
                            .foregroundStyle(tokens.inkSecondary)
                            .frame(minHeight: 32)
                            .padding(.horizontal, 8)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove record")
                    .accessibilityHint("Clears \(prayer.displayNameEnglish)'s record. Undo stays on offer for a few seconds.")

                    Button {
                        Haptics.impact(.light)
                        isChanging = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(tokens.metal.opacity(0.85))
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Done")
                }
            }

            Spacer(minLength: IhsanSpacing.sm)

            TimingSealRow(
                prayer: prayer,
                seals: changeSeals,
                tokens: tokens,
                selected: currentStatus,
                onChoose: change
            )
        }
    }

    // MARK: - Shared rows

    /// Ornament, name pair, the state line and the congregation's line,
    /// with one trailing slot. `onTap` makes the text block a door (the
    /// recorded card opens its change); the trailing controls are their
    /// own buttons either way.
    private func header<Trailing: View>(
        inscription: String,
        accessibilityLabel: String,
        accessibilityHint: String? = nil,
        onTap: (() -> Void)? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(alignment: .top, spacing: IhsanSpacing.sm) {
            HStack(alignment: .top, spacing: IhsanSpacing.sm) {
                ornament
                VStack(alignment: .leading, spacing: 2) {
                    prayerNameRow
                    inscriptionText(inscription)
                    iqamahLine
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onTap?()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(accessibilityHint ?? "")
            .accessibilityAddTraits(onTap == nil ? [] : .isButton)

            trailing()
        }
    }

    private func inscriptionText(_ text: String) -> some View {
        Text(text.uppercased())
            .font(IhsanFont.inscription)
            .tracking(1.4)
            .monospacedDigit()
            .foregroundStyle(tokens.inkSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .inkKeyline(tokens)
    }

    /// The congregation's time, joining the state line's register.
    /// Hidden from VoiceOver here because each layout combines its
    /// children into a single spoken label that already carries it.
    @ViewBuilder
    private var iqamahLine: some View {
        if let iqamahInscription {
            Text(iqamahInscription)
                .font(IhsanFont.inscription)
                .tracking(1.4)
                .monospacedDigit()
                .foregroundStyle(tokens.inkSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .inkKeyline(tokens)
                .accessibilityHidden(true)
        }
    }

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

    private func undoButton(_ action: @escaping () -> Void) -> some View {
        quietButton(
            label: "UNDO",
            accessibilityLabel: "Undo",
            accessibilityHint: "Puts back \(prayer.displayNameEnglish)'s record as it was.",
            marked: false
        ) {
            undo(action)
        }
    }

    /// The quiet capsule the post-prayer links and Undo share: metal
    /// edge, a faint metal wash, inscription register. A leaf dot marks
    /// the forward offers; Undo goes without it.
    private func quietButton(
        label: String,
        accessibilityLabel: String,
        accessibilityHint: String,
        marked: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.impact(.light)
            onInteraction()
            action()
        } label: {
            HStack(spacing: 6) {
                if marked {
                    Circle()
                        .fill(tokens.leafGold)
                        .frame(width: 5, height: 5)
                }
                Text(label)
                    .font(IhsanFont.inscription)
                    .tracking(1.35)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(tokens.ink)
            .padding(.horizontal, 10)
            .frame(minHeight: 34)
            .background(tokens.metal.opacity(0.11), in: Capsule())
            .overlay {
                Capsule().strokeBorder(tokens.metal.opacity(0.34), lineWidth: 0.7)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }

    // MARK: - Sunnah chips
    //
    // Both rows render only when the parent hands them a model, which it
    // does only after the user turns the layer on. One tap records; a
    // second tap removes. Filled ornament = recorded, outline = not —
    // the same vocabulary as the plate's markers.

    /// The before/after chips alone — shared by the open card's sunnah
    /// row and the recorded card's modifier row.
    @ViewBuilder
    private func rawatibChipSet(_ rawatib: RawatibChips) -> some View {
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
    }

    @ViewBuilder
    private func nightChipSet(_ nightSet: NightChips) -> some View {
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
            onInteraction()
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
                            .stroke(tokens.metal.opacity(0.55), lineWidth: 0.9)
                    }
                }
                .frame(width: 14, height: 14)

                Text(caption)
                    .font(IhsanFont.inscription)
                    .tracking(1.2)
                    .foregroundStyle(tokens.metal.opacity(logged ? 0.95 : 0.65))
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

    // MARK: - Acts

    private func commit(_ status: PrayerStatus) {
        Haptics.settle()
        onInteraction()
        onCommit(status)
    }

    private func change(_ status: PrayerStatus) {
        guard status != currentStatus else {
            isChanging = false
            return
        }
        Haptics.settle()
        onInteraction()
        onCommit(status)
        isChanging = false
    }

    private func beginChange() {
        Haptics.impact(.light)
        onInteraction()
        isChanging = true
    }

    private func remove() {
        Haptics.impact(.light)
        onInteraction()
        isChanging = false
        onRemove()
    }

    private func undo(_ action: () -> Void) {
        isChanging = false
        action()
    }

    // MARK: - Copy

    private func inscription(for phase: FocusedCardModel.Phase) -> String {
        FocusedCardModel.inscription(
            for: phase,
            status: currentStatus,
            loggedAt: loggedAt,
            // The chip beneath carries jamāʿah now, in both senses.
            isJamaah: false,
            windowEndTime: windowEndTime,
            scheduledTime: scheduledTime,
            now: now,
            timeZone: timeZone,
            windowEndDescriptor: PrayerWindowRule.windowEndDescriptor(for: prayer)
        )
    }

    /// The spoken window, phrased by the same copy rule the visual
    /// inscription follows.
    private var accessibilityLabelForWindow: String {
        var parts: [String] = ["\(prayer.displayNameEnglish) prayer"]
        switch windowPhase {
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
        if let iqamahSpoken {
            parts.append(iqamahSpoken)
        }
        return parts.joined(separator: ", ")
    }

    private var accessibilityLabelForRecord: String {
        var parts: [String] = ["\(prayer.displayNameEnglish) prayer", "logged"]
        if isJamaah {
            parts.append("in \(IhsanVocabulary.jamaah)")
        }
        if let status = currentStatus {
            parts.append(status.spokenLabel)
        }
        if let iqamahSpoken {
            parts.append(iqamahSpoken)
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Jamaʿah chip

/// The congregation modifier, in the app's own marker vocabulary: a
/// hollow ring when off, the gilded ring when on, with its name beside
/// it. It is both the record's jamāʿah state and the control that
/// changes it, and a tap applies at once — jamāʿah describes what
/// happened, so it is set after the commit, not staged before it.
struct JamaahChip: View {
    let isOn: Bool
    let tokens: SkyPaletteTokens
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
            .frame(minHeight: 28)
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
        .accessibilityHint("Double-tap to record whether this prayer was in \(IhsanVocabulary.jamaah).")
    }
}

// The spoken labels come from `PrayerStatus`'s own vocabulary in
// IhsanCore, so the card, the sheet, the Path counts, and Siri all say
// the same word.
