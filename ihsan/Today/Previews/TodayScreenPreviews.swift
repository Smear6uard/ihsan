import SwiftUI
import IhsanCore
import IhsanDesignSystem

#Preview("Today Header") {
    ZStack {
        IhsanColor.ground.ignoresSafeArea()
        VStack {
            TodayHeader(
                cityName: "Chicago",
                date: .now,
                qiblaAction: {},
                masjidAction: {}
            )
            .padding(IhsanSpacing.md)
            Spacer()
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("Sunrise Boundary Row") {
    ZStack {
        IhsanColor.ground.ignoresSafeArea()
        VStack {
            SunriseBoundaryRow(sunriseTime: Date.now.addingTimeInterval(45 * 60))
                .padding(IhsanSpacing.md)
            Spacer()
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("Evening Reflection Entry") {
    ZStack {
        IhsanColor.ground.ignoresSafeArea()
        VStack {
            EveningReflectionEntry()
                .padding(IhsanSpacing.md)
            Spacer()
        }
    }
    .preferredColorScheme(.dark)
}
