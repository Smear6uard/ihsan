import SwiftUI

/// Small caps section label rendered in the manuscript register —
/// uppercase, brass-tinted, letter-spaced. Sits above the content
/// inside a `SettingsSectionCard` or as the first child of any
/// manuscript-style section.
public struct SectionHeader: View {
    public let title: String

    public init(_ title: String) {
        self.title = title
    }

    public var body: some View {
        Text(title.uppercased())
            .font(IhsanFont.inscription)
            .tracking(1.8)
            .foregroundStyle(IhsanColor.brassDark)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview("Section header") {
    VStack(alignment: .leading, spacing: IhsanSpacing.md) {
        SectionHeader("Location & Times")
        SectionHeader("Adhan")
        SectionHeader("Practice")
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .ihsanManuscriptPage()
}
