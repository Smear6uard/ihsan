import IhsanCore
import IhsanDesignSystem
import IhsanPrayerTimes
import SwiftUI

/// The hub the band opens: every remembrance set, plus the instrument,
/// in the day's own order.
///
/// Each set that has a window today inscribes it, so the sheet keeps
/// teaching when a set belongs — and the one whose window is open right
/// now is marked. What it does not do is *gate* on any of that. Every
/// row is live at every hour. See `RemembranceMenu` for why.
struct RemembranceSheet: View {
    let entries: [RemembranceMenu.Entry]
    let timeZone: TimeZone
    let tokens: SkyPaletteTokens
    /// Records the chosen destination and closes. The caller applies it
    /// after dismissal — a full-screen reader presented from inside a
    /// dismissing sheet is a race.
    let onSelect: (RemembranceMenu.Entry.Destination) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    // The instrument is a different kind of thing from a
                    // set — nothing to read, only counting — so a rule
                    // separates it rather than a heading nobody needs.
                    if entry.destination == .freeTasbih, index > 0 {
                        OrnamentalDivider(tint: tokens.metal, opacity: 0.4)
                            .padding(.horizontal, IhsanSpacing.md)
                            .padding(.vertical, IhsanSpacing.sm)
                    }
                    row(entry)
                }
            }
            .padding(.bottom, IhsanSpacing.md)
            .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { height in
                contentHeight = height
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .background { tokens.sheetBacking.ignoresSafeArea() }
        .presentationDetents([.height(contentHeight > 0 ? contentHeight + 12 : 420)])
        .presentationDragIndicator(.visible)
        .presentationBackground(.thinMaterial)
    }

    private var header: some View {
        VStack(spacing: IhsanSpacing.xs) {
            Text("REMEMBRANCE")
                .font(IhsanFont.inscription)
                .tracking(2.4)
                .foregroundStyle(tokens.inkSecondary)
            Text("Any set, any time")
                .font(IhsanFont.bodyEnglish)
                .foregroundStyle(tokens.ink.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, IhsanSpacing.lg)
        .padding(.bottom, IhsanSpacing.md)
        .accessibilityElement(children: .combine)
    }

    private func row(_ entry: RemembranceMenu.Entry) -> some View {
        Button {
            Haptics.impact(.soft)
            onSelect(entry.destination)
            dismiss()
        } label: {
            HStack(spacing: IhsanSpacing.sm) {
                SequenceMark(
                    state: entry.isCurrent ? .current : .pending,
                    tokens: tokens
                )

                Text(entry.title)
                    .font(IhsanFont.bodyEnglish)
                    .foregroundStyle(tokens.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: IhsanSpacing.sm)

                if let inscription = windowInscription(entry) {
                    Text(inscription)
                        .font(IhsanFont.inscription)
                        .tracking(1.1)
                        .monospacedDigit()
                        .foregroundStyle(tokens.inkSecondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .celestialPanel(
            tokens: tokens,
            cornerRadius: IhsanSpacing.smallCardRadius,
            isActive: entry.isCurrent
        )
        .padding(.horizontal, IhsanSpacing.md)
        .padding(.vertical, 3)
        .accessibilityLabel(spokenLabel(entry))
        .accessibilityHint("Double-tap to begin.")
    }

    /// "NOW" beats a clock range for the set whose window is open: the
    /// row is already marked, and repeating the hours the person is
    /// currently inside says nothing.
    private func windowInscription(_ entry: RemembranceMenu.Entry) -> String? {
        guard let window = entry.window else { return nil }
        if entry.isCurrent { return "NOW" }
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.timeZone = timeZone
        return "\(window.start.formatted(style)) – \(window.end.formatted(style))"
            .uppercased()
    }

    private func spokenLabel(_ entry: RemembranceMenu.Entry) -> String {
        var parts = [entry.title]
        if entry.isCurrent {
            parts.append("its window is open now")
        } else if let inscription = windowInscription(entry) {
            parts.append("window \(inscription.lowercased())")
        }
        return parts.joined(separator: ", ")
    }
}
