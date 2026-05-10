import SwiftUI

/// Standard Settings section container: a GlassCard with a SectionHeader and
/// vertically-stacked SettingsRow content.
public struct SettingsSectionCard<Content: View>: View {
    public let title: String
    public let content: Content

    public init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        GlassCard {
            VStack(spacing: IhsanSpacing.sm) {
                SectionHeader(title)
                content
            }
        }
    }
}
