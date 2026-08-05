import IhsanCore
import IhsanDesignSystem
import IhsanPrayerTimes
import SwiftUI

/// The log sheet, rebuilt on the two-axis model.
///
/// Structure mirrors the data: **jamāʿah is a toggle** (the
/// congregation axis) presented distinctly above the **timing
/// choice** (one exclusive selection — On Time / Delayed / Qadā /
/// Missed). The ornament states ARE the iconography: each timing
/// tile shows this prayer's own ornament in exactly the state that
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
    /// prayer and day — `TimingAvailability`'s answer. Tiles outside
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

    /// One commit: the chosen timing plus the jamāʿah flag, together.
    let onCommit: (PrayerStatus, Bool) -> Void
    var onTogglePause: () -> Void = {}
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedTiming: PrayerStatus?
    @State private var jamaahOn: Bool
    /// Measured natural height of the sheet's content — the medium
    /// detent is sized to exactly this, so there is no dead zone
    /// between the tiles and the commit button and nothing below the
    /// footer. At accessibility type sizes the measurement exceeds
    /// the screen, the detent clamps, and the scroll view takes over.
    @State private var contentHeight: CGFloat = 0

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
        // One still composition, top to bottom, with no dead zone:
        // the commit bar rides directly below the tiles, the footer
        // directly below it. Scrolls only when it must (accessibility
        // type sizes make the content taller than the screen).
        ScrollView {
            VStack(spacing: 0) {
                header
                    .padding(.top, IhsanSpacing.lg)

                jamaahRow
                    .padding(.horizontal, IhsanSpacing.md)
                    .padding(.top, IhsanSpacing.lg)

                timingGrid
                    .padding(.horizontal, IhsanSpacing.md)
                    .padding(.top, IhsanSpacing.md)

                commitBar
                    .padding(.horizontal, IhsanSpacing.md)
                    .padding(.top, IhsanSpacing.md)

                footer
                    .padding(.horizontal, IhsanSpacing.lg)
                    .padding(.top, IhsanSpacing.xs)
                    .padding(.bottom, IhsanSpacing.sm)
            }
            .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { height in
                contentHeight = height
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .background {
            // The SkyPhase backing under the platform glass — indigo
            // at night, plum at sunset, warm near-white on the days.
            // Never a gray scrim, never a flat charcoal slab.
            tokens.sheetBacking.ignoresSafeArea()
        }
        // A medium detent sized to the content itself. No .large:
        // the sheet holds exactly header + toggle + tiles + commit +
        // footer, and nothing here justifies a taller pull.
        .presentationDetents([.height(contentHeight > 0 ? contentHeight + 12 : 560)])
        .presentationDragIndicator(.visible)
        .presentationBackground(.thinMaterial)
        .accessibilityElement(children: .contain)
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
        VStack(spacing: IhsanSpacing.xs) {
            Text("LOG PRAYER")
                .font(IhsanFont.inscription)
                .tracking(2.4)
                .foregroundStyle(tokens.inkSecondary)

            HStack(alignment: .firstTextBaseline, spacing: IhsanSpacing.sm) {
                Text(prayer.displayNameEnglish)
                    .font(IhsanFont.heroPrayerName)
                    .foregroundStyle(tokens.ink)
                Text(prayer.displayNameArabic)
                    .font(IhsanFont.bodyArabic)
                    .foregroundStyle(tokens.ink.opacity(0.72))
            }
            .padding(.top, IhsanSpacing.xxs)

            Text(timeRangeInscription)
                .font(IhsanFont.inscription)
                .tracking(1.6)
                .monospacedDigit()
                .foregroundStyle(tokens.inkSecondary)
                .padding(.top, IhsanSpacing.xxs)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, IhsanSpacing.lg)
    }

    // MARK: - The congregation axis

    /// Jamāʿah is orthogonal to timing, and the layout says so: one
    /// toggle, its own panel, above the timing choice — never a
    /// sibling of it. Missed prayers can't have been in congregation.
    private var jamaahRow: some View {
        let disabled = selectedTiming == .missed
        return HStack(spacing: IhsanSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(IhsanVocabulary.inJamaahTitle)
                    .font(IhsanFont.rowPrayerName)
                    .foregroundStyle(tokens.ink.opacity(disabled ? 0.4 : 1))
                Text("PRAYED IN CONGREGATION")
                    .font(IhsanFont.inscription)
                    .tracking(1.4)
                    .foregroundStyle(tokens.inkSecondary.opacity(disabled ? 0.5 : 1))
            }
            Spacer()
            Toggle("", isOn: $jamaahOn)
                .labelsHidden()
                .tint(tokens.leafGold)
                .disabled(disabled)
        }
        .padding(.horizontal, IhsanSpacing.md)
        .padding(.vertical, IhsanSpacing.sm + 2)
        .celestialPanel(tokens: tokens, cornerRadius: 16, isActive: jamaahOn && !disabled)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(IhsanVocabulary.inJamaahTitle), prayed in congregation")
        .accessibilityValue(disabled ? "unavailable for missed" : (jamaahOn ? "on" : "off"))
        .accessibilityAddTraits(.isToggle)
        .onTapGesture {
            guard !disabled else { return }
            Haptics.impact(.light)
            jamaahOn.toggle()
        }
    }

    // MARK: - The timing axis

    private var timingGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: IhsanSpacing.sm),
            GridItem(.flexible(), spacing: IhsanSpacing.sm),
        ]
        // Names and captions come from `PrayerStatus`'s own vocabulary
        // — the sheet does not get to phrase the timing axis itself.
        // On Time and Delayed are both INSIDE the window; qadā is the
        // one that happens after it.
        return LazyVGrid(columns: columns, spacing: IhsanSpacing.sm) {
            timingTile(.onTime)
            timingTile(.late)
            timingTile(.qada)
            timingTile(.missed)
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
            selectedTiming = timing
            if timing == .missed { jamaahOn = false }
        } label: {
            VStack(spacing: IhsanSpacing.xs + 2) {
                tileOrnament(for: timing)
                    .frame(width: 30, height: 30)
                Text(title)
                    .font(IhsanFont.rowPrayerName)
                    .fontWeight(selected ? .semibold : .regular)
                    .foregroundStyle(tokens.ink)
                Text(caption)
                    .font(IhsanFont.inscription)
                    .tracking(1.1)
                    .foregroundStyle(tokens.inkSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, IhsanSpacing.md)
            .padding(.horizontal, IhsanSpacing.xs)
            .contentShape(Rectangle())
            // The whole face quiets together — ornament, title, and
            // caption stay legible as one muted unit, teaching what
            // the state means even while it cannot be chosen.
            .opacity(available ? 1 : Self.unavailableTileOpacity)
        }
        .buttonStyle(.plain)
        .disabled(!available)
        .celestialPanel(tokens: tokens, cornerRadius: 16, isActive: selected)
        .overlay {
            // Selection is form + weight, never hue alone: the chosen
            // tile takes the illuminated double rule — a heavier gold
            // border with an inset hairline echo — and its title turns
            // semibold above.
            if selected {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(tokens.leafGold.opacity(0.90), lineWidth: 1.6)
                RoundedRectangle(cornerRadius: 12.5, style: .continuous)
                    .strokeBorder(tokens.metal.opacity(0.55), lineWidth: 0.75)
                    .padding(3.5)
            }
        }
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
            Text(Self.commitTitle(prayer: prayer, isEditing: currentStatus != nil).uppercased())
                .font(IhsanFont.inscription)
                .tracking(2.2)
                .foregroundStyle(commitEnabled ? tokens.keyline : tokens.inkSecondary.opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, IhsanSpacing.sm + 4)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(commitEnabled ? AnyShapeStyle(tokens.leafGold) : AnyShapeStyle(tokens.panelFill.opacity(0.6)))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            commitEnabled ? tokens.keyline.opacity(0.55) : tokens.panelStroke.opacity(0.6),
                            lineWidth: 0.8
                        )
                }
        }
        .buttonStyle(.plain)
        .disabled(!commitEnabled)
        .accessibilityLabel(Self.commitTitle(prayer: prayer, isEditing: currentStatus != nil))
        .accessibilityHint(commitEnabled ? "" : "Choose a timing first.")
    }

    private var commitEnabled: Bool { selectedTiming != nil }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: IhsanSpacing.md) {
            Button {
                Haptics.impact(.light)
                onCancel()
                dismiss()
            } label: {
                Text("CANCEL")
                    .font(IhsanFont.inscription)
                    .tracking(1.8)
                    .foregroundStyle(tokens.inkSecondary)
                    .padding(.vertical, IhsanSpacing.sm)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel")

            Spacer()

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
                .buttonStyle(.plain)
                .accessibilityLabel(isPaused ? "End the pause" : "Begin a pause")
            }
        }
    }
}
