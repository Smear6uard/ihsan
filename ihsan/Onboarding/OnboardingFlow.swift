import SwiftUI
import IhsanCore
import IhsanDesignSystem

/// First-launch flow root.
///
/// Three screens, and the first of them is the app: a live plate for a
/// real place with the location question on it. `NavigationStack`
/// drives the forward progression; the back mark pops a step.
///
/// The flow is presented full-screen by `IhsanApp` and owns its own
/// view model, so quitting mid-flow throws the drafts away and starts
/// clean rather than resuming somewhere half-decided.
struct OnboardingFlow: View {
    @State private var viewModel = OnboardingViewModel()

    var body: some View {
        @Bindable var vm = viewModel
        return NavigationStack(path: $vm.path) {
            OnboardingPlateStep(viewModel: viewModel)
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: OnboardingStep.self) { step in
                    destinationView(for: step)
                        .toolbar { backChevron }
                        .toolbarBackground(.hidden, for: .navigationBar)
                        .navigationBarBackButtonHidden(true)
                        .navigationBarTitleDisplayMode(.inline)
                }
        }
        .tint(IhsanPageChrome.tokens(at: NowProvider.active.now()).leafGold)
    }

    @ViewBuilder
    private func destinationView(for step: OnboardingStep) -> some View {
        switch step {
        case .plate:
            // The plate is the root, not a path entry. This branch
            // exists only for exhaustiveness; reaching it would mean
            // the path was built wrong.
            EmptyView()
        case .calculation:
            OnboardingCalculationStep(viewModel: viewModel)
        case .close:
            OnboardingCloseStep(viewModel: viewModel)
        }
    }

    @ToolbarContentBuilder
    private var backChevron: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                guard !viewModel.path.isEmpty else { return }
                viewModel.path.removeLast()
            } label: {
                // The app's own bent line, like every other mark.
                BackMark()
                    .stroke(
                        IhsanPageChrome.tokens(at: NowProvider.active.now()).inkSecondary,
                        style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: 9, height: 16)
                    .frame(width: 44, height: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Back")
        }
    }
}

/// The back mark: one bent line, drawn.
private struct BackMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}

#Preview {
    OnboardingFlow()
}
