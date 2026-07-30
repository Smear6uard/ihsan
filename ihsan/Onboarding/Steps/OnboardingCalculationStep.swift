import IhsanCore
import IhsanDesignSystem
import IhsanPrayerTimes
import SwiftUI

/// One screen for how the times are worked out.
///
/// The region's common method is already selected — every method row
/// shows the two angles it computes with, so the choice can be checked
/// against a masjid's timetable rather than taken on faith. Asr sits on
/// the same screen instead of getting a page of its own: it moves Asr
/// by the better part of an hour for a large part of the world, and
/// leaving it to be discovered in Set would hand those people quietly
/// wrong times.
///
/// Nothing here recommends. The starting point is a starting point.
struct OnboardingCalculationStep: View {
    @Bindable var viewModel: OnboardingViewModel

    @Environment(\.nowProvider) private var nowProvider

    var body: some View {
        let tokens = IhsanPageChrome.tokens(at: nowProvider.now())

        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: IhsanSpacing.lg) {
                    heading(tokens: tokens)

                    SettingsSectionCard("Method") {
                        SettingsDescriptionText("Every method sets how far below the horizon the sun must be for Fajr and Isha. Those two angles are on each row. You can change this later in Set.")

                        ForEach(CalculationMethodChoice.selectable, id: \.self) { method in
                            OnboardingMethodRow(
                                method: method,
                                isSelected: viewModel.draftMethod == method,
                                tokens: tokens
                            ) {
                                Haptics.impact(.light)
                                viewModel.draftMethod = method
                            }
                        }
                    }

                    SettingsSectionCard("Asr") {
                        SettingsDescriptionText("Schools differ on when Asr begins. This is the one choice that moves a prayer by close to an hour.")

                        ForEach(MadhabChoice.allCases, id: \.self) { madhab in
                            SettingsRow(
                                title: madhab.onboardingTitle,
                                subtitle: nil,
                                action: {
                                    Haptics.impact(.light)
                                    viewModel.draftMadhab = madhab
                                }
                            ) {
                                SettingsSelectionRing(isSelected: viewModel.draftMadhab == madhab)
                            }
                            .accessibilityValue(madhab.onboardingDetail)
                            SettingsDescriptionText(madhab.onboardingDetail)
                        }
                    }

                    Color.clear.frame(height: IhsanSpacing.md)
                }
                .padding(.horizontal, IhsanSpacing.md)
                .padding(.top, IhsanSpacing.md)
            }

            VStack(spacing: IhsanSpacing.md) {
                OnboardingPrimaryButton("Continue") {
                    viewModel.goNext(from: .calculation)
                }
                OnboardingProgressDots(
                    total: OnboardingStep.totalSteps,
                    currentIndex: OnboardingStep.calculation.progressIndex
                )
            }
            .padding(.horizontal, IhsanSpacing.lg)
            .padding(.bottom, IhsanSpacing.md)
        }
        .ihsanManuscriptPage()
    }

    private func heading(tokens: SkyPaletteTokens) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("How the times are worked out")
                .font(.system(.title2, design: .serif))
                .foregroundStyle(tokens.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("Set to what timetables near you commonly use.")
                .font(IhsanFont.bodyEnglish)
                .foregroundStyle(tokens.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// The same two-line method row Set uses: the name a person says, the
/// angles they can check, and who publishes it.
struct OnboardingMethodRow: View {
    let method: CalculationMethodChoice
    let isSelected: Bool
    let tokens: SkyPaletteTokens
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let angles = method.angles

        VStack(spacing: 0) {
            Divider()
                .frame(height: 0.5)
                .overlay(tokens.panelStroke.opacity(0.55))

            Button(action: action) {
                let stacked = typeSize >= .accessibility2

                HStack(alignment: .firstTextBaseline, spacing: IhsanSpacing.md) {
                    VStack(alignment: .leading, spacing: 2) {
                        if stacked {
                            name
                            if let angles { angleText(angles) }
                        } else {
                            HStack(alignment: .firstTextBaseline, spacing: IhsanSpacing.sm) {
                                name
                                Spacer(minLength: IhsanSpacing.xs)
                                if let angles { angleText(angles) }
                            }
                        }
                        Text(method.provenance)
                            .font(.footnote)
                            .foregroundStyle(tokens.inkSecondary.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    SettingsSelectionRing(isSelected: isSelected)
                }
                .padding(.horizontal, IhsanSpacing.md)
                .padding(.vertical, IhsanSpacing.sm + 2)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("\(method.shortName), \(method.provenance)")
        .accessibilityValue(
            [angles?.spokenDescription, isSelected ? "Selected" : nil]
                .compactMap { $0 }.joined(separator: ". ")
        )
    }

    private var name: some View {
        Text(method.shortName)
            .font(.system(size: 17, weight: .regular, design: .serif))
            .foregroundStyle(tokens.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func angleText(_ angles: CalculationMethodAngles) -> some View {
        Text(angles.inlineDescription)
            .font(.system(.subheadline, design: .rounded).monospacedDigit())
            .foregroundStyle(tokens.leafGold)
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(1)
    }
}

private extension MadhabChoice {
    var onboardingTitle: String {
        switch self {
        case .standard: "Standard"
        case .hanafi: "Hanafi"
        }
    }

    var onboardingDetail: String {
        switch self {
        case .standard:
            "Asr begins when a thing's shadow equals its length. Kept by Shafi'i, Maliki, and Hanbali."
        case .hanafi:
            "Asr begins when a thing's shadow is twice its length."
        }
    }
}
