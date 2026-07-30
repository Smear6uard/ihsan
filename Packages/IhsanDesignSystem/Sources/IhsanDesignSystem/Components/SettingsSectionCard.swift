import SwiftUI

/// One settings section as an illuminated parchment panel.
///
/// Header is rendered at the top in small-caps brass; rows stack
/// beneath with thin brass dividers between them so the whole
/// section reads as a chapter on the manuscript page rather than
/// as a list of independent cards.
public struct SettingsSectionCard<Content: View>: View {
    public let title: String
    public let content: Content

    public init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: IhsanSpacing.md) {
            SectionHeader(title)
                .padding(.horizontal, IhsanSpacing.md)
                .padding(.top, IhsanSpacing.sm)

            VStack(spacing: 0) {
                content
            }
            .padding(.bottom, IhsanSpacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .ihsanIlluminatedPanel(intensity: .regular)
    }
}

#Preview("Settings section") {
    ScrollView {
        VStack(spacing: IhsanSpacing.lg) {
            SettingsSectionCard("Location & Times") {
                SettingsRow(title: "Oakland, CA", subtitle: nil, glyph: .location, action: {})
                SettingsRow(title: "Method", subtitle: "ISNA", action: {})
                SettingsRow(title: "Madhhab (Asr)", subtitle: "Standard", action: {})
            }
        }
        .padding()
    }
    .ihsanManuscriptPage()
}
