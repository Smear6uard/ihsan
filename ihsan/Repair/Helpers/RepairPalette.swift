import Foundation
import IhsanCore
import IhsanDesignSystem

/// Resolves the v2 palette for Repair surfaces from the app's clock alone.
/// Repair screens open from Set and Path, where no solar-event data is in
/// hand, so we sit on the four canonical plateaus rather than interpolating —
/// `PaletteState.resolved(for: .fixed(state))` returns exact canonical tokens.
enum RepairPalette {
    // `NowProvider`, not `.now`: under `-IhsanNowOverride` the Repair
    // sheet took its palette from the real time of capture, so a staged
    // night frame came out at dusk.
    static func tokens(at date: Date = NowProvider.active.now(), calendar: Calendar = .current) -> SkyPaletteTokens {
        // The one page-chrome resolver — Repair rides the same
        // clock-derived phase as the rest of the secondary pages.
        IhsanPageChrome.tokens(at: date)
    }

    static func state(at date: Date = NowProvider.active.now(), calendar: Calendar = .current) -> PaletteState {
        switch calendar.component(.hour, from: date) {
        case 6..<12: .morning
        case 12..<17: .afternoon
        case 17..<21: .sunset
        default: .night
        }
    }
}
