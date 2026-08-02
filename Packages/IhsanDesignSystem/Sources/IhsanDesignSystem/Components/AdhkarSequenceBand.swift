import SwiftUI

/// The four-pointed lozenge a manuscript sets between verses.
///
/// Chosen over a dot because a dot would be a progress indicator
/// borrowed from software, and this is a position in a sequence that
/// was fixed long before software: the morning set has a customary
/// order, and where you are in it is real information. The sides bow
/// inward so the form reads as drawn rather than geometric.
public struct SequenceLozengeShape: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        let midX = rect.midX
        let midY = rect.midY
        // How far the sides pull toward the centre. Enough to read as
        // concave at 9 pt, not so much that the form becomes a star.
        let bow: CGFloat = 0.28

        var path = Path()
        path.move(to: CGPoint(x: midX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: midY),
            control: CGPoint(
                x: midX + (rect.maxX - midX) * bow,
                y: midY - (midY - rect.minY) * bow
            )
        )
        path.addQuadCurve(
            to: CGPoint(x: midX, y: rect.maxY),
            control: CGPoint(
                x: midX + (rect.maxX - midX) * bow,
                y: midY + (rect.maxY - midY) * bow
            )
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: midY),
            control: CGPoint(
                x: midX - (midX - rect.minX) * bow,
                y: midY + (rect.maxY - midY) * bow
            )
        )
        path.addQuadCurve(
            to: CGPoint(x: midX, y: rect.minY),
            control: CGPoint(
                x: midX - (midX - rect.minX) * bow,
                y: midY - (midY - rect.minY) * bow
            )
        )
        path.closeSubpath()
        return path
    }
}

/// What one mark in the band is saying.
public enum SequenceMarkState: Sendable, Equatable {
    /// Not yet counted through.
    case pending
    /// The item on screen.
    case current
    /// Counted to its transmitted number.
    case complete
}

/// One mark of the band, in the app's ornament-state language: engraved
/// outline, outline with its keyline lit, or gilded.
public struct SequenceMark: View {
    private let state: SequenceMarkState
    private let tokens: SkyPaletteTokens

    public init(state: SequenceMarkState, tokens: SkyPaletteTokens) {
        self.state = state
        self.tokens = tokens
    }

    public var body: some View {
        SequenceLozengeShape()
            .fill(state == .complete ? AnyShapeStyle(tokens.leafGold) : AnyShapeStyle(.clear))
            .overlay {
                SequenceLozengeShape()
                    .stroke(strokeColor, lineWidth: state == .pending ? 0.8 : 1.0)
            }
            .frame(width: 9, height: 14)
    }

    private var strokeColor: Color {
        switch state {
        case .pending: tokens.metal.opacity(0.40)
        case .current: tokens.keyline
        case .complete: tokens.keyline.opacity(0.60)
        }
    }
}

/// The set's spine: one mark per item, in the set's own order, gilding
/// as each item's count is kept.
///
/// It is the progress indicator, the position indicator, and the way to
/// move — a mark is a tap target that jumps to its item. Under Reduce
/// Motion nothing animates; a mark simply is gilded or is not.
public struct AdhkarSequenceBand: View {
    private let states: [SequenceMarkState]
    private let tokens: SkyPaletteTokens
    private let reduceMotion: Bool
    private let labels: [String]
    private let onSelect: (Int) -> Void

    public init(
        states: [SequenceMarkState],
        labels: [String],
        tokens: SkyPaletteTokens,
        reduceMotion: Bool,
        onSelect: @escaping (Int) -> Void
    ) {
        self.states = states
        self.labels = labels
        self.tokens = tokens
        self.reduceMotion = reduceMotion
        self.onSelect = onSelect
    }

    public var body: some View {
        HStack(spacing: spacing) {
            ForEach(Array(states.enumerated()), id: \.offset) { index, state in
                Button {
                    onSelect(index)
                } label: {
                    SequenceMark(state: state, tokens: tokens)
                        // A 9 pt lozenge is not a tap target; the mark
                        // keeps its drawn size and the target grows
                        // around it.
                        .frame(width: 22, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(labels.indices.contains(index) ? labels[index] : "Item \(index + 1)")
                .accessibilityValue(value(for: state))
                .accessibilityHint("Double-tap to go to this one.")
            }
        }
        .frame(height: 44)
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: states)
    }

    /// Sixteen marks and their targets have to fit a phone; past a
    /// dozen the band tightens rather than overflowing.
    private var spacing: CGFloat {
        states.count > 12 ? 0 : 2
    }

    private func value(for state: SequenceMarkState) -> String {
        switch state {
        case .pending: "not yet counted"
        case .current: "current"
        case .complete: "counted"
        }
    }
}

#Preview("Sequence band") {
    let tokens = PaletteState.resolved(for: SkyPhase.fixed(.dawn))
    return ZStack {
        tokens.groundGradient.ignoresSafeArea()
        VStack(spacing: 24) {
            AdhkarSequenceBand(
                states: [.complete, .complete, .current] + Array(repeating: .pending, count: 13),
                labels: (1...16).map { "Item \($0)" },
                tokens: tokens,
                reduceMotion: false,
                onSelect: { _ in }
            )
            AdhkarSequenceBand(
                states: [.complete, .complete, .complete, .complete, .complete, .complete, .current],
                labels: (1...7).map { "Item \($0)" },
                tokens: tokens,
                reduceMotion: false,
                onSelect: { _ in }
            )
        }
        .padding()
    }
}
