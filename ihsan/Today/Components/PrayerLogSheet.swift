import IhsanCore
import IhsanDesignSystem
import IhsanPrayerTimes
import SwiftUI

/// The log sheet, rebuilt on the two-axis model.
///
/// Structure mirrors the data: **jamāʿah is a toggle** (the
/// congregation axis) presented distinctly beneath the **timing
/// choice** (one exclusive selection — On Time / Delayed / Qadā /
/// Missed). The ornament states ARE the iconography: each timing
/// row shows this prayer's own ornament in exactly the state that
/// choice would produce on the plate — gilded for On Time, the warm
/// outline for Delayed, the lapis pigment for Qadā, the quiet passed
/// state for Missed. The sheet teaches the plate's language.
///
/// Every name and caption comes from `PrayerStatus`'s vocabulary, so
/// the sheet cannot phrase the timing axis differently from the card,
/// the Path counts, or Siri. On Time and Delayed both describe a
/// prayer offered INSIDE its window; qadā is the one offered after.
///
/// Times format through `PlateTimeFormat` in the **place's**
/// timezone — the sheet can never again disagree with the plate
/// about when a window ends.
///
/// Chrome: the sheet rides the platform's glass presentation with
/// the palette's `chromeTint` backing (warm on the day grounds,
/// clear on jewel grounds), content as illuminated panels.
struct PrayerLogSheet: View {
    let prayer: Prayer
    let scheduledTime: Date
    /// End of the prayer's window, from `PrayerWindowRule` — the one
    /// rule every surface reads.
    let windowEndTime: Date?
    /// The place's timezone: the display frame for every clock time.
    let timeZone: TimeZone
    let tokens: SkyPaletteTokens
    let currentStatus: PrayerStatus?
    let isJamaah: Bool
    var isPaused: Bool = false
    /// The timing choices that can be true at this moment for this
    /// prayer and day — `TimingAvailability`'s answer. Rows outside
    /// the set render quiet and disabled: visible for learnability,
    /// not selectable.
    let availableStatuses: Set<PrayerStatus>
    /// Set when the sheet logs a day other than today (the Path
    /// ledger): the header inscribes the date instead of the window's
    /// clock times.
    var displayDate: Date? = nil
    /// The exact state produced by `PrayerStateResolver`. `nil`
    /// (retroactive days) shows the date, no live temporal claim.
    var windowState: PrayerWindowState? = nil
    /// The congregation's time for this prayer, already resolved and
    /// formatted. `nil` renders the header exactly as it was before My
    /// Masjid existed.
    var iqamahInscription: String? = nil
    var iqamahSpoken: String? = nil

    /// One commit: the chosen timing plus the jamāʿah flag, together.
    let onCommit: (PrayerStatus, Bool) -> Void
    var onTogglePause: () -> Void = {}
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedTiming: PrayerStatus?
    @State private var jamaahOn: Bool

    init(
        prayer: Prayer,
        scheduledTime: Date,
        windowEndTime: Date?,
        timeZone: TimeZone,
        tokens: SkyPaletteTokens,
        currentStatus: PrayerStatus?,
        isJamaah: Bool,
        isPaused: Bool = false,
        availableStatuses: Set<PrayerStatus>,
        displayDate: Date? = nil,
        windowState: PrayerWindowState? = nil,
        iqamahInscription: String? = nil,
        iqamahSpoken: String? = nil,
        onCommit: @escaping (PrayerStatus, Bool) -> Void,
        onTogglePause: @escaping () -> Void = {},
        onCancel: @escaping () -> Void
    ) {
        self.prayer = prayer
        self.scheduledTime = scheduledTime
        self.windowEndTime = windowEndTime
        self.timeZone = timeZone
        self.tokens = tokens
        self.currentStatus = currentStatus
        self.isJamaah = isJamaah
        self.isPaused = isPaused
        self.availableStatuses = availableStatuses
        self.displayDate = displayDate
        self.windowState = windowState
        self.iqamahInscription = iqamahInscription
        self.iqamahSpoken = iqamahSpoken
        self.onCommit = onCommit
        self.onTogglePause = onTogglePause
        self.onCancel = onCancel
        // Editing an existing log opens with its state preselected.
        _selectedTiming = State(initialValue: currentStatus)
        _jamaahOn = State(initialValue: isJamaah)
    }

