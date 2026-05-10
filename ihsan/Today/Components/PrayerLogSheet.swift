import SwiftUI
import IhsanCore
import IhsanDesignSystem

/// The modal sheet presented when the user taps a prayer row.
///
/// The visual hierarchy follows the manuscript-redirect spec: the sheet
/// container itself reads as iOS 26 Liquid Glass (the platform identity
/// surface), while the five status options inside the glass render as
/// illuminated parchment rows with iridescent brass borders. This is
/// the only place in the app where illuminated rows sit on glass —
/// elsewhere they sit on the manuscript page background.
///
/// The sheet folds the existing confirmation-dialog flow into one
/// considered surface: the five status taps each map to a single
/// `Choice`, and the bottom-bar ADHAN SOUND button toggles per-prayer
/// adhan playback (the same toggle as the inline row's mute icon).
struct PrayerLogSheet: View {
    let prayer: Prayer
    let scheduledTime: Date
    /// Optional end of the prayer's window. `Fajr` ends at sunrise;
    /// other prayers end at the next prayer's scheduled time. Pass
    /// `nil` for Isha (the window extends past midnight; the
    /// inscription drops the "ENDS" clause when this is `nil`).
    let windowEndTime: Date?
    let currentStatus: PrayerStatus?
    let isJamaah: Bool
    let adhanEnabled: Bool

    let onSelect: (Choice) -> Void
    let onToggleAdhan: () -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    /// Combined status + jamaʿah option. The "in jamaʿah" case sets
    /// status to `.onTime` and jamaʿah to `true` in one tap; the plain
    /// "on time" case sets status to `.onTime` and jamaʿah to `false`.
    enum Choice: Hashable {
        case inJamaah
        case onTime
        case late
        case qada
        case missed
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            OrnamentalDivider()
                .padding(.horizontal, IhsanSpacing.lg)
                .padding(.top, IhsanSpacing.md)

            statusRows
                .padding(.horizontal, IhsanSpacing.md)
                .padding(.top, IhsanSpacing.lg)

            Spacer(minLength: IhsanSpacing.md)

