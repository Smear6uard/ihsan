import IhsanCore
import IhsanDesignSystem
import SwiftUI

/// Yesterday, in one sheet.
///
/// The retroactive path through Path's grid already works, but it asks
/// a person to know it exists. This is the front door for the one case
/// that actually happens: a day was prayed and never logged.
///
/// Five rows, each closed until touched. An unlogged row opens in place
/// to the same two axes the log sheet uses — jamāʿah as a chip, timing
/// as four chips — and commits the moment a timing is chosen, with the
/// settle haptic. The row closes to its logged state and the next
/// unlogged row opens itself, so the whole day is one tap per prayer
/// after the first. Rows that already carry a log stay closed and are
/// still editable; nothing here overwrites an answer without being
/// asked twice.
///
/// Yesterday is a past day, so all four timings are true things a
/// person can say about it. Nothing is dimmed, and nothing is implied
/// about which of them they ought to pick.
struct YesterdaySheet: View {
    let day: Date
    let rows: [(prayer: Prayer, log: PrayerLog?)]
    let tokens: SkyPaletteTokens
    /// Commits one prayer. Returns after the write so the sheet's rows
    /// re-read from the store rather than guessing.
    let onCommit: (Prayer, PrayerStatus, Bool) -> Void
    /// The all-five shortcut. Nil hides the chip entirely.
    var onCommitAllOnTime: (() -> Void)?
    let onDone: () -> Void

    @State private var expandedPrayer: Prayer?
    @State private var jamaahByPrayer: [Prayer: Bool] = [:]
    @Environment(\.dismiss) private var dismiss

