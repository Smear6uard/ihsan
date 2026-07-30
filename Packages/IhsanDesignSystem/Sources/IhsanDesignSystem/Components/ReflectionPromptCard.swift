import SwiftUI

/// Glass card carrying a daily reflection prompt and its citation. The
/// optional `Begin` action surfaces as a capsule button when supplied —
/// when omitted, the card renders as a passive prompt suitable for
/// archive views.
public struct ReflectionPromptCard: View {
    public let prompt: String
    public let citation: String
    public var onBegin: (() -> Void)?

    public init(
        prompt: String,
        citation: String,
        onBegin: (() -> Void)? = nil
    ) {
        self.prompt = prompt
        self.citation = citation
        self.onBegin = onBegin
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.md) {
            Text("DAILY REFLECTION")
                .font(IhsanFont.smallCaps)
                .foregroundStyle(IhsanColor.textMuted)
                .tracking(1.2)

            Text(prompt)
                .font(IhsanFont.subtitle)
                .foregroundStyle(IhsanColor.textPrimary)
                .italic()
                .fixedSize(horizontal: false, vertical: true)

            Text(citation)
                .font(IhsanFont.citation)
                .foregroundStyle(IhsanColor.textMuted)

            if let onBegin {
                Button(action: onBegin) {
                    HStack(spacing: IhsanSpacing.sm) {
                        Image(systemName: "pencil")
                        Text("Begin")
                            .font(IhsanFont.bodyEnglishBold)
                    }
                    .foregroundStyle(IhsanColor.textPrimary)
                    .padding(.vertical, IhsanSpacing.sm)
                    .padding(.horizontal, IhsanSpacing.lg)
                    .background {
                        Capsule(style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Begin reflection")
            }
        }
        .padding(IhsanSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ihsanGlass(intensity: .regular)
    }
}

#Preview("Reflection prompt card") {
    ReflectionPromptCard(
        prompt: "Looking back at your day — what helped you turn toward Allah, and what pulled you away?",
        citation: "— al-Ghazali, Ihya 'Ulum al-Din, Book 38",
        onBegin: {}
    )
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .ihsanManuscriptPage()
}
