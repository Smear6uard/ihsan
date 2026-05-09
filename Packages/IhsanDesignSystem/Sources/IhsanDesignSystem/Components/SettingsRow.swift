import SwiftUI

/// iOS-grouped-list-style row, rendered in Liquid Glass. Use a column of
/// these inside a `VStack` (with no spacing) to recreate the grouped-list
/// aesthetic without falling back to `List` styling that fights the dark
/// ground.
///
/// Generic over the trailing accessory so callers can pass a `Toggle`,
/// `Text`, chevron, or any custom view without forcing one shape.
public struct SettingsRow<Accessory: View>: View {
    public let title: String
    public let subtitle: String?
    public let icon: String?
    public let accessory: Accessory
    public let action: (() -> Void)?

    public init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        action: (() -> Void)? = nil,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.action = action
        self.accessory = accessory()
    }

    public var body: some View {
        Group {
            if let action {
                Button(action: action) { rowContent }
                    .buttonStyle(.plain)
            } else {
                rowContent
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(action != nil ? .isButton : [])
    }

    private var rowContent: some View {
        HStack(spacing: IhsanSpacing.md) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(IhsanColor.textSecondary)
                    .frame(width: 24)
            }
            VStack(alignment: .leading, spacing: IhsanSpacing.xxs) {
                Text(title)
                    .font(IhsanFont.bodyEnglish)
                    .foregroundStyle(IhsanColor.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(IhsanFont.citation)
                        .foregroundStyle(IhsanColor.textMuted)
                }
            }
            Spacer(minLength: IhsanSpacing.sm)
            accessory
        }
        .padding(.horizontal, IhsanSpacing.md)
        .padding(.vertical, IhsanSpacing.sm + IhsanSpacing.xxs)
        .frame(minHeight: 44)
        .ihsanGlass(
            in: RoundedRectangle(
                cornerRadius: IhsanSpacing.smallCardRadius,
                style: .continuous
            ),
            intensity: .subtle
        )
    }

    private var accessibilityLabel: String {
        if let subtitle { return "\(title), \(subtitle)" }
        return title
    }
}

public extension SettingsRow where Accessory == AnyView {
    /// Convenience initializer that renders a chevron when no accessory is
    /// supplied. Standard for navigation rows.
    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        action: @escaping () -> Void
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            icon: icon,
            action: action
        ) {
            AnyView(
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(IhsanColor.textMuted)
            )
        }
    }
}

private struct SettingsRowPreviewWrapper: View {
    @State private var notifications = true

    var body: some View {
        VStack(spacing: IhsanSpacing.sm) {
            SectionHeader("Location")
            SettingsRow(
                title: "Mecca",
                subtitle: "Auto-detected",
                icon: "location.fill",
                action: {}
            )
            SectionHeader("Calculation")
            SettingsRow(
                title: "Method",
                subtitle: "Umm al-Qura",
                icon: "function",
                action: {}
            )
            SettingsRow(
                title: "Madhab",
                subtitle: "Standard",
                icon: "book.closed.fill",
                action: {}
            )
            SectionHeader("Notifications")
            SettingsRow(
                title: "Adhan reminders",
                icon: "bell.fill"
            ) {
                Toggle("", isOn: $notifications)
                    .labelsHidden()
                    .tint(IhsanColor.textPrimary)
            }
        }
        .padding()
    }
}

#Preview("Settings rows") {
    ScrollView {
        SettingsRowPreviewWrapper()
    }
    .ihsanBackground()
}