    private var unlogged: [Prayer] {
        rows.filter { $0.log == nil }.map(\.prayer)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
                    header

                    if let onCommitAllOnTime, unlogged.count == Prayer.allCases.count {
                        allFiveChip(action: onCommitAllOnTime)
                    }

                    VStack(spacing: 0) {
                        ForEach(rows, id: \.prayer) { row in
                            prayerRow(row)
                        }
                    }
                    .ihsanIlluminatedPanel(intensity: .regular)
                }
                .padding(IhsanSpacing.md)
            }
            .scrollEdgeEffectStyle(.soft, for: .all)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ihsanManuscriptPage()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDone()
                        dismiss()
                    }
                    .foregroundStyle(tokens.leafGold)
                }
            }
        }
        .presentationDragIndicator(.visible)
        .onAppear { expandedPrayer = unlogged.first }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Yesterday")
                .font(.system(.title2, design: .serif))
                .foregroundStyle(tokens.ink)
            Text(HijriDateFormatter.string(from: day))
                .font(IhsanFont.inscription)
                .tracking(1.4)
                .foregroundStyle(tokens.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// The whole-day shortcut, offered only when nothing at all was
    /// logged — the shape of "I prayed a normal day and never opened
    /// the app". It says exactly what it will write, and every row
    /// stays editable afterwards.
    private func allFiveChip(action: @escaping () -> Void) -> some View {
        Button {
            Haptics.settle()
            action()
            // The day now has answers, so nothing is waiting on the
            // person: close the open row rather than leaving a set of
            // choices hanging under a finished day.
            withAnimation(.snappy(duration: 0.22)) { expandedPrayer = nil }
        } label: {
            HStack(spacing: IhsanSpacing.xs) {
                Text("All five")
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                Text("· ON TIME")
                    .font(IhsanFont.inscription)
                    .tracking(1.2)
            }
            .foregroundStyle(tokens.ink)
            .padding(.horizontal, IhsanSpacing.md)
            .padding(.vertical, IhsanSpacing.sm)
            .frame(maxWidth: .infinity)
            .background(
                Capsule().fill(tokens.panelFill)
            )
            .overlay(
                Capsule().strokeBorder(tokens.metal.opacity(0.5), lineWidth: 1)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log all five prayers on time")
        .accessibilityHint("Each one stays editable afterwards")
    }

    // MARK: - Rows

    @ViewBuilder
    private func prayerRow(_ row: (prayer: Prayer, log: PrayerLog?)) -> some View {
        let isExpanded = expandedPrayer == row.prayer

        VStack(spacing: 0) {
            Divider()
                .frame(height: 0.5)
                .overlay(tokens.panelStroke.opacity(0.55))

            Button {
                Haptics.impact(.light)
                withAnimation(.snappy(duration: 0.22)) {
                    expandedPrayer = isExpanded ? nil : row.prayer
                }
            } label: {
                HStack(spacing: IhsanSpacing.md) {
                    PrayerMarkerOrnament(
                        prayer: row.prayer,
                        size: 22,
                        state: markerState(for: row),
                        tokens: tokens
                    )
                    .frame(width: 26)

                    Text(row.prayer.displayNameEnglish)
                        .font(IhsanFont.rowPrayerName)
                        .foregroundStyle(tokens.ink)

                    Spacer(minLength: IhsanSpacing.xs)

                    Text(stateInscription(for: row))
                        .font(IhsanFont.inscription)
                        .tracking(1.2)
                        // Ink for an answered row, secondary ink for
                        // one still waiting. Gold on the morning panel
                        // measures 2.5:1 and this is text.
                        .foregroundStyle(
                            row.log == nil ? tokens.inkSecondary : tokens.ink
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.horizontal, IhsanSpacing.md)
                .padding(.vertical, IhsanSpacing.sm + 2)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("yesterday-row-\(row.prayer.rawValue)")
            .accessibilityLabel(row.prayer.displayNameEnglish)
            .accessibilityValue(spokenState(for: row))
            .accessibilityHint(isExpanded ? "Closes the choices" : "Opens the choices")

            if isExpanded {
                choices(for: row)
            }
        }
    }

    private func choices(for row: (prayer: Prayer, log: PrayerLog?)) -> some View {
        let jamaah = jamaahByPrayer[row.prayer] ?? (row.log?.withJamaah ?? false)

        return VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
            // The congregation axis, first and separate — it qualifies
            // the timing rather than competing with it.
            Button {
                Haptics.impact(.light)
                jamaahByPrayer[row.prayer] = !jamaah
            } label: {
                HStack(spacing: IhsanSpacing.xs) {
                    Circle()
                        .strokeBorder(
                            jamaah ? tokens.leafGold : tokens.metal.opacity(0.5),
                            lineWidth: jamaah ? 4 : 1
                        )
                        .frame(width: 12, height: 12)
                    Text(IhsanVocabulary.inJamaahTitle)
                        .font(.system(size: 14, weight: .medium, design: .serif))
                }
                .foregroundStyle(tokens.ink)
                .padding(.horizontal, IhsanSpacing.sm)
                .padding(.vertical, 6)
                .background(Capsule().fill(jamaah ? tokens.panelFill : .clear))
                .overlay(Capsule().strokeBorder(tokens.metal.opacity(0.35), lineWidth: 0.75))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(IhsanVocabulary.inJamaahTitle)
            .accessibilityValue(jamaah ? "on" : "off")
            .accessibilityAddTraits(.isToggle)

            // Yesterday is past: every timing is a true thing someone
            // could say about it, so all four are live.
            FlowRow(spacing: IhsanSpacing.xs) {
                timingChip(.onTime, "On Time", for: row, jamaah: jamaah)
                timingChip(.late, "Late", for: row, jamaah: jamaah)
                timingChip(.qada, "Qadā", for: row, jamaah: jamaah)
                timingChip(.missed, "Missed", for: row, jamaah: jamaah)
            }
        }
        .padding(.horizontal, IhsanSpacing.md)
        .padding(.bottom, IhsanSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func timingChip(
        _ status: PrayerStatus,
        _ title: String,
        for row: (prayer: Prayer, log: PrayerLog?),
        jamaah: Bool
    ) -> some View {
        let selected = row.log?.status == status
        return Button {
            Haptics.settle()
            // Missed cannot have been in congregation.
            onCommit(row.prayer, status, status == .missed ? false : jamaah)
            advance(past: row.prayer)
        } label: {
            Text(title)
                .font(.system(size: 15, weight: selected ? .semibold : .regular, design: .serif))
                // The keyline, not lapis: the same deep ultramarine
                // that bounds a gilded ornament, and the pairing that
                // already holds AA on leaf gold in every phase.
                .foregroundStyle(selected ? tokens.keyline : tokens.ink)
                .padding(.horizontal, IhsanSpacing.sm + 2)
                .padding(.vertical, 8)
                .background(Capsule().fill(selected ? tokens.leafGold : tokens.panelFill))
                .overlay(
                    Capsule().strokeBorder(
                        selected ? tokens.keyline.opacity(0.6) : tokens.metal.opacity(0.4),
                        lineWidth: selected ? 0.75 : 1
                    )
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(row.prayer.displayNameEnglish), \(title)")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    /// After a commit, open the next row that still has no answer. When
    /// there is none, close up: the day is done and the sheet should
    /// not keep asking.
    private func advance(past prayer: Prayer) {
        let remaining = rows
            .filter { $0.log == nil && $0.prayer != prayer }
            .map(\.prayer)
        withAnimation(.snappy(duration: 0.22)) {
            expandedPrayer = remaining.first
        }
    }

    // MARK: - State language

    private func markerState(
        for row: (prayer: Prayer, log: PrayerLog?)
    ) -> PrayerMarkerState {
        guard let status = row.log?.status else { return .passedUnlogged }
        return status == .missed ? .passedUnlogged : .logged
    }

    private func stateInscription(
        for row: (prayer: Prayer, log: PrayerLog?)
    ) -> String {
        guard let status = row.log?.status else { return "NOT LOGGED" }
        let base: String
        switch status {
        case .onTime: base = "ON TIME"
        case .late: base = "LATE"
        case .qada: base = "MADE UP"
        case .missed: base = "MISSED"
        }
        return row.log?.withJamaah == true ? "\(base) · JAMĀʿAH" : base
    }

    private func spokenState(for row: (prayer: Prayer, log: PrayerLog?)) -> String {
        guard let status = row.log?.status else { return "not logged" }
        let base: String
        switch status {
        case .onTime: base = "on time"
        case .late: base = "late"
        case .qada: base = "made up"
        case .missed: base = "missed"
        }
        return row.log?.withJamaah == true ? "\(base), in congregation" : base
    }
}

/// Chips that wrap rather than shrink.
///
/// Four timing chips fit one line at default type and cannot at
/// accessibility sizes; an HStack would squeeze them until the words
/// broke. This lets them flow onto as many lines as they need, which
/// is the only behaviour that keeps every choice readable.
struct FlowRow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + lineHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(size)
            )
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
