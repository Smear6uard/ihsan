import IhsanCore
import IhsanDesignSystem
import SwiftData
import SwiftUI

/// The last screen: two facts and one question.
///
/// The facts are the two things a person genuinely cannot discover on
/// their own — that there is more of the day here if they want it, and
/// that nothing they record leaves their own devices. One line each, no
/// card, no illustration.
///
/// The question is notifications, asked here because here is where it
/// becomes relevant, and answered honestly: what the app will do with
/// the permission, in one line, before the system dialog appears.
/// Declining is a complete answer and the app finishes either way.
struct OnboardingCloseStep: View {
    @Bindable var viewModel: OnboardingViewModel

    @Environment(\.modelContext) private var modelContext
    @Environment(\.nowProvider) private var nowProvider

    var body: some View {
        let tokens = IhsanPageChrome.tokens(at: nowProvider.now())

        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: IhsanSpacing.lg) {
                Text("Before you begin")
                    .font(.system(.title2, design: .serif))
                    .foregroundStyle(tokens.ink)
                    .accessibilityAddTraits(.isHeader)

                line(
                    "There is more to the day than the five, if you want it — the sunnah layer waits in Set, off until you turn it on.",
                    tokens: tokens
                )
                line(
                    "Your worship data stays on your device and your iCloud. There is no server.",
                    tokens: tokens
                )
                line(
                    "Notifications, if you allow them, are one per prayer at its time — and every prayer can be silenced on its own.",
                    tokens: tokens
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, IhsanSpacing.lg)
            .padding(.top, IhsanSpacing.xxl)

            Spacer(minLength: IhsanSpacing.lg)

            VStack(spacing: IhsanSpacing.md) {
                OnboardingPrimaryButton(
                    viewModel.isRequestingNotifications ? "Asking…" : "Allow notifications"
                ) {
                    Task { await viewModel.enableNotificationsAndFinish(in: modelContext) }
                }
                .disabled(viewModel.isRequestingNotifications)

                OnboardingGhostButton("Not now") {
                    viewModel.skipNotificationsAndFinish(in: modelContext)
                }

                OnboardingProgressDots(
                    total: OnboardingStep.totalSteps,
                    currentIndex: OnboardingStep.close.progressIndex
                )
            }
            .padding(.horizontal, IhsanSpacing.lg)
            .padding(.bottom, IhsanSpacing.md)
        }
        .ihsanManuscriptPage()
    }

    /// A line, with the engraved rule that marks an inscription
    /// elsewhere in the app. Not a card, not an icon, not a bullet.
    private func line(_ text: String, tokens: SkyPaletteTokens) -> some View {
        HStack(alignment: .top, spacing: IhsanSpacing.sm) {
            Rectangle()
                .fill(tokens.metal.opacity(0.75))
                .frame(width: 14, height: 1.2)
                .padding(.top, 10)
            Text(text)
                .font(IhsanFont.bodyEnglish)
                .foregroundStyle(tokens.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
