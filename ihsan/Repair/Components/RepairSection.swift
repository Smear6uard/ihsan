import IhsanCore
import IhsanDesignSystem
import SwiftData
import SwiftUI

/// The quiet Repair panel on Path: the thread, the total remaining in small
/// caps, and the pace month when there is one. Tapping opens the full
/// Repair surface. Self-contained — owns its own queries so it renders even
/// when the trajectory itself is empty.
struct RepairSection: View {
    let onOpen: () -> Void

    @Query(sort: \QadaLedger.categoryRaw) private var ledgers: [QadaLedger]
    @Query(sort: \QadaEntry.createdAt) private var entries: [QadaEntry]

    private var tokens: SkyPaletteTokens {
        RepairPalette.tokens()
    }

    private var totalRemaining: Int {
        ledgers.reduce(0) { $0 + $1.remainingCount }
    }

    private var totalMadeUp: Int {
        ledgers.reduce(0) { $0 + $1.madeUpCount }
    }

    private var progress: Double {
        let whole = totalRemaining + totalMadeUp
        guard whole > 0 else {
            return 0
        }
        return Double(totalMadeUp) / Double(whole)
    }

    private var inscriptionLine: String {
        if totalRemaining == 0 {
            return "NOTHING REMAINING"
        }

        var line = "REMAINING · \(totalRemaining.formatted(.number.grouping(.automatic)))"
        if let forecast = QadaPace.forecast(entries: entries, remaining: totalRemaining, asOf: .now) {
            line += "   AT YOUR PACE · \(forecast.formatted(.dateTime.month(.abbreviated).year()).uppercased())"
        }
        return line
    }

    var body: some View {
        Button {
            Haptics.impact(.light)
            onOpen()
        } label: {
            VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
                Text("REPAIR")
                    .font(IhsanFont.inscription)
                    .tracking(1.6)
                    .foregroundStyle(tokens.metal)

                RepairThreadView(progress: progress, tokens: tokens, terminalSize: 18)
                    .frame(height: 32)

                Text(inscriptionLine)
                    .font(IhsanFont.inscription)
                    .tracking(1.2)
                    .foregroundStyle(tokens.inkSecondary)
            }
            .padding(IhsanSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tokens.panelFill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(tokens.panelStroke, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Repair. \(totalRemaining) remaining. Opens makeup prayers.")
    }
}
