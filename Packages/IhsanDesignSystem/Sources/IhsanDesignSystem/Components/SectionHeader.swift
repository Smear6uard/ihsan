import SwiftUI

/// Small caps section label. Renders as uppercase tracked text in the
/// muted text tier — quiet by design so the content beneath it carries
/// the visual weight.
public struct SectionHeader: View {
    public let title: String

    public init(_ title: String) {
        self.title = title
    }

    public var body: some View {
        Text(title.uppercased())
            .font(IhsanFont.smallCaps)
            .tracking(1.2)
            .foregroundStyle(IhsanColor.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, IhsanSpacing.md)
            .padding(.vertical, IhsanSpacing.sm)
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview("Section header") {
    VStack(spacing: 0) {
        SectionHeader("Location")
        SectionHeader("Calculation")
        SectionHeader("Notifications")
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .ihsanBackground()
}
