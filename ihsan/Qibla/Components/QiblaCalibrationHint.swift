import SwiftUI
import IhsanDesignSystem

/// Quiet inline prompt asking the user to wave the device in a figure-8 to
/// recalibrate the magnetometer. iOS shows its own system overlay
/// independently when calibration is required; this is the in-context
/// equivalent.
struct QiblaCalibrationHint: View {
    var body: some View {
        HStack(spacing: IhsanSpacing.sm) {
            Image(systemName: "gyroscope")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(IhsanColor.textMuted)
            Text("Move the device in a figure-8 to calibrate the compass")
                .font(IhsanFont.bodyEnglish)
                .foregroundStyle(IhsanColor.textMuted)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, IhsanSpacing.md)
        .padding(.vertical, IhsanSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    QiblaCalibrationHint()
        .padding(IhsanSpacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ihsanBackground()
}
