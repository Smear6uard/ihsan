import IhsanCore
import IhsanDesignSystem
import IhsanPrayerTimes
import SwiftUI

/// The log sheet, rebuilt on the two-axis model.
///
/// Structure mirrors the data: **jamāʿah is a toggle** (the
/// congregation axis) presented distinctly above the **timing
/// choice** (one exclusive selection — On Time / Late / Qadā /
/// Missed). The ornament states ARE the iconography: each timing
/// tile shows this prayer's own ornament in exactly the state that
/// choice would produce on the plate — gilded for On Time, the warm
/// outline for Late, the lapis pigment for Qadā, the quiet passed
/// state for Missed. The sheet teaches the plate's language.
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

    /// One commit: the chosen timing plus the jamāʿah flag, together.
    let onCommit: (PrayerStatus, Bool) -> Void
    var onTogglePause: () -> Void = {}
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

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
        self.onCommit = onCommit
        self.onTogglePause = onTogglePause
        self.onCancel = onCancel
        // Editing an existing log opens with its state preselected.
        _selectedTiming = State(initialValue: currentStatus)
        _jamaahOn = State(initialValue: isJamaah)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Scrolls only when it must (accessibility type sizes);
            // at standard sizes the sheet is one still composition.
            ScrollView {
                VStack(spacing: 0) {
                    header
                        .padding(.top, IhsanSpacing.xl)

                    jamaahRow
                        .padding(.horizontal, IhsanSpacing.md)
                        .padding(.top, IhsanSpacing.lg)

                    timingGrid
                        .padding(.horizontal, IhsanSpacing.md)
                        .padding(.top, IhsanSpacing.md)
                }
            }
            .scrollBounceBehavior(.basedOnSize)

            Spacer(minLength: IhsanSpacing.md)

            commitBar
                .padding(.horizontal, IhsanSpacing.md)
            footer
                .padding(.horizontal, IhsanSpacing.lg)
                .padding(.top, IhsanSpacing.sm)
                .padding(.bottom, IhsanSpacing.lg)
        }
        .background {
            // The warm backing under the platform glass — never a
            // gray scrim over the scene's warmth.
            tokens.chromeTint.ignoresSafeArea()
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Header

    /// "12:38 PM · ENDS 5:06 PM" — the place's clock, always.
    private var timeRangeInscription: String {
        let start = PlateTimeFormat.time(scheduledTime, in: timeZone).uppercased()
        guard let end = windowEndTime else { return start }
        return "\(start) · ENDS \(PlateTimeFormat.time(end, in: timeZone).uppercased())"
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
                Text("In Jamāʿah")
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
        .accessibilityLabel("In jamāʿah, prayed in congregation")
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
        return LazyVGrid(columns: columns, spacing: IhsanSpacing.sm) {
            timingTile(.onTime, title: "On Time", caption: "PRAYED IN ITS WINDOW")
            timingTile(.late, title: "Late", caption: "PRAYED AFTER ITS WINDOW")
            timingTile(.qada, title: "Qadā", caption: "MADE UP LATER")
            timingTile(.missed, title: "Missed", caption: "ITS WINDOW PASSED UNPRAYED")
        }
    }

    private func timingTile(
        _ timing: PrayerStatus, title: String, caption: String
    ) -> some View {
        let selected = selectedTiming == timing
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
        }
        .buttonStyle(.plain)
        .celestialPanel(tokens: tokens, cornerRadius: 16, isActive: selected)
        .overlay {
            if selected {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(tokens.leafGold.opacity(0.85), lineWidth: 1.2)
            }
        }
        .accessibilityLabel("\(title), \(caption.lowercased())")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
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
            // The warm metal outline.
            PrayerOrnamentShape(prayer: prayer, mode: .outline)
                .stroke(tokens.metal.opacity(0.85), lineWidth: 1.3)
        case .qada:
            // The pigment without the leaf: lapis body, keyline edge —
            // made up later, warm, never alarming.
            ZStack {
                PrayerOrnamentShape(prayer: prayer, mode: .filled)
                    .fill(tokens.lapis, style: FillStyle(eoFill: true))
                PrayerOrnamentShape(prayer: prayer, mode: .filled)
                    .stroke(tokens.keyline, lineWidth: 0.75)
            }
        case .missed:
            // The quiet passed state.
            PrayerOrnamentShape(prayer: prayer, mode: .outline)
                .stroke(tokens.inkSecondary.opacity(0.75), lineWidth: 1.0)
        }
    }

    // MARK: - Commit

    private var commitBar: some View {
        Button {
            guard let timing = selectedTiming else { return }
            // Haptic first — commit feel lands with the tap, the
            // optimistic model update follows within the same beat,
            // and the plate's materialize animation plays off it.
            Haptics.notification(.success)
            onCommit(timing, jamaahOn)
            dismiss()
        } label: {
            Text(currentStatus == nil ? "LOG PRAYER" : "SAVE CHANGES")
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
        .accessibilityLabel(currentStatus == nil ? "Log prayer" : "Save changes")
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
            // not ask why.
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
