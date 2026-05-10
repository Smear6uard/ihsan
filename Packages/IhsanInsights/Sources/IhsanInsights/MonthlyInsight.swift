import Foundation
import FoundationModels

@Generable(description: "A concise, factual monthly summary of one user's materialized prayer statistics.")
public struct MonthlyInsight: Equatable, Sendable {
    @Guide(description: "Two to three neutral factual sentences based only on the provided numeric monthly data. No advice, religious content, or quotation marks.")
    public var summarySentence: String

    @Guide(description: "English display name of the prayer with the highest on-time count.")
    public var mostConsistentPrayer: String

    @Guide(description: "English display name of the prayer with the lowest on-time count.")
    public var leastConsistentPrayer: String

    @Guide(description: "Optional neutral factual observation from the numeric data. No advice, religious content, or quotation marks.")
    public var notableObservation: String?

    public init(
        summarySentence: String,
        mostConsistentPrayer: String,
        leastConsistentPrayer: String,
        notableObservation: String? = nil
    ) {
        self.summarySentence = summarySentence
        self.mostConsistentPrayer = mostConsistentPrayer
        self.leastConsistentPrayer = leastConsistentPrayer
        self.notableObservation = notableObservation
    }
}
