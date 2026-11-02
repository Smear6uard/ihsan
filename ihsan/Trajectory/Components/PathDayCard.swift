import SwiftUI
import IhsanCore
import IhsanDesignSystem

/// One day, in words, and the place to change it.
///
/// The grid above answers "what is the shape of this month?"; this
/// answers "what happened on that day?" It replaces a second copy of the
/// grid, thirty rows long, whose cells opened a sheet: pick a tile, set
/// a switch, press commit. Here it is the Today card's language. Tap a
/// prayer and its seals appear in place; tap a seal and it is recorded,
/// with Undo beside it for a few seconds.
///
/// The rows run in the grid's order, Fajr at the top through Isha, so
/// the eye moves between a column up there and a list down here without
/// having to translate.
struct PathDayCard: View {
    let day: DayCompletion
    /// Whether this is the newest day in the window — the day in
    /// progress, whose blanks may simply not have happened yet.
    let isToday: Bool
    /// Whether a blank on this day counts as a gap.
    let countsBlanks: Bool
    let canStepBack: Bool
    let canStepForward: Bool
    let voluntary: DayVoluntaryDetail?
    let tokens: SkyPaletteTokens
    let editor: PathRecordEditor
    /// The prayer whose seals are showing.
    @Binding var openPrayer: Prayer?
    /// Whether a make-up points at this prayer's record. Such a record
    /// cannot be removed: the make-up would be left answering nothing.
    let isRemovalRefused: (Prayer) -> Bool
    /// -1 is a day earlier, +1 a day later.
    let onStep: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let seals: [PrayerStatus] = [.onTime, .late, .qada, .missed]

    var body: some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
            header

            if let note = dayNote {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(tokens.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 0) {
                ForEach(Array(day.prayerCompletions.enumerated()), id: \.element.prayer) { index, completion in
                    if index > 0 { rule }
                    row(for: completion)
                }
            }

            if let voluntary, !voluntary.isEmpty {
                rule
                voluntaryDetail(voluntary)
            }
        }
        .padding(IhsanSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .celestialPanel(tokens: tokens, cornerRadius: 18)
    }

    private var rule: some View {
        Rectangle()
            .fill(tokens.panelStroke.opacity(0.55))
            .frame(height: IhsanSpacing.hairline)
    }

    // MARK: - Header

