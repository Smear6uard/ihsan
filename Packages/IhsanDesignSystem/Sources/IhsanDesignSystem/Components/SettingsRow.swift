import IhsanCore
import SwiftUI

/// One settings row: title in refined serif, optional small-caps
/// value, an optional engraved `SettingsGlyph` on the left, and a
/// trailing accessory (chevron, toggle, or custom). Rows live inside
/// a `SettingsSectionCard` and are separated by hairlines — they DO
/// NOT carry their own panel borders, so the section reads as one
/// composed surface.
///
/// Ink resolves from the page's clock-derived tokens (pinned by
/// `timeOfDayOverride` for previews and screenshot runs), so the row
/// repaints with the ground beneath it.
public struct SettingsRow<Accessory: View>: View {
    public let title: String
    public let subtitle: String?
    public let glyph: SettingsGlyph?
    public let accessory: Accessory
    public let action: (() -> Void)?

    @Environment(\.timeOfDayOverride) private var override

    public init(
        title: String,
        subtitle: String? = nil,
        glyph: SettingsGlyph? = nil,
        action: (() -> Void)? = nil,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.subtitle = subtitle
        self.glyph = glyph
        self.action = action
        self.accessory = accessory()
    }

    public var body: some View {
        let tokens = IhsanPageChrome.tokens(at: override ?? NowProvider.active.now())
        VStack(spacing: 0) {
            Divider()
                .frame(height: 0.5)
                .overlay(tokens.panelStroke.opacity(0.55))

            Group {
                if let action {
                    Button(action: action) { rowContent(tokens: tokens) }
                        .buttonStyle(.plain)
                } else {
                    rowContent(tokens: tokens)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(action != nil ? .isButton : [])
    }

    private func rowContent(tokens: SkyPaletteTokens) -> some View {
        HStack(spacing: IhsanSpacing.md) {
            if let glyph {
                SettingsGlyphView(glyph, color: tokens.metal.opacity(0.9))
                    .frame(width: 18, height: 18)
                    .frame(width: 22)
            }
            Text(title)
                .font(.system(size: 17, weight: .regular, design: .serif))
                .foregroundStyle(tokens.ink)
            Spacer(minLength: IhsanSpacing.sm)
            if let subtitle {
                Text(subtitle.uppercased())
                    .font(IhsanFont.inscription)
                    .tracking(1.4)
                    .foregroundStyle(tokens.inkSecondary)
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
    /// Convenience initializer that renders a quiet chevron when no
    /// accessory is supplied. Standard for navigation rows.
    init(
        title: String,
        subtitle: String? = nil,
        glyph: SettingsGlyph? = nil,
        action: @escaping () -> Void
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            glyph: glyph,
            action: action
        ) {
            AnyView(SettingsRowChevron())
        }
    }
}

/// The navigation chevron in the engraved language — a single bent
/// line, not a symbol.
public struct SettingsRowChevron: View {
    @Environment(\.timeOfDayOverride) private var override

    public init() {}

    public var body: some View {
        let tokens = IhsanPageChrome.tokens(at: override ?? NowProvider.active.now())
        ChevronLine()
            .stroke(
                tokens.inkSecondary.opacity(0.6),
                style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round)
            )
            .frame(width: 7, height: 12)
            .accessibilityHidden(true)
    }

    private struct ChevronLine: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            return p
        }
    }
}

/// The selection ring for option pickers: an engraved ring, filled
/// with the gilded dot when chosen — never a checkmark symbol.
public struct SettingsSelectionRing: View {
    public let isSelected: Bool

    @Environment(\.timeOfDayOverride) private var override

    public init(isSelected: Bool) {
        self.isSelected = isSelected
    }

    public var body: some View {
        let tokens = IhsanPageChrome.tokens(at: override ?? NowProvider.active.now())
        ZStack {
            Circle()
                .strokeBorder(
                    isSelected ? tokens.leafGold : tokens.panelStroke,
                    lineWidth: isSelected ? 1.4 : 1.0
                )
            if isSelected {
                Circle()
                    .fill(tokens.leafGold)
                    .padding(4.5)
                Circle()
                    .strokeBorder(tokens.keyline.opacity(0.6), lineWidth: 0.6)
                    .padding(4.5)
            }
        }
        .frame(width: 18, height: 18)
        .accessibilityHidden(true)
    }
}

private struct SettingsRowPreviewWrapper: View {
    @State private var notifications = true

    var body: some View {
        VStack(spacing: IhsanSpacing.lg) {
            SettingsSectionCard("Location & Times") {
                SettingsRow(title: "Oakland, CA", glyph: .location, action: {})
                SettingsRow(title: "Method", subtitle: "ISNA", glyph: .method, action: {})
                SettingsRow(title: "Madhhab (Asr)", subtitle: "Standard", glyph: .asrShadow, action: {})
            }
            SettingsSectionCard("Practice") {
                SettingsRow(title: "Adhan reminders", glyph: .adhan) {
                    Toggle("", isOn: $notifications)
                        .labelsHidden()
                        .tint(PaletteState.afternoon.tokens.leafGold)
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
