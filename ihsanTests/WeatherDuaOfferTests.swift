import Foundation
import Testing
import IhsanCore
@testable import ihsan

@Suite("Weather dua offers")
struct WeatherDuaOfferTests {
    private static let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func conditions(
        _ kind: SkyConditions.Kind,
        wind: SkyConditions.WindBand = .calm,
        at instant: Date = now
    ) -> SkyConditions {
        SkyConditions(
            kind: kind,
            isPrecipitating: kind.impliesPrecipitation,
            windBand: wind,
            cloudBand: .broken,
            fetchedAt: instant
        )
    }

    private func context(
        conditions: SkyConditions?,
        ledger: WeatherEpisodeLedger,
        now: Date = now,
        dismissed: Set<String> = [],
        available: Bool = true,
        layerEnabled: Bool = true
    ) -> WeatherDuaOffer.Context {
        WeatherDuaOffer.Context(
            conditions: conditions,
            ledger: ledger,
            now: now,
            dismissedEpisodes: dismissed,
            isContentAvailable: available,
            layerEnabled: layerEnabled
        )
    }

    // MARK: - Ledger transitions

    @Test("Rain beginning opens an episode; continuing rain keeps it")
    func rainEpisodeOpens() {
        let empty = WeatherEpisodeLedger()
        let begun = empty.advanced(with: conditions(.rain), now: Self.now)
        #expect(begun.rainStartedAt == Self.now)
        #expect(begun.rainEndedAt == nil)

        let later = Self.now.addingTimeInterval(1800)
        let still = begun.advanced(with: conditions(.heavyRain), now: later)
        #expect(still.rainStartedAt == Self.now, "continuing rain is the same episode")
    }

    @Test("Rain ending closes the episode and records when")
    func rainEpisodeCloses() {
        let raining = WeatherEpisodeLedger().advanced(with: conditions(.rain), now: Self.now)
        let after = Self.now.addingTimeInterval(3600)
        let ended = raining.advanced(with: conditions(.cloudy), now: after)
        #expect(ended.rainStartedAt == nil)
        #expect(ended.rainEndedAt == after)

        // Rain again later: a fresh episode, and the end mark clears.
        let again = after.addingTimeInterval(3600)
        let reopened = ended.advanced(with: conditions(.drizzle), now: again)
        #expect(reopened.rainStartedAt == again)
        #expect(reopened.rainEndedAt == nil)
    }

    @Test("Wind and thunder episodes follow their bands")
    func windAndThunderEpisodes() {
        let windy = WeatherEpisodeLedger().advanced(
            with: conditions(.windy, wind: .strong), now: Self.now
        )
        #expect(windy.windStartedAt == Self.now)

        let calmed = windy.advanced(with: conditions(.windy, wind: .breezy), now: Self.now + 60)
        #expect(calmed.windStartedAt == nil)

        let thunder = WeatherEpisodeLedger().advanced(
            with: conditions(.thunderstorms), now: Self.now
        )
        #expect(thunder.thunderStartedAt == Self.now)
        #expect(thunder.rainStartedAt == Self.now, "a thunderstorm also rains")

        let passed = thunder.advanced(with: conditions(.mostlyCloudy), now: Self.now + 60)
        #expect(passed.thunderStartedAt == nil)
    }

    // MARK: - Offers

    @Test("Active rain offers the dua of rain")
    func rainOffers() {
        let ledger = WeatherEpisodeLedger().advanced(with: conditions(.rain), now: Self.now)
        let offer = WeatherDuaOffer.offer(context(conditions: conditions(.rain), ledger: ledger))
        #expect(offer?.kind == .rain)
        #expect(offer?.episodeKey == "rain:1700000000")
    }

    @Test("A dismissed episode stays dismissed; a new episode offers again")
    func dismissalIsPerEpisode() {
        let ledger = WeatherEpisodeLedger().advanced(with: conditions(.rain), now: Self.now)
        let dismissed = WeatherDuaOffer.offer(
            context(conditions: conditions(.rain), ledger: ledger, dismissed: ["rain:1700000000"])
        )
        #expect(dismissed == nil)

        // The rain ends and returns: different episode, fresh offer.
        let after = Self.now.addingTimeInterval(3600)
        let again = after.addingTimeInterval(3600)
        let reopened = ledger
            .advanced(with: conditions(.cloudy), now: after)
            .advanced(with: conditions(.rain), now: again)
        let offer = WeatherDuaOffer.offer(
            context(
                conditions: conditions(.rain, at: again),
                ledger: reopened,
                now: again,
                dismissed: ["rain:1700000000"]
            )
        )
        #expect(offer?.kind == .rain)
        #expect(offer?.episodeKey == "rain:\(Int(again.timeIntervalSince1970))")
    }

