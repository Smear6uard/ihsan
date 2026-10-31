import IhsanCore
import SwiftUI

/// The switch for a page that sits in the window, drawn from the page's
/// own tokens instead of the system's.
///
/// The window's color scheme follows the sky so the status bar can be
/// read by day, and a system switch draws itself from the window's
/// traits rather than SwiftUI's environment: by day its off track went
/// white on Set's near-white cards. This one takes its off track and
/// outline from `inkSecondary`, so it reads on every ground, and its
/// on track from the caller's `.tint`. VoiceOver is handed a real
/// `Toggle` through `accessibilityRepresentation`, so it is announced
/// and operated exactly as the system switch was.
///
/// Presentations keep the system switch: they pin `.dark` and are
/// unaffected.
public struct IhsanSwitchToggleStyle: ToggleStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        IhsanSwitch(configuration: configuration)
    }

    /// The off track's fill and outline, as fractions of `inkSecondary`
    /// over the panel. The outline is what carries the shape: pinned by
    /// `SwitchContrastTests` at the 3:1 non-text contrast minimum.
    public static let offFill: Double = 0.14
    public static let offOutline: Double = 0.62
    public static let size = CGSize(width: 51, height: 31)
}

private struct IhsanSwitch: View {
    let configuration: ToggleStyleConfiguration

    @Environment(\.timeOfDayOverride) private var override
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let tokens = IhsanPageChrome.tokens(at: override ?? NowProvider.active.now())
        let isOn = configuration.isOn
        Button {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) {
                configuration.isOn.toggle()
            }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn
                        ? AnyShapeStyle(.tint)
                        : AnyShapeStyle(tokens.inkSecondary.opacity(IhsanSwitchToggleStyle.offFill)))
                Capsule()
                    .strokeBorder(
                        tokens.inkSecondary.opacity(isOn ? 0 : IhsanSwitchToggleStyle.offOutline),
                        lineWidth: 1
                    )
                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
                    .padding(2)
            }
            .frame(width: IhsanSwitchToggleStyle.size.width, height: IhsanSwitchToggleStyle.size.height)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
        }
    }
}
