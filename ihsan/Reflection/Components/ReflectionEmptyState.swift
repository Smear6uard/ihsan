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
            FourPointedStar()
                .fill(IhsanColor.brass.opacity(0.55))
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            Text(title)
                .font(.system(size: 22, weight: .medium, design: .serif).italic())
                .foregroundStyle(IhsanColor.inkDeep)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(IhsanFont.bodyEnglish)
                .foregroundStyle(IhsanColor.inkDeep.opacity(0.72))
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
        subtitle: "Today's prompt is above. Write or speak whatever comes to mind. Past entries appear here."
    )
    .padding(IhsanSpacing.md)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .ihsanManuscriptPage()
}