            actionBar
        }
        .padding(.top, IhsanSpacing.xl)
        // The sheet renders on the system's Liquid Glass presentation
        // backing (configured at the call site via
        // `.presentationBackground(.thinMaterial)`). Internal rows
        // sit on top as illuminated parchment panels.
        .accessibilityElement(children: .contain)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: IhsanSpacing.xs) {
            Text("LOG PRAYER")
                .font(IhsanFont.inscription)
                .tracking(2.4)
                .foregroundStyle(IhsanColor.brassDark)

            HStack(alignment: .firstTextBaseline, spacing: IhsanSpacing.sm) {
                Text(prayer.displayNameEnglish)
                    .font(IhsanFont.heroPrayerName)
                    .foregroundStyle(IhsanColor.inkDeep)
                Text(prayer.displayNameArabic)
                    .font(IhsanFont.bodyArabic)
                    .foregroundStyle(IhsanColor.inkDeep.opacity(0.72))
            }
            .padding(.top, IhsanSpacing.xxs)

            Text(timeRangeInscription)
                .font(IhsanFont.inscription)
                .tracking(1.6)
                .foregroundStyle(IhsanColor.brassDark.opacity(0.85))
                .padding(.top, IhsanSpacing.xxs)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, IhsanSpacing.lg)
    }

    private var timeRangeInscription: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let start = formatter.string(from: scheduledTime).uppercased()
        guard let end = windowEndTime else { return start }
        return "\(start) · ENDS \(formatter.string(from: end).uppercased())"
    }

    // MARK: - Status rows

    private var statusRows: some View {
        VStack(spacing: IhsanSpacing.sm) {
            StatusOptionRow(
                choice: .inJamaah,
                isSelected: currentStatus == .onTime && isJamaah,
                onTap: { handle(.inJamaah) }
            )
            StatusOptionRow(
                choice: .onTime,
                isSelected: currentStatus == .onTime && !isJamaah,
                onTap: { handle(.onTime) }
            )
            StatusOptionRow(
                choice: .late,
                isSelected: currentStatus == .late,
                onTap: { handle(.late) }
            )
            StatusOptionRow(
                choice: .qada,
                isSelected: currentStatus == .qada,
                onTap: { handle(.qada) }
            )
            StatusOptionRow(
                choice: .missed,
                isSelected: currentStatus == .missed,
                onTap: { handle(.missed) }
            )
        }
    }

    private func handle(_ choice: Choice) {
        Haptics.impact(.light)
        onSelect(choice)
        dismiss()
    }

    // MARK: - Action bar

    private var actionBar: some View {
        HStack(spacing: IhsanSpacing.md) {
            Button {
                Haptics.impact(.light)
                onCancel()
                dismiss()
            } label: {
                Text("CANCEL")
                    .font(IhsanFont.inscription)
                    .tracking(1.8)
                    .foregroundStyle(IhsanColor.brassDark)
                    .padding(.horizontal, IhsanSpacing.md)
                    .padding(.vertical, IhsanSpacing.sm + 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel")

            Spacer()

            Button {
                Haptics.impact(.light)
                onToggleAdhan()
            } label: {
                HStack(spacing: IhsanSpacing.xs) {
                    Image(systemName: adhanEnabled
                          ? "speaker.wave.2.fill"
                          : "speaker.slash.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("ADHAN SOUND")
                        .font(IhsanFont.inscription)
                        .tracking(1.8)
                }
                .foregroundStyle(IhsanColor.inkDeep)
                .padding(.horizontal, IhsanSpacing.md + 2)
                .padding(.vertical, IhsanSpacing.sm + 2)
                .background {
                    Capsule()
                        .fill(IhsanIridescence.brassStroke(opacity: 0.95))
                }
                .overlay {
                    Capsule()
                        .strokeBorder(IhsanColor.brassDark.opacity(0.55), lineWidth: 0.5)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                adhanEnabled
                    ? "Mute adhan for \(prayer.displayNameEnglish)"
                    : "Unmute adhan for \(prayer.displayNameEnglish)"
            )
        }
        .padding(.horizontal, IhsanSpacing.lg)
        .padding(.bottom, IhsanSpacing.lg)
    }
}

// MARK: - Status option row

/// One status option inside the sheet. Renders as an illuminated
/// parchment row with a left-edge status marker, a two-line label
/// (status name + small-caps description), and a trailing chevron.
/// Selected rows fill their marker in brass; unselected rows show
/// the outlined marker.
private struct StatusOptionRow: View {
    let choice: PrayerLogSheet.Choice
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: IhsanSpacing.md) {
                StatusMarker(choice: choice, isSelected: isSelected)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(choice.title)
                        .font(IhsanFont.rowPrayerName)
                        .foregroundStyle(IhsanColor.inkDeep)
                    Text(choice.subtitle)
                        .font(IhsanFont.inscription)
                        .tracking(1.4)
                        .foregroundStyle(IhsanColor.brassDark)
                }

                Spacer(minLength: IhsanSpacing.sm)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(IhsanColor.brassDark.opacity(0.55))
            }
            .padding(.horizontal, IhsanSpacing.md)
            .padding(.vertical, IhsanSpacing.sm + 2)
            .frame(minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .ihsanIlluminatedPanel(intensity: .prayerRow, isActive: isSelected)
        .accessibilityLabel(choice.accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// The left-edge status marker — a square containing the option's
/// identifying glyph (J, ✓, ○, Q, —). Selected rows fill the
/// square in brass with the glyph in deep ink; unselected rows
/// outline the square and render the glyph in brass.
private struct StatusMarker: View {
    let choice: PrayerLogSheet.Choice
    let isSelected: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        ZStack {
            if isSelected {
                shape.fill(IhsanIridescence.brassStroke(opacity: 0.95))
            } else {
                shape
                    .fill(IhsanColor.panelDay.opacity(0.45))
            }
            shape.strokeBorder(
                IhsanIridescence.brassStroke(opacity: isSelected ? 0.95 : 0.55),
                lineWidth: isSelected ? 1.0 : 0.75
            )
            glyph
                .foregroundStyle(isSelected ? IhsanColor.inkDeep : IhsanColor.brassDark)
        }
    }

    @ViewBuilder
    private var glyph: some View {
        switch choice {
        case .inJamaah:
            Text("J")
                .font(.system(size: 16, weight: .bold, design: .serif))
        case .onTime:
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
        case .late:
            Image(systemName: "circle")
                .font(.system(size: 14, weight: .semibold))
        case .qada:
            Text("Q")
                .font(.system(size: 16, weight: .bold, design: .serif))
        case .missed:
            Image(systemName: "minus")
                .font(.system(size: 16, weight: .bold))
        }
    }
}

private extension PrayerLogSheet.Choice {
    var title: String {
        switch self {
        case .inJamaah: return "In Jamaʿah"
        case .onTime: return "On Time"
        case .late: return "Late"
        case .qada: return "Qadā"
        case .missed: return "Missed"
        }
    }

    var subtitle: String {
        switch self {
        case .inJamaah: return "PRAYED IN CONGREGATION"
        case .onTime: return "PRAYED WITHIN THE WINDOW"
        case .late: return "PRAYED AFTER THE WINDOW"
        case .qada: return "MADE UP AFTER MISSING"
        case .missed: return "NOT YET PRAYED"
        }
    }

    var accessibilityLabel: String {
        "\(title), \(subtitle.lowercased())"
    }
}

// MARK: - Preview

#Preview("Log sheet — Dhuhr, not yet logged") {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    let scheduled = calendar.date(byAdding: .second, value: 12 * 3600 + 38 * 60, to: today) ?? today
    let windowEnd = calendar.date(byAdding: .second, value: 16 * 3600 + 2 * 60, to: today) ?? today

    return Color.clear
        .ihsanManuscriptPage()
        .sheet(isPresented: .constant(true)) {
            PrayerLogSheet(
                prayer: .dhuhr,
                scheduledTime: scheduled,
                windowEndTime: windowEnd,
                currentStatus: nil,
                isJamaah: false,
                adhanEnabled: true,
                onSelect: { _ in },
                onToggleAdhan: {},
                onCancel: {}
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.thinMaterial)
        }
}

#Preview("Log sheet — Fajr, in jamaʿah") {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    let scheduled = calendar.date(byAdding: .second, value: 5 * 3600 + 14 * 60, to: today) ?? today
    let windowEnd = calendar.date(byAdding: .second, value: 6 * 3600 + 32 * 60, to: today) ?? today

    return Color.clear
        .ihsanManuscriptPage()
        .sheet(isPresented: .constant(true)) {
            PrayerLogSheet(
                prayer: .fajr,
                scheduledTime: scheduled,
                windowEndTime: windowEnd,
                currentStatus: .onTime,
                isJamaah: true,
                adhanEnabled: false,
                onSelect: { _ in },
                onToggleAdhan: {},
                onCancel: {}
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.thinMaterial)
        }
}
