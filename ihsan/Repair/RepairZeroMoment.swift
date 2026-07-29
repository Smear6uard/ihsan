import IhsanCore
import IhsanDesignSystem
import SwiftUI

/// The one quiet moment when a category — or the whole ledger — reaches
/// zero. The completed thread meets its terminal ornament, a single line of
/// type, one soft haptic. Nothing moves, nothing plays, nothing is shared.
/// It shows once, at the moment of crossing, then the cleared category
/// quietly collapses from the Repair surface.
struct RepairZeroMoment: View {
    let event: RepairViewModel.ZeroEvent
    let tokens: SkyPaletteTokens

    @Environment(\.dismiss) private var dismiss

    private var line: String {
        switch event {
        case .category(let category):
            "Every \(category.displayNameEnglish) returned."
        case .whole:
            "Every prayer returned."
        }
    }

    var body: some View {
        ZStack {
            tokens.groundGradient
                .ignoresSafeArea()

            VStack(spacing: IhsanSpacing.xl) {
                Spacer()

                ZStack {
                    RepairThreadView(progress: 1, tokens: tokens, terminalSize: 28)
                        .frame(width: 240, height: 56)
                }

                Text(line)
                    .font(IhsanFont.heroPrayerName)
                    .foregroundStyle(tokens.ink)
                    .shadow(color: tokens.inkHalo, radius: 2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if case .whole = event {
                    Text("AT YOUR PACE · WHOLE")
                        .font(IhsanFont.inscription)
                        .tracking(1.6)
                        .foregroundStyle(tokens.metal)
                        .shadow(color: tokens.inkHalo, radius: 2)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("Continue")
                        .font(IhsanFont.bodyEnglish)
                        .foregroundStyle(tokens.inkSecondary)
                        .shadow(color: tokens.inkHalo, radius: 2)
                        .frame(minHeight: 44)
                        .padding(.horizontal, IhsanSpacing.lg)
                }
                .buttonStyle(.plain)
                .padding(.bottom, IhsanSpacing.xl)
            }
            .padding(IhsanSpacing.lg)
        }
        .task {
            Haptics.impact(.soft)
        }
        .accessibilityElement(children: .contain)
    }
}
