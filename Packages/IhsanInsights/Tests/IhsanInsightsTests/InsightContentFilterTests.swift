import Testing
@testable import IhsanInsights

@Test
func contentFilterRejectsProhibitedTerms() {
    let rejectedTexts = [
        "You should pray Fajr earlier.",
        "This hadith shows consistency.",
        "Allah loves consistency.",
        "The Prophet said something about prayer.",
        "Quran recitation increased this month.",
        "That pattern is halal.",
        "That pattern is haram.",
        "Dhuhr was most consistent and must remain steady."
    ]

    for text in rejectedTexts {
        #expect(!InsightContentFilter.accepts(text), "Expected rejection for: \(text)")
    }
}

@Test
func contentFilterRejectsQuotationMarks() {
    #expect(!InsightContentFilter.accepts(#"Fajr was "consistent" this week."#))
    #expect(!InsightContentFilter.accepts("Fajr was “consistent” this week."))
}

@Test
func contentFilterAcceptsNeutralFactualSummary() {
    let text = "Fajr was prayed on time on 14 of 30 days. Asr was prayed on time on 22 of 30 days."

    #expect(InsightContentFilter.accepts(text))
}
