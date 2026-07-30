import SwiftUI
import IhsanDesignSystem

/// Centered, contemplative empty state shown when no reflections have
/// been saved yet. The framing copy is loaded from FiqhConfig so it
/// stays consistent with the rest of the app's spiritual register.
struct ReflectionEmptyState: View {
    let title: String
    let subtitle: String
    let tokens: SkyPaletteTokens

    var body: some View {
        VStack(spacing: IhsanSpacing.md) {
            FourPointedStar()
                .fill(tokens.metal.opacity(0.70))
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            Text(title)
                .font(.system(size: 22, weight: .medium, design: .serif).italic())
                .foregroundStyle(tokens.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(IhsanFont.bodyEnglish)
                .foregroundStyle(tokens.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, IhsanSpacing.lg)
        }
        .padding(IhsanSpacing.xl)
        .frame(maxWidth: .infinity)
        .ihsanIlluminatedPanel(intensity: .regular)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }
}

#Preview("Empty state") {
    ReflectionEmptyState(
        title: "Begin your record.",
        subtitle: "Today's prompt is above. Write or speak whatever comes to mind. Past entries appear here.",
        tokens: PaletteState.afternoon.tokens
    )
    .padding(IhsanSpacing.md)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .ihsanManuscriptPage()
}
