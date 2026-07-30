import IhsanCore
import IhsanDesignSystem
import SwiftUI

/// The Hijri month as a quiet sheet: a calm grid in the panel
/// language, today carrying a small gilded treatment, significant
/// days marked with fine engraved ticks, and a small-caps legend of
/// the month's curated facts beneath. Dates and names only — the
/// sheet states the calendar, nothing more.
struct HijriMonthSheet: View {
    /// Every day of the month, from THE one converter with the
    /// user's adjustment applied.
    let days: [HijriConverter.Day]
    /// Today's Hijri components under the same mapping.
    let today: HijriConverter.Components
    let timeZone: TimeZone
    let weekStartsOnSaturday: Bool
    let tokens: SkyPaletteTokens

    @Environment(\.dismiss) private var dismiss

    private var monthName: String {
        days.first?.components.monthName ?? ""
    }

    private var year: Int {
        days.first?.components.year ?? 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: IhsanSpacing.lg) {
                header
                grid
                legend
            }
            .padding(.horizontal, IhsanSpacing.lg)
            .padding(.top, IhsanSpacing.xl)
            .padding(.bottom, IhsanSpacing.xl)
        }
        .background {
            tokens.sheetBacking.ignoresSafeArea()
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.thinMaterial)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: IhsanSpacing.xs) {
            Text("HIJRI MONTH")
                .font(.system(.caption2, weight: .semibold).smallCaps())
                .tracking(2.4)
                .foregroundStyle(tokens.inkSecondary)

            Text("\(monthName) \(String(year)) AH")
                .font(.system(.title2, design: .serif, weight: .medium))
                .foregroundStyle(tokens.ink)

            Text(gregorianSpan)
                .font(.system(.caption2, weight: .semibold).smallCaps())
                .tracking(1.6)
                .foregroundStyle(tokens.inkSecondary.opacity(0.8))
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// "JUL 15 – AUG 12" — where this Hijri month sits on the civil
    /// calendar, under the user's adjustment.
    private var gregorianSpan: String {
        guard let first = days.first?.civilDayStart, let last = days.last?.civilDayStart else {
            return ""
        }
        return "\(PlateTimeFormat.dayMonth(first, in: timeZone)) – \(PlateTimeFormat.dayMonth(last, in: timeZone))"
    }

    // MARK: - Grid

    private var weekdaySymbols: [String] {
        // Saturday-first is the region-common default the app already
        // uses for its week views; the alternative starts Sunday.
        weekStartsOnSaturday
            ? ["S", "S", "M", "T", "W", "T", "F"]
            : ["S", "M", "T", "W", "T", "F", "S"]
    }

    /// Column index (0…6) of a civil day under the chosen week start.
    private func columnIndex(for date: Date) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let weekday = calendar.component(.weekday, from: date) // 1 = Sun
        return weekStartsOnSaturday ? weekday % 7 : weekday - 1
    }

    private var grid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        let leadingBlanks = days.first.map { columnIndex(for: $0.civilDayStart) } ?? 0

        return LazyVGrid(columns: columns, spacing: IhsanSpacing.sm) {
            ForEach(weekdaySymbols.indices, id: \.self) { index in
                Text(weekdaySymbols[index])
                    .font(.system(.caption2, weight: .semibold).smallCaps())
                    .tracking(1.2)
                    .foregroundStyle(tokens.inkSecondary.opacity(0.7))
                    .accessibilityHidden(true)
            }
            ForEach(0..<leadingBlanks, id: \.self) { _ in
                Color.clear.frame(height: 40)
            }
            ForEach(days, id: \.components) { day in
                dayCell(day)
            }
        }
        .padding(IhsanSpacing.md)
        .celestialPanel(tokens: tokens, cornerRadius: 20, isActive: false)
    }

    @ViewBuilder
    private func dayCell(_ day: HijriConverter.Day) -> some View {
        let isToday = day.components == today
        let marked = !day.significance.isEmpty && !day.significance.contains(.ramadan)

        VStack(spacing: 3) {
            Text("\(day.components.day)")
                .font(.system(.footnote, design: .serif, weight: isToday ? .semibold : .regular))
                .monospacedDigit()
                .foregroundStyle(isToday ? tokens.keyline : tokens.ink)
                .frame(width: 26, height: 26)
                .background {
                    if isToday {
                        Circle()
                            .fill(tokens.leafGold)
                            .overlay {
                                Circle().strokeBorder(
                                    tokens.keyline.opacity(0.55), lineWidth: 0.8
                                )
                            }
                    }
                }

            // The engraved tick: a fine metal mark, present only on
            // curated significant days.
            Rectangle()
                .fill(tokens.metal.opacity(marked ? 0.85 : 0))
                .frame(width: 8, height: 1.2)
        }
        .frame(height: 40)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cellAccessibilityLabel(day, isToday: isToday))
    }

    private func cellAccessibilityLabel(_ day: HijriConverter.Day, isToday: Bool) -> String {
        var parts = ["\(day.components.monthName) \(day.components.day)"]
        if isToday { parts.append("today") }
        for significance in day.significance where significance != .ramadan {
            parts.append(significance.label)
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Legend
    //
    // The month's curated facts, each an engraved tick and a
    // small-caps line: names and dates, nothing generated.

    private struct LegendEntry: Identifiable {
        let id: String
        let text: String
    }

    private var legendEntries: [LegendEntry] {
        var entries: [LegendEntry] = []
        let kinds = Set(days.flatMap(\.significance))
        if kinds.contains(.whiteDay) {
            entries.append(.init(id: "white", text: "White days · 13–15"))
        }
        if kinds.contains(.firstTenOfDhulHijjah) || kinds.contains(.arafah) {
            entries.append(.init(id: "ten", text: "First ten of Dhul-Hijjah · 1–10"))
        }
        if kinds.contains(.arafah) {
            entries.append(.init(id: "arafah", text: "Day of ʿArafah · 9"))
        }
        if kinds.contains(.ninthOfMuharram) {
            entries.append(.init(id: "ninth", text: "9th of Muharram · 9"))
        }
        if kinds.contains(.ashura) {
            entries.append(.init(id: "ashura", text: "ʿAshura · 10"))
        }
        if let note = HijriConverter.monthNote(forMonth: days.first?.components.month ?? 0) {
            entries.append(.init(id: "note", text: note))
        }
        return entries
    }

    @ViewBuilder
    private var legend: some View {
        if !legendEntries.isEmpty {
            VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
                ForEach(legendEntries) { entry in
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(tokens.metal.opacity(0.85))
                            .frame(width: 10, height: 1.2)
                            .accessibilityHidden(true)
                        Text(entry.text.uppercased())
                            .font(.system(.caption2, weight: .semibold).smallCaps())
                            .tracking(1.4)
                            .foregroundStyle(tokens.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(IhsanSpacing.md)
            .celestialPanel(tokens: tokens, cornerRadius: 16, isActive: false)
        }
    }
}
