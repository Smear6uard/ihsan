import SwiftUI

/// Prose block for explanatory copy inside SettingsSectionCard.
public struct SettingsDescriptionText: View {
    public let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(IhsanFont.bodyEnglish)
            .foregroundStyle(IhsanColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, IhsanSpacing.md)
            .padding(.vertical, IhsanSpacing.sm)
            .accessibilityLabel(text)
    }
}
