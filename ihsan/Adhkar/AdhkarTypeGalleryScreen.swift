#if DEBUG
import IhsanCore
import IhsanDesignSystem
import SwiftUI

/// The Arabic typography gate, on device.
///
/// `-IhsanDebugAdhkarTypeGallery` opens it. The maintainer walks the
/// five grounds at three Dynamic Type sizes and judges the Arabic at
/// arm's length, the way every other surface here is judged. DEBUG
/// only — this is a review instrument, not a feature.
struct AdhkarTypeGalleryScreen: View {
    let onDismiss: () -> Void

    /// `-IhsanDebugAdhkarGround night|dawn|morning|afternoon|sunset`
    /// picks the ground so the capture script can take one frame each
    /// without anyone tapping through the page. The TYPE SIZE comes
    /// from the device — pass
    /// `-UIPreferredContentSizeCategoryName UICTContentSizeCategory…`
    /// to drive it, or just change it in Settings.
    @State private var state: PaletteState = {
        guard let raw = DebugLaunch.value(after: "-IhsanDebugAdhkarGround"),
              let parsed = PaletteState(rawValue: raw)
        else { return .morning }
        return parsed
    }()

    var body: some View {
        let tokens = PaletteState.resolved(for: SkyPhase.fixed(state))

        ZStack(alignment: .top) {
            AdhkarTypeGallery(state: state)

            HStack(spacing: IhsanSpacing.sm) {
                ForEach(PaletteState.allCases, id: \.self) { candidate in
                    Button {
                        state = candidate
                    } label: {
                        Text(candidate.displayName.prefix(2).uppercased())
                            .font(IhsanFont.inscription)
                            .tracking(1.2)
                            .foregroundStyle(
                                candidate == state ? tokens.ink : tokens.inkSecondary
                            )
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button("Close", action: onDismiss)
                    .font(IhsanFont.inscription)
                    .tracking(1.2)
                    .foregroundStyle(tokens.inkSecondary)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, IhsanSpacing.md)
            .padding(.top, IhsanSpacing.xs)
            .background(.ultraThinMaterial)
        }
    }
}
#endif
