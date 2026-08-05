import Foundation
import Testing
@testable import ihsan

/// The pattern card's one geometric promise: every row sits on the
/// same columns.
///
/// The presence rows used to be laid out by their own stack with their
/// own idea of where a column was, and a mark half a pitch out of step
/// reads as debris rather than as a row — which is exactly how they
/// came to look like marks floating in empty space. These hold the
/// prayer-dot centres and the presence-mark centres to each other at
/// every period, every width, and every column.
@Suite("Gestalt layout")
struct GestaltLayoutTests {

    /// The widths a supported iPhone gives the card, panel padding
    /// already taken off — plus two absurd ones, because a layout that
    /// only holds at plausible sizes is a layout waiting to be
    /// surprised.
    private static let widths: [CGFloat] = [
        260, 300, 320, 343, 360, 393, 430, 120, 1_024
    ]

    private static let gutters: [CGFloat] = [0, 46, 92]

    // MARK: - The promise

    @Test("Presence marks land exactly on the prayer columns")
    func presenceMarksShareThePrayerColumns() {
        for period in TrajectoryPeriod.allCases {
            for width in Self.widths {
                for gutter in Self.gutters {
                    let layout = GestaltLayout(
                        period: period,
                        availableWidth: width,
                        labelGutter: gutter,
                        labelHeight: 13
                    )
                    for column in 0..<layout.columnCount {
                        #expect(
                            layout.presenceMarkCenter(column: column)
                                == layout.prayerDotCenter(column: column),
                            """
                            column \(column) of \(period) at width \(width), \
                            gutter \(gutter): a presence mark left its column
                            """
                        )
                    }
                }
            }
        }
    }

    @Test("Columns are evenly pitched, with no accumulating drift")
    func columnsAreEvenlyPitched() {
        for period in TrajectoryPeriod.allCases {
            for width in Self.widths {
                let layout = GestaltLayout(
                    period: period, availableWidth: width, labelGutter: 46, labelHeight: 13
                )
                for column in 1..<layout.columnCount {
                    let step = layout.prayerDotCenter(column: column)
                        - layout.prayerDotCenter(column: column - 1)
                    #expect(
                        abs(step - layout.pitch) < 0.0001,
                        "\(period) at \(width): column \(column) drifted by \(step - layout.pitch)"
                    )
                }
            }
        }
    }

    @Test("No mark renders off-grid, gutter included")
    func nothingRendersOffGrid() {
        for period in TrajectoryPeriod.allCases {
            for width in Self.widths where width >= 260 {
                for gutter in Self.gutters {
                    let layout = GestaltLayout(
                        period: period,
                        availableWidth: width,
                        labelGutter: gutter,
                        labelHeight: 13
                    )
                    let firstEdge = layout.prayerDotCenter(column: 0) - layout.dotSize / 2
                    let lastEdge = layout.prayerDotCenter(column: layout.columnCount - 1)
                        + layout.dotSize / 2
                    #expect(
                        firstEdge >= layout.labelGutter - 0.0001,
                        "\(period) at \(width): the first column crossed into the label gutter"
                    )
                    // The gutter is capped, so a label at the largest
                    // type sizes on the narrowest phone can never ask
                    // for more room than the pattern it names.
                    #expect(layout.labelGutter <= gutter)
                    #expect(layout.labelGutter <= width * 0.25 + 0.0001)
                    #expect(
                        lastEdge <= width + 0.0001,
                        "\(period) at \(width): the last column ran past the panel"
                    )
                }
            }
        }
    }

    // MARK: - The presence rows' own geometry

    @Test("A presence mark is a fardh dot's size — one size rule")
    func presenceMarksAreDotSized() {
        for period in TrajectoryPeriod.allCases {
            let layout = GestaltLayout(
                period: period, availableWidth: 343, labelGutter: 46, labelHeight: 13
            )
            #expect(layout.presenceMarkSize == layout.dotSize)
        }
    }

    /// The label needs vertical room the dots do not have at 90D. It
    /// may take it from the row's HEIGHT and from nowhere else.
    @Test("A presence row is at least as tall as its label")
    func presenceRowsMakeRoomForTheirLabel() {
        for period in TrajectoryPeriod.allCases {
            let layout = GestaltLayout(
                period: period, availableWidth: 343, labelGutter: 46, labelHeight: 13
            )
            #expect(layout.presenceRowHeight >= 13)
            #expect(layout.presenceRowHeight >= layout.dotSize)
        }
    }

    // MARK: - The pristine card

    /// With no voluntary record in the window there is no gutter, and
    /// the pattern keeps the full width — the card a new account sees
    /// is the card that existed before any of this.
    @Test("No gutter means the pattern starts at the leading edge")
    func aPristineCardKeepsItsFullWidth() {
        for period in TrajectoryPeriod.allCases {
            let bare = GestaltLayout(period: period, availableWidth: 343)
            #expect(bare.labelGutter == 0)
            #expect(bare.prayerDotCenter(column: 0) == bare.dotSize / 2)

            let labelled = GestaltLayout(
                period: period, availableWidth: 343, labelGutter: 46, labelHeight: 13
            )
            #expect(labelled.dotSize <= bare.dotSize)
        }
    }

    // MARK: - Column counts

    /// A presence row is drawn from `presenceColumns`, which must
    /// produce exactly one entry per fardh column or the row cannot be
    /// aligned at all.
    @Test("Presence columns are 1:1 with fardh columns at every period")
    func presenceColumnsMatchTheFardhColumns() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let days: [DayCompletion] = (0..<365).reversed().map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            return DayCompletion(
                id: date,
                date: date,
                prayerCompletions: [],
                isPaused: false,
                isTraveling: false
            )
        }

        for period in TrajectoryPeriod.allCases {
            let window = Array(days.suffix(period.dayCount))
            let marked = Set([window[window.count - 1].date])
            let columns = GestaltAggregation.presenceColumns(
                days: window, period: period, daysWithRecord: marked
            )
            #expect(
                columns.count == GestaltLayout.columnCount(for: period),
                "\(period) produced \(columns.count) presence columns"
            )
        }
    }
}
