import SwiftUI
import IhsanDesignSystem

/// Centered, contemplative empty state shown when no reflections have
/// been saved yet. The framing copy is loaded from FiqhConfig so it
/// stays consistent with the rest of the app's spiritual register.
struct ReflectionEmptyState: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: IhsanSpacing.md) {
            // A simple drawn glyph — a thin crescent + asterisk-like sparkle —
            // gives the empty state a more contemplative feel than a
            // generic "no entries" icon would.
            CrescentMark()
                .frame(width: 48, height: 48)
                .foregroundStyle(IhsanColor.statusQada)
                .accessibilityHidden(true)

            Text(title)
                .font(IhsanFont.subtitle)
                .italic()
                .foregroundStyle(IhsanColor.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(IhsanFont.bodyEnglish)
                .foregroundStyle(IhsanColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, IhsanSpacing.lg)
        }
        .padding(IhsanSpacing.lg)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }
}

/// Minimalist crescent glyph drawn as the difference of two circles.
/// Looks intentional rather than generic — and matches the brass
/// accent color used elsewhere in the design system.
private struct CrescentMark: View {
    var body: some View {
        Canvas { context, size in
            let outer = Path(
                ellipseIn: CGRect(
                    x: 2, y: 2,
                    width: size.width - 4, height: size.height - 4
                )
            )
            let inset: CGFloat = 6
            let inner = Path(
                ellipseIn: CGRect(
                    x: 2 + inset, y: 2,
                    width: size.width - 4, height: size.height - 4
                )
            )
            context.clip(to: outer)
            context.blendMode = .destinationOut
            context.fill(outer, with: .color(.white))
            context.blendMode = .normal
            context.fill(outer, with: .color(.white.opacity(0.85)))
            context.blendMode = .destinationOut
            context.fill(inner, with: .color(.white))
        }
    }
}

#Preview("Empty state") {
    ReflectionEmptyState(
        title: "Begin your record.",
        subtitle: "Today's prompt is above. Write or speak whatever comes to mind. Past entries appear here."
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .ihsanBackground()
}
