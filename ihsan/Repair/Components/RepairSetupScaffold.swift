import IhsanDesignSystem
import SwiftUI

/// The one-question-per-screen frame for the Repair setup conversation.
/// Mirrors the onboarding scaffold's anatomy but is composed from v2 tokens:
/// ground gradient page, small-caps inscription, serif question, quiet body,
/// content in the middle, actions at the bottom. Text drawn on the ground
/// carries the ink-halo shadow per the palette contract.
struct RepairSetupScaffold<Content: View, Actions: View>: View {
    let tokens: SkyPaletteTokens
    let inscription: String
    let title: String
    let subtitle: String?
    @ViewBuilder let content: Content
    @ViewBuilder let actions: Actions

    var body: some View {
        ZStack {
            tokens.groundGradient
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: IhsanSpacing.md) {
                Text(inscription)
                    .font(IhsanFont.inscription)
                    .tracking(1.6)
                    .foregroundStyle(tokens.metal)
                    .shadow(color: tokens.inkHalo, radius: 2)

                Text(title)
                    .font(IhsanFont.heroPrayerName)
                    .foregroundStyle(tokens.ink)
                    .shadow(color: tokens.inkHalo, radius: 2)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle {
                    Text(subtitle)
                        .font(IhsanFont.bodyEnglish)
                        .foregroundStyle(tokens.inkSecondary)
                        .shadow(color: tokens.inkHalo, radius: 2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: IhsanSpacing.sm)

                content

                Spacer(minLength: IhsanSpacing.sm)

                VStack(spacing: IhsanSpacing.sm) {
                    actions
                }
            }
            .padding(.horizontal, IhsanSpacing.lg)
            .padding(.vertical, IhsanSpacing.lg)
        }
        .environment(\.colorScheme, tokens.prefersDarkChrome ? .dark : .light)
    }
}

extension SkyPaletteTokens {
    /// System controls (wheels, toggles) should match the ground's polarity.
    var prefersDarkChrome: Bool {
        groundBottomValue.relativeLuminance < 0.5
    }
}

/// Primary action: panel-filled capsule with a metal edge. Uses only
/// contrast-certified pairs (ink on panelFill).
struct RepairPrimaryButton: View {
    let title: String
    let tokens: SkyPaletteTokens
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.impact(.light)
            action()
        } label: {
            Text(title)
                .font(IhsanFont.bodyEnglishBold)
                .foregroundStyle(tokens.ink)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background {
                    Capsule().fill(tokens.panelFill)
                }
                .overlay {
                    Capsule().stroke(tokens.metal, lineWidth: 1.2)
                }
        }
        .buttonStyle(.plain)
    }
}

/// Quiet secondary action: hairline metal capsule, no fill.
struct RepairGhostButton: View {
    let title: String
    let tokens: SkyPaletteTokens
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.impact(.light)
            action()
        } label: {
            Text(title)
                .font(IhsanFont.bodyEnglish)
                .foregroundStyle(tokens.inkSecondary)
                .shadow(color: tokens.inkHalo, radius: 2)
                .frame(maxWidth: .infinity, minHeight: 44)
                .overlay {
                    Capsule().stroke(tokens.metal.opacity(0.45), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}
