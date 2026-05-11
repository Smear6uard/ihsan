import SwiftUI
import IhsanDesignSystem

/// The full-screen celestial reference overlay — opened from the
/// Today header's moon-phase glyph. Hosts the qibla compass, sun /
/// moon detail panels, and the close affordance.
///
/// The compass and detail panels themselves are implemented in
/// `Phase 6`; this entry struct defines the surface, the title and
/// inscription block, and the dismissal flow so the Today header's
/// tap target has a destination at the Phase 3 commit.
struct CelestialReferenceView: View {
    let latitude: Double
    let longitude: Double
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            IhsanColor.nightPage
                .ignoresSafeArea()

            VStack(spacing: IhsanSpacing.lg) {
                header

                Spacer()

                Text("CELESTIAL REFERENCE")
                    .font(IhsanFont.inscription)
                    .tracking(1.8)
                    .foregroundStyle(IhsanColor.brass.opacity(0.70))

                Spacer()
            }
            .padding(IhsanSpacing.lg)
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height > 80 {
                        onDismiss()
                    }
                }
        )
    }

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Celestial")
                    .font(.system(size: 28, weight: .medium, design: .serif))
                    .foregroundStyle(IhsanColor.boneCream)
                Text("DIRECTION & SKY")
                    .font(IhsanFont.inscription)
                    .tracking(1.8)
                    .foregroundStyle(IhsanColor.brass.opacity(0.80))
            }

            Spacer(minLength: IhsanSpacing.sm)

            Button {
                Haptics.tap()
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(IhsanColor.brass)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
    }
}
