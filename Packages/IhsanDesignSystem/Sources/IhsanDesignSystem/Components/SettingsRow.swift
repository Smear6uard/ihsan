import SwiftUI

/// One settings row rendered as a manuscript-style inscription:
/// title in refined serif on the left, optional subtitle / value in
/// small caps brass on the right (or beneath the title), and a
/// trailing accessory (chevron, toggle, or custom). Rows live inside
/// a `SettingsSectionCard` and are separated by thin brass hairlines
/// — they DO NOT carry their own panel borders, so the section
/// reads as one composed surface.
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
        VStack(spacing: 0) {
            Divider()
                .frame(height: 0.5)
                .overlay(IhsanColor.brass.opacity(0.20))

            Group {
                if let action {
                    Button(action: action) { rowContent }
                        .buttonStyle(.plain)
                } else {
                    rowContent
                }
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
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(IhsanColor.brassDark)
                    .frame(width: 22)
            }
            Text(title)
                .font(.system(size: 17, weight: .regular, design: .serif))
                .foregroundStyle(IhsanColor.inkDeep)
            Spacer(minLength: IhsanSpacing.sm)
            if let subtitle {
                Text(subtitle.uppercased())
                    .font(IhsanFont.inscription)
                    .tracking(1.4)
                    .foregroundStyle(IhsanColor.brassDark.opacity(0.85))
            }
            accessory
        }
        .padding(.horizontal, IhsanSpacing.md)
        .padding(.vertical, IhsanSpacing.sm + 2)
        .frame(minHeight: 44)
    }

    private var accessibilityLabel: String {
        if let subtitle { return "\(title), \(subtitle)" }
        return title
    }
}

public extension SettingsRow where Accessory == AnyView {
    /// Convenience initializer that renders a brass chevron when no
    /// accessory is supplied. Standard for navigation rows.
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
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(IhsanColor.brassDark.opacity(0.55))
            )
        }
    }
}

private struct SettingsRowPreviewWrapper: View {
    @State private var notifications = true

    var body: some View {
        VStack(spacing: IhsanSpacing.lg) {
            SettingsSectionCard("Location & Times") {
                SettingsRow(title: "Oakland, CA", icon: "location.fill", action: {})
                SettingsRow(title: "Method", subtitle: "ISNA", action: {})
                SettingsRow(title: "Madhhab (Asr)", subtitle: "Standard", action: {})
            }
            SettingsSectionCard("Adhan") {
                SettingsRow(title: "Fajr", subtitle: "Makkah · Soft", action: {})
                SettingsRow(title: "Dhuhr", subtitle: "Off", action: {})
                SettingsRow(title: "Asr", subtitle: "Off", action: {})
            }
            SettingsSectionCard("Practice") {
                SettingsRow(title: "Adhan reminders", icon: "bell.fill") {
                    Toggle("", isOn: $notifications)
                        .labelsHidden()
                        .tint(IhsanColor.brass)
                }
            }
        }
        .padding()
    }
}

#Preview("Settings rows") {
    ScrollView {
        SettingsRowPreviewWrapper()
    }
    .ihsanManuscriptPage()
}
