import SwiftUI
import IhsanDesignSystem

/// The watch root is a single-column experience. Today is the home;
/// Qibla rides as a sheet so the user is always one tap away from
/// the countdown — the canonical "why I lifted my wrist" surface.
struct RootView: View {
    @State private var presentingQibla = false

    var body: some View {
        ZStack {
            IhsanColor.ground.ignoresSafeArea()
            TodayView(onPresentQibla: { presentingQibla = true })
        }
        .sheet(isPresented: $presentingQibla) {
            QiblaView()
        }
    }
}
