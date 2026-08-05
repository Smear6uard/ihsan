import IhsanCore
import IhsanDesignSystem
import IhsanPrayerTimes
import SwiftUI

/// One time-aware remembrance set, followed by the quiet actions that
/// belong to an occasion rather than a clock.
struct RemembranceSheet: View {
    let entries: [RemembranceMenu.Entry]
    let timeZone: TimeZone
    let tokens: SkyPaletteTokens
    let onSelect: (RemembranceMenu.Entry.Destination) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: IhsanSpacing.md) {
                header

                if let featured = entries.first(where: \.isFeatured) {
                    featuredRow(featured)
                        .padding(.horizontal, IhsanSpacing.md)
                }

                let supporting = entries.filter { !$0.isFeatured }
                if !supporting.isEmpty {
                    supportingRows(supporting)
                }
            }
            .padding(.bottom, IhsanSpacing.lg)
            .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { height in
                contentHeight = height
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .background { tokens.sheetBacking.ignoresSafeArea() }
        .presentationDetents([.height(contentHeight > 0 ? contentHeight + 12 : 420)])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
    }

    private var header: some View {
        VStack(spacing: IhsanSpacing.xs) {
            Text("REMEMBRANCE")
                .font(IhsanFont.inscription)
                .tracking(2.4)
                .foregroundStyle(tokens.inkSecondary)
            Text(headerSubtitle)
                .font(IhsanFont.bodyEnglish)
                .foregroundStyle(tokens.ink.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, IhsanSpacing.lg)
        .padding(.bottom, IhsanSpacing.sm)
        .accessibilityElement(children: .combine)
    }

    private var headerSubtitle: String {
        if entries.contains(where: \.isFeatured) {
            return "For this moment"
        }
        if entries.contains(where: { $0.destination == .set(.sleep) && $0.isCurrent }) {
            return "For the quiet of night"
        }
        return "For prayer and quiet counting"
    }

    private func supportingRows(_ supporting: [RemembranceMenu.Entry]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ALSO AVAILABLE")
                .font(IhsanFont.inscription)
                .tracking(1.8)
                .foregroundStyle(tokens.inkSecondary)
                .padding(.horizontal, IhsanSpacing.md)
                .padding(.bottom, IhsanSpacing.sm)

            VStack(spacing: 0) {
                ForEach(Array(supporting.enumerated()), id: \.element.id) { index, entry in
                    row(entry)
                    if index < supporting.count - 1 {
                        Rectangle()
                            .fill(tokens.panelStroke.opacity(0.6))
                            .frame(height: IhsanSpacing.hairline)
                            .padding(.leading, IhsanSpacing.xxl)
                    }
                }
            }
            .ihsanGlass(
                in: RoundedRectangle(
                    cornerRadius: IhsanSpacing.cardRadius,
                    style: .continuous
                ),
                intensity: .subtle,
                isClear: true
            )
            .padding(.horizontal, IhsanSpacing.md)
        }
    }

    private func featuredRow(_ entry: RemembranceMenu.Entry) -> some View {
        Button {
            select(entry)
        } label: {
            HStack(spacing: IhsanSpacing.md) {
                SequenceMark(state: .current, tokens: tokens)

                VStack(alignment: .leading, spacing: IhsanSpacing.xs) {
                    Text("NOW")
                        .font(IhsanFont.inscription)
                        .tracking(1.8)
                        .foregroundStyle(tokens.metal)
                    Text(entry.title)
                        .font(IhsanFont.heroPrayerName)
                        .foregroundStyle(tokens.ink)
                    if let inscription = windowInscription(entry, showsNow: false) {
                        Text(inscription)
                            .font(IhsanFont.inscription)
                            .tracking(1.2)
                            .monospacedDigit()
                            .foregroundStyle(tokens.inkSecondary)
                    }
                }

                Spacer(minLength: IhsanSpacing.sm)

                Image(systemName: "arrow.up.right")
                    .font(IhsanFont.bodyEnglishBold)
                    .foregroundStyle(tokens.metal)
            }
            .padding(IhsanSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .ihsanGlass(
            in: RoundedRectangle(cornerRadius: IhsanSpacing.cardRadius, style: .continuous),
            intensity: .hero,
            isActive: true,
            isInteractive: true,
            isClear: true
        )
        .accessibilityLabel(spokenLabel(entry))
        .accessibilityHint("Double-tap to begin.")
    }

    private func row(_ entry: RemembranceMenu.Entry) -> some View {
        Button {
            select(entry)
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

                Image(systemName: "chevron.right")
                    .font(IhsanFont.inscription)
                    .foregroundStyle(tokens.inkSecondary)
            }
            .padding(.horizontal, IhsanSpacing.md)
            .padding(.vertical, IhsanSpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(spokenLabel(entry))
        .accessibilityHint("Double-tap to begin.")
    }

    private func select(_ entry: RemembranceMenu.Entry) {
        Haptics.impact(.soft)
        onSelect(entry.destination)
        dismiss()
    }

    private func windowInscription(
        _ entry: RemembranceMenu.Entry,
        showsNow: Bool = true
    ) -> String? {
        guard let window = entry.window else { return nil }
        if entry.isCurrent, showsNow { return "NOW" }
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.timeZone = timeZone
        return "\(window.start.formatted(style)) - \(window.end.formatted(style))"
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