    /// The day's name between two arrows. The arrows are the exact way
    /// to a day at the long periods, where a column is too narrow to
    /// land on with any confidence, and the way through a year's week.
    private var header: some View {
        HStack(spacing: 0) {
            stepButton(direction: -1, label: "Earlier day", systemImage: "chevron.left", isEnabled: canStepBack)

            Text(dayTitle)
                .font(.system(.headline, design: .serif, weight: .medium))
                .foregroundStyle(tokens.ink)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)

            stepButton(direction: 1, label: "Later day", systemImage: "chevron.right", isEnabled: canStepForward)
        }
    }

    private func stepButton(
        direction: Int, label: String, systemImage: String, isEnabled: Bool
    ) -> some View {
        Button {
            Haptics.tap()
            onStep(direction)
        } label: {
            Image(systemName: systemImage)
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(isEnabled ? GestaltGrid.overlayMarkValue(for: tokens).color : tokens.inkSecondary.opacity(0.35))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
    }

    private var dayTitle: String {
        let date = day.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        if isToday { return "Today, \(date)" }
        return date
    }

    /// What's unusual about the day as a whole, said once, in words.
    private var dayNote: String? {
        var notes: [String] = []
        if day.isPaused { notes.append("Paused. This day isn’t counted.") }
        if day.isTraveling { notes.append("You were traveling.") }
        if day.needsReview { notes.append("Two entries for one prayer, kept for your review.") }
        return notes.isEmpty ? nil : notes.joined(separator: " ")
    }

    // MARK: - A prayer

    private func row(for completion: PrayerCompletion) -> some View {
        let prayer = completion.prayer
        let isOpen = openPrayer == prayer
        let canUndo = editor.offer?.prayer == prayer && editor.offer?.day == day.date

        return VStack(spacing: IhsanSpacing.sm) {
            HStack(spacing: IhsanSpacing.sm) {
                Button {
                    Haptics.tap()
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                        openPrayer = isOpen ? nil : prayer
                    }
                } label: {
                    HStack(spacing: IhsanSpacing.sm) {
                        GestaltDot(
                            completion: completion,
                            isPausedDay: day.isPaused,
                            isUncounted: completion.status == nil && !countsBlanks,
                            size: 14,
                            tokens: tokens
                        )
                        Text(prayer.displayNameEnglish)
                            .font(IhsanFont.bodyEnglish)
                            .foregroundStyle(tokens.ink)
                        Spacer(minLength: IhsanSpacing.sm)
                        Text(statusText(for: completion))
                            .font(.subheadline)
                            .foregroundStyle(completion.status == nil ? tokens.inkSecondary : tokens.ink)
                            .multilineTextAlignment(.trailing)
                        if !canUndo {
                            Image(systemName: "chevron.down")
                                .font(.system(.caption2, weight: .semibold))
                                .foregroundStyle(tokens.inkSecondary)
                                .rotationEffect(.degrees(isOpen ? 180 : 0))
                                .accessibilityHidden(true)
                        }
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(rowAccessibilityLabel(for: completion))
                .accessibilityHint(completion.status == nil ? "Double-tap to record." : "Double-tap to change.")
                .accessibilityValue(isOpen ? "Open" : "")

                if canUndo {
                    undoButton
                }
            }

            if isOpen {
                editor(for: completion)
                    .padding(.bottom, IhsanSpacing.sm)
                    .transition(reduceMotion ? .identity : .opacity)
            }
        }
    }

    private var undoButton: some View {
        Button {
            Haptics.tap()
            editor.undo()
        } label: {
            Text("Undo")
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(tokens.ink)
                .padding(.horizontal, IhsanSpacing.sm)
                .frame(minHeight: 32)
                .overlay {
                    Capsule().strokeBorder(tokens.metal.opacity(0.55), lineWidth: 0.9)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func statusText(for completion: PrayerCompletion) -> String {
        guard let status = completion.status else {
            if day.isPaused { return "Paused" }
            return isToday ? "Not recorded yet" : "No record"
        }
        let name = status.sentenceName
        return completion.withJamaah && status != .missed
            ? "\(name), in \(IhsanVocabulary.jamaah)"
            : name
    }

    private func rowAccessibilityLabel(for completion: PrayerCompletion) -> String {
        let date = day.date.formatted(.dateTime.weekday(.wide).month(.wide).day())
        return "\(completion.prayer.displayNameEnglish), \(date), \(statusText(for: completion).lowercased())"
    }

    // MARK: - Changing it

    /// The Today card's seals. One tap records and closes; the current
    /// timing carries the gold, and tapping it again just closes.
    private func editor(for completion: PrayerCompletion) -> some View {
        let prayer = completion.prayer
        let close = {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { openPrayer = nil }
        }
        return VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
            TimingSealRow(
                prayer: prayer,
                seals: Self.seals,
                tokens: tokens,
                selected: completion.status
            ) { status in
                if status != completion.status {
                    Haptics.settle()
                    editor.record(status, on: day.date, current: completion)
                }
                close()
            }

            if let status = completion.status {
                HStack(spacing: IhsanSpacing.sm) {
                    // A missed prayer was not offered, so it was not
                    // offered in congregation.
                    if status != .missed {
                        JamaahChip(isOn: completion.withJamaah, tokens: tokens) {
                            Haptics.impact(.light)
                            editor.toggleJamaah(on: day.date, current: completion)
                        }
                    }
                    Spacer(minLength: 0)
                    if !isRemovalRefused(prayer) {
                        Button {
                            Haptics.impact(.light)
                            editor.remove(on: day.date, current: completion)
                            close()
                        } label: {
                            Text("Remove")
                                .font(.footnote)
                                .foregroundStyle(tokens.inkSecondary)
                                .frame(minHeight: 44)
                                .padding(.horizontal, IhsanSpacing.sm)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove record")
                        .accessibilityHint("Clears \(prayer.displayNameEnglish)'s record. Undo stays on offer for a few seconds.")
                    }
                }
            }
        }
    }

    // MARK: - The rest of the day

    /// What the day held beyond its five: named and finished. No
    /// percentage, no total, and nothing carried across days. The
    /// question this answers is "what did I offer that day", and the
    /// honest answer is a list.
    private func voluntaryDetail(_ detail: DayVoluntaryDetail) -> some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
            if !detail.naflKinds.isEmpty {
                VStack(alignment: .leading, spacing: IhsanSpacing.xxs) {
                    Text("Voluntary prayer")
                        .font(IhsanFont.bodyEnglishBold)
                        .foregroundStyle(tokens.ink)
                    Text(detail.naflKinds.map(\.displayNameEnglish).joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundStyle(tokens.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if !detail.sittings.isEmpty {
                VStack(alignment: .leading, spacing: IhsanSpacing.xxs) {
                    Text("Remembrance")
                        .font(IhsanFont.bodyEnglishBold)
                        .foregroundStyle(tokens.ink)
                    ForEach(detail.sittings) { sitting in
                        HStack(alignment: .firstTextBaseline) {
                            Text(sitting.label)
                                .font(.subheadline)
                                .foregroundStyle(tokens.inkSecondary)
                            Spacer(minLength: IhsanSpacing.sm)
                            Text("\(sitting.count)")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(tokens.inkSecondary)
                        }
                    }
                }
            }
        }
        .padding(.top, IhsanSpacing.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(detail.spokenSummary)
    }
}
