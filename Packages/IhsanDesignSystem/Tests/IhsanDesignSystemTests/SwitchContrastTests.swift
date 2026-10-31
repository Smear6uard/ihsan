import Testing
@testable import IhsanDesignSystem

/// The drawn switch's off state must be findable on its panel in every
/// phase: its outline meets the 3:1 non-text contrast minimum. The
/// system switch it replaces in Set failed this by day, when the window
/// turned light and its off track went white on near-white.
@Suite("Drawn switch contrast")
struct SwitchContrastTests {

    @Test("The off outline holds 3:1 against the panel in every phase")
    func offOutlineIsFindable() {
        for state in PaletteState.allCases {
            let tokens = PaletteState.resolved(for: .fixed(state))
            let panel = tokens.panelFillValue
            let outline = SRGBValue.mix(
                panel, tokens.inkSecondaryValue,
                amount: IhsanSwitchToggleStyle.offOutline
            )
            let ratio = outline.contrastRatio(against: panel)
            #expect(ratio >= 3.0, "\(state) off outline is \(ratio):1")
        }
    }
}