    @Test("After the rain, its remembrance is offered for a while")
    func afterRainOffers() {
        let after = Self.now.addingTimeInterval(3600)
        let ended = WeatherEpisodeLedger()
            .advanced(with: conditions(.rain), now: Self.now)
            .advanced(with: conditions(.cloudy), now: after)

        let soon = after.addingTimeInterval(600)
        let offer = WeatherDuaOffer.offer(
            context(conditions: conditions(.cloudy, at: soon), ledger: ended, now: soon)
        )
        #expect(offer?.kind == .afterRain)

        let late = after.addingTimeInterval(WeatherDuaOffer.afterRainWindow)
        let expired = WeatherDuaOffer.offer(
            context(conditions: conditions(.cloudy, at: late), ledger: ended, now: late)
        )
        #expect(expired == nil)
    }

    @Test("Thunder outranks rain; wind is offered only alone")
    func priorityOrder() {
        let storm = conditions(.thunderstorms, wind: .strong)
        let ledger = WeatherEpisodeLedger().advanced(with: storm, now: Self.now)
        let offer = WeatherDuaOffer.offer(context(conditions: storm, ledger: ledger))
        #expect(offer?.kind == .thunder)

        let windOnly = conditions(.windy, wind: .strong)
        let windLedger = WeatherEpisodeLedger().advanced(with: windOnly, now: Self.now)
        let windOffer = WeatherDuaOffer.offer(context(conditions: windOnly, ledger: windLedger))
        #expect(windOffer?.kind == .wind)
    }

    @Test("Snow triggers no line at all")
    func snowIsQuiet() {
        let snow = conditions(.snow)
        let ledger = WeatherEpisodeLedger().advanced(with: snow, now: Self.now)
        #expect(WeatherDuaOffer.offer(context(conditions: snow, ledger: ledger)) == nil)
    }

    @Test("No reading, no line — and the gates hold")
    func gatesHold() {
        let rain = conditions(.rain)
        let ledger = WeatherEpisodeLedger().advanced(with: rain, now: Self.now)

        #expect(WeatherDuaOffer.offer(context(conditions: nil, ledger: ledger)) == nil)
        #expect(WeatherDuaOffer.offer(
            context(conditions: rain, ledger: ledger, available: false)
        ) == nil)
        #expect(WeatherDuaOffer.offer(
            context(conditions: rain, ledger: ledger, layerEnabled: false)
        ) == nil)
    }

    /// The decision function has no pause input at all. An excused
    /// pause suspends salah and fasting, never remembrance —
    /// `AdhkarOffer.pauseSuppresses` writes that rule down, and this
    /// context simply has nothing to suppress with.
    @Test("The offer context carries no pause field")
    func pauseImmuneByConstruction() {
        let mirror = Mirror(reflecting: context(
            conditions: conditions(.rain),
            ledger: WeatherEpisodeLedger()
        ))
        let labels = mirror.children.compactMap(\.label)
        #expect(!labels.contains { $0.lowercased().contains("pause") })
    }

    // MARK: - Each kind opens its transmitted text

    @Test("Every offer kind names a shipped situational item")
    func kindsNameRealItems() {
        let ids = Set(BundledAdhkar.items(in: .situational).map(\.id))
        for kind in WeatherDuaOffer.Kind.allCases {
            #expect(ids.contains(kind.itemID), "\(kind) → \(kind.itemID)")
        }
    }

    // MARK: - Dismissal storage codec

    @Test("Dismissal storage prunes keys that no longer name a live episode")
    func dismissalPrunes() {
        let stored = WeatherDuaDismissal.encode(
            ["rain:100", "wind:200", "thunder:9"],
            keeping: ["rain:100", "wind:200"]
        )
        #expect(WeatherDuaDismissal.decode(stored) == ["rain:100", "wind:200"])
        #expect(WeatherDuaDismissal.decode("") == [])
    }
}