    // MARK: - Commit copy

    /// The commit names the act: a fresh entry logs THIS prayer; an
    /// edit saves changes. Pinned by `PrayerLogSheetCopyTests` and
    /// asserted through the live UI by `PrayerLogCommitUITests`.
    static func commitTitle(prayer: Prayer, isEditing: Bool) -> String {
        isEditing ? "Save Changes" : "Log \(prayer.displayNameEnglish)"
    }

    var body: some View {
        GlassEffectContainer(spacing: IhsanSpacing.md) {
            ScrollView {
                VStack(spacing: IhsanSpacing.lg) {
                    header

                    timingGrid

                    if selectedTiming != .missed {
                        jamaahRow
                            .transition(
                                reduceMotion
                                    ? .identity
                                    : .opacity.combined(with: .move(edge: .top))
                            )
                    }

                    commitBar

                    footer
                }
                .padding(.horizontal, IhsanSpacing.md)
                .padding(.top, IhsanSpacing.md)
                .padding(.bottom, IhsanSpacing.lg)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .background {
            // The SkyPhase backing under the platform glass — indigo
            // at night, plum at sunset, warm near-white on the days.
            // Never a gray scrim, never a flat charcoal slab.
            tokens.sheetBacking.ignoresSafeArea()
        }
        .presentationDetents([.fraction(0.82), .large])
        .presentationContentInteraction(.scrolls)
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
        .accessibilityElement(children: .contain)
        .animation(
            reduceMotion ? nil : .snappy(duration: 0.30, extraBounce: 0.05),
            value: selectedTiming
        )
    }

    // MARK: - Header

    /// "12:38 PM · ENDS 5:06 PM" — the place's clock, always. A
    /// retroactive day has no clock to show; it inscribes its date.
    private var timeRangeInscription: String {
        Self.timeRangeInscription(
            scheduledTime: scheduledTime,
            windowEndTime: windowEndTime,
            displayDate: displayDate,
            windowState: windowState,
            timeZone: timeZone
        )
    }

    /// The header's tense follows the derived window state, exactly
    /// as the card's does: before the boundary "ENDS", after it
    /// "ENDED". Without a resolved moment the neutral present holds.
    static func timeRangeInscription(
        scheduledTime: Date,
        windowEndTime: Date?,
        displayDate: Date?,
        windowState: PrayerWindowState?,
        timeZone: TimeZone
    ) -> String {
        if let displayDate {
            return PlateTimeFormat.dayMonth(displayDate, in: timeZone).uppercased()
        }
        let start = PlateTimeFormat.time(scheduledTime, in: timeZone).uppercased()
        guard let end = windowEndTime else { return start }
        let verb: String
        if case .closed = windowState {
            verb = "ENDED"
        } else {
            verb = "ENDS"
        }
        return "\(start) · \(verb) \(PlateTimeFormat.time(end, in: timeZone).uppercased())"
    }

    private var header: some View {
        HStack(spacing: IhsanSpacing.md) {
            GildedOrnamentGlyph(prayer: prayer, size: IhsanSpacing.xl, tokens: tokens)
                .frame(width: IhsanSpacing.xxl, height: IhsanSpacing.xxl)
                .ihsanGlass(in: Circle(), intensity: .subtle, isClear: true)

            VStack(alignment: .leading, spacing: IhsanSpacing.xs) {
                Text("LOG PRAYER")
                    .font(IhsanFont.inscription)
                    .tracking(2.2)
                    .foregroundStyle(tokens.inkSecondary)

                HStack(alignment: .firstTextBaseline, spacing: IhsanSpacing.sm) {
                    Text(prayer.displayNameEnglish)
                        .font(IhsanFont.heroPrayerName)
                        .foregroundStyle(tokens.ink)
                    Text(prayer.displayNameArabic)
                        .font(IhsanFont.bodyArabic)
                        .foregroundStyle(tokens.ink.opacity(0.72))
                }

                Text(timeRangeInscription)
                    .font(IhsanFont.inscription)
                    .tracking(1.4)
                    .monospacedDigit()
                    .foregroundStyle(tokens.inkSecondary)

                // The congregation's time, in the same register directly
                // beneath the window it belongs to.
                if let iqamahInscription {
                    Text(iqamahInscription)
                        .font(IhsanFont.inscription)
                        .tracking(1.4)
                        .monospacedDigit()
                        .foregroundStyle(tokens.inkSecondary)
                        .accessibilityLabel(iqamahSpoken ?? iqamahInscription)
                }
            }

            Spacer(minLength: IhsanSpacing.xs)

            Button {
                Haptics.impact(.light)
                onCancel()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(IhsanFont.inscription)
                    .frame(width: IhsanSpacing.xxl, height: IhsanSpacing.xxl)
                    .contentShape(Circle())
            }
            .buttonStyle(PrayerSheetPressStyle())
            .ihsanGlass(
                in: Circle(),
                intensity: .subtle,
                isInteractive: true,
                isClear: true
            )
            .foregroundStyle(tokens.inkSecondary)
            .accessibilityLabel("Close")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    // MARK: - The congregation axis

    /// Jamāʿah is orthogonal to timing, and the layout says so: one
    /// toggle, its own panel, beneath the timing choice — never a
    /// sibling of it. Missed prayers can't have been in congregation.
    private var jamaahRow: some View {
        let disabled = selectedTiming == .missed
        return Toggle(isOn: $jamaahOn) {
            HStack(spacing: IhsanSpacing.md) {
                Image(systemName: "person.2")
                    .font(IhsanFont.bodyEnglishBold)
                    .foregroundStyle(tokens.metal)
                    .frame(width: IhsanSpacing.xl)

                VStack(alignment: .leading, spacing: IhsanSpacing.xxs) {
                    Text(IhsanVocabulary.inJamaahTitle)
                        .font(IhsanFont.bodyEnglishBold)
                        .foregroundStyle(tokens.ink.opacity(disabled ? 0.4 : 1))
                    Text("PRAYED IN CONGREGATION")
                        .font(IhsanFont.inscription)
                        .tracking(1.4)
                        .foregroundStyle(tokens.inkSecondary.opacity(disabled ? 0.5 : 1))
                }
            }
        }
        .toggleStyle(.switch)
        .tint(tokens.leafGold)
        .disabled(disabled)
        .padding(.horizontal, IhsanSpacing.md)
        .padding(.vertical, IhsanSpacing.md)
        .ihsanGlass(
            in: RoundedRectangle(cornerRadius: IhsanSpacing.cardRadius, style: .continuous),
            intensity: .regular,
            isActive: jamaahOn && !disabled,
            isInteractive: !disabled,
            isClear: true
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(IhsanVocabulary.inJamaahTitle), prayed in congregation")
        .accessibilityValue(disabled ? "unavailable for missed" : (jamaahOn ? "on" : "off"))
        .onChange(of: jamaahOn) {
            Haptics.impact(.light)
        }
    }

    // MARK: - The timing axis

    private static let timingChoices: [PrayerStatus] = [
        .onTime, .late, .qada, .missed
    ]

    private var timingGrid: some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
            Text("WHEN IT WAS PRAYED")
                .font(IhsanFont.inscription)
                .tracking(1.8)
                .foregroundStyle(tokens.inkSecondary)
                .padding(.leading, IhsanSpacing.xs)

            VStack(spacing: 0) {
                ForEach(Array(Self.timingChoices.enumerated()), id: \.element) { index, timing in
                    timingTile(timing)
                    if index < Self.timingChoices.count - 1 {
                        Rectangle()
                            .fill(tokens.panelStroke.opacity(0.55))
                            .frame(height: IhsanSpacing.hairline)
                            .padding(.leading, IhsanSpacing.xxl + IhsanSpacing.lg)
                    }
                }
            }
            .ihsanGlass(
                in: RoundedRectangle(cornerRadius: IhsanSpacing.cardRadius, style: .continuous),
                intensity: .regular,
                isClear: true
            )
        }
    }

    /// Opacity applied to a tile whose timing cannot be true at this
    /// moment — quiet, never invisible. Static so the contrast test
    /// audits the exact value the tiles render; 0.5 is the floor at
    /// which every dimmed ornament still holds ≥1.9:1 on its tile in
    /// all four palettes (0.45 dropped the afternoon late outline to
    /// 1.86).
    static let unavailableTileOpacity: Double = 0.5

    private func timingTile(_ timing: PrayerStatus) -> some View {
        let title = timing.displayName
        let caption = timing.caption
        let selected = selectedTiming == timing
        let available = availableStatuses.contains(timing)
        return Button {
            Haptics.impact(.light)
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.28, extraBounce: 0.06)) {
                selectedTiming = timing
                if timing == .missed { jamaahOn = false }
            }
        } label: {
            HStack(spacing: IhsanSpacing.md) {
                tileOrnament(for: timing)
                    .frame(width: IhsanSpacing.xl, height: IhsanSpacing.xl)

                VStack(alignment: .leading, spacing: IhsanSpacing.xxs) {
                    Text(title)
                        .font(selected ? IhsanFont.bodyEnglishBold : IhsanFont.bodyEnglish)
                        .foregroundStyle(tokens.ink)
                    Text(caption)
                        .font(IhsanFont.inscription)
                        .tracking(1.0)
                        .foregroundStyle(tokens.inkSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: IhsanSpacing.sm)

                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(IhsanFont.bodyEnglishBold)
                    .foregroundStyle(selected ? tokens.metal : tokens.inkSecondary.opacity(0.55))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, IhsanSpacing.md)
            .padding(.horizontal, IhsanSpacing.md)
            .background {
                if selected {
                    RoundedRectangle(
                        cornerRadius: IhsanSpacing.smallCardRadius,
                        style: .continuous
                    )
                    .fill(tokens.leafGold.opacity(0.10))
                    .padding(IhsanSpacing.xs)
                }
            }
            .contentShape(Rectangle())
            // The whole face quiets together — ornament, title, and
            // caption stay legible as one muted unit, teaching what
            // the state means even while it cannot be chosen.
            .opacity(available ? 1 : Self.unavailableTileOpacity)
        }
        .buttonStyle(PrayerSheetPressStyle())
        .disabled(!available)
        .accessibilityLabel("\(title), \(caption.lowercased())")
        .accessibilityValue(available ? "" : "not available now")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    // MARK: - Tile ornament treatments
    //
    // One recipe per timing state, exposed as static functions so
    // `PrayerLogSheetContrastTests` audits exactly the values the
    // tiles render — every state's primary boundary holds ≥3:1
    // against the tile in all four palettes. Quiet must never mean
    // invisible.

    /// The qadā body: lapis pigment, lifted a step on the jewel
    /// grounds so the roundel never sinks into a dark tile.
    static func qadaBodyValue(for tokens: SkyPaletteTokens) -> SRGBValue {
        tokens.groundBottomValue.relativeLuminance < 0.5
            ? tokens.lapisValue.scalingLightness(by: 1.4)
            : tokens.lapisValue
    }

    /// The qadā edge: the metal keyline that pairs gold with the
    /// pigment — the classical lapis-and-gold voice, and the boundary
    /// that carries the ornament on dark tiles.
    static func qadaEdgeValue(for tokens: SkyPaletteTokens) -> SRGBValue {
        tokens.metalValue
    }

    /// The delayed outline: warm metal on jewel grounds; on the
    /// near-white days plain metal falls under 3:1, so it deepens
    /// toward the keyline — still bronze, never gray. (Named for the
    /// `.late` case it draws, whose stored name predates the rename.)
    static func lateOutlineValue(for tokens: SkyPaletteTokens) -> SRGBValue {
        tokens.groundBottomValue.relativeLuminance < 0.5
            ? tokens.metalValue
            : SRGBValue.mix(tokens.metalValue, tokens.keylineValue, amount: 0.30)
    }

    /// The missed outline: quiet secondary ink, already ≥7:1 on every
    /// panel.
    static func missedOutlineValue(for tokens: SkyPaletteTokens) -> SRGBValue {
        tokens.inkSecondaryValue
    }

    /// The ornament in the state the choice would produce — the
    /// sheet's tiles and the plate's markers speak one language.
    @ViewBuilder
    private func tileOrnament(for timing: PrayerStatus) -> some View {
        switch timing {
        case .onTime:
            // Gilded: solid leaf bounded by the keyline.
            GildedOrnamentGlyph(prayer: prayer, size: 30, tokens: tokens)
        case .late:
            PrayerOrnamentShape(prayer: prayer, mode: .outline)
                .stroke(Self.lateOutlineValue(for: tokens).color.opacity(0.95), lineWidth: 1.3)
        case .qada:
            // The pigment paired with the metal: made up later — warm,
            // legible, never alarming.
            ZStack {
                PrayerOrnamentShape(prayer: prayer, mode: .filled)
                    .fill(Self.qadaBodyValue(for: tokens).color, style: FillStyle(eoFill: true))
                PrayerOrnamentShape(prayer: prayer, mode: .filled)
                    .stroke(Self.qadaEdgeValue(for: tokens).color.opacity(0.95), lineWidth: 1.0)
            }
        case .missed:
            // The quiet passed state.
            PrayerOrnamentShape(prayer: prayer, mode: .outline)
                .stroke(Self.missedOutlineValue(for: tokens).color.opacity(0.85), lineWidth: 1.0)
        }
    }

    // MARK: - Commit

    private var commitBar: some View {
        Button {
            guard let timing = selectedTiming else { return }
            // The settle lands with the tap; the optimistic model
            // update follows within the same beat, and the plate's
            // materialize animation plays off it.
            Haptics.settle()
            onCommit(timing, jamaahOn)
            dismiss()
        } label: {
            HStack(spacing: IhsanSpacing.sm) {
                Text(Self.commitTitle(prayer: prayer, isEditing: currentStatus != nil))
                    .font(IhsanFont.bodyEnglishBold)

                Image(systemName: "arrow.right")
                    .font(IhsanFont.inscription)
            }
                .foregroundStyle(commitEnabled ? tokens.ink : tokens.inkSecondary.opacity(0.55))
                .frame(maxWidth: .infinity)
                .padding(.vertical, IhsanSpacing.md)
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(PrayerSheetPressStyle())
        .disabled(!commitEnabled)
        .ihsanGlass(
            in: Capsule(style: .continuous),
            intensity: commitEnabled ? .hero : .subtle,
            isActive: commitEnabled,
            isInteractive: commitEnabled,
            isClear: true
        )
        .opacity(commitEnabled ? 1 : 0.72)
        .accessibilityLabel(Self.commitTitle(prayer: prayer, isEditing: currentStatus != nil))
        .accessibilityHint(commitEnabled ? "" : "Choose a timing first.")
    }

    private var commitEnabled: Bool { selectedTiming != nil }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Spacer(minLength: 0)
            // The excused-pause droplet, with its quiet name. One tap
            // begins a pause, the same control ends it. Ihsan does
            // not ask why. A pause is a statement about NOW — the
            // retroactive sheet (a past day) does not offer it.
            if displayDate == nil {
                Button {
                    Haptics.impact(.medium)
                    onTogglePause()
                    dismiss()
                } label: {
                    HStack(spacing: IhsanSpacing.xs) {
                        Image(systemName: isPaused ? "drop.fill" : "drop")
                            .font(.system(size: 14, weight: .regular))
                        Text(isPaused ? "PAUSED" : "PAUSE")
                            .font(IhsanFont.inscription)
                            .tracking(1.6)
                    }
                    .foregroundStyle(tokens.inkSecondary)
                    .padding(.vertical, IhsanSpacing.sm)
                }
                .buttonStyle(PrayerSheetPressStyle())
                .accessibilityLabel(isPaused ? "End the pause" : "Begin a pause")
            }
            Spacer(minLength: 0)
        }
    }
}

/// A restrained press response for controls already carrying native
/// Liquid Glass. Transform and opacity keep the interaction on the
/// compositor and avoid the abrupt flash of the legacy sheet.
private struct PrayerSheetPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(
                reduceMotion ? nil : .snappy(duration: 0.18, extraBounce: 0.04),
                value: configuration.isPressed
            )
    }
}
