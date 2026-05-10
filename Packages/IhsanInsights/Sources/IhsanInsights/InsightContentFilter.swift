import Foundation

enum InsightContentFilter {
    private static let prohibitedWordPatterns = [
        #"should"#,
        #"must"#,
        #"allah"#,
        #"prophet"#,
        #"hadith"#,
        #"qur[’']?an"#,
        #"haram"#,
        #"halal"#,
        #"scripture"#,
        #"fiqh"#,
        #"imam"#,
        #"scholar"#
    ]

    private static let quotationCharacters = CharacterSet(charactersIn: #""“”„‟«»"#)

    static func accepts(_ text: String) -> Bool {
        rejectionReasons(for: text).isEmpty
    }

    static func accepts(_ insight: WeeklyInsight) -> Bool {
        accepts(joinedFields(
            summarySentence: insight.summarySentence,
            mostConsistentPrayer: insight.mostConsistentPrayer,
            leastConsistentPrayer: insight.leastConsistentPrayer,
            notableObservation: insight.notableObservation
        ))
    }

    static func accepts(_ insight: MonthlyInsight) -> Bool {
        accepts(joinedFields(
            summarySentence: insight.summarySentence,
            mostConsistentPrayer: insight.mostConsistentPrayer,
            leastConsistentPrayer: insight.leastConsistentPrayer,
            notableObservation: insight.notableObservation
        ))
    }

    static func rejectionReasons(for text: String) -> [String] {
        var reasons: [String] = []

        if text.rangeOfCharacter(from: quotationCharacters) != nil {
            reasons.append("quotation marks")
        }

        for pattern in prohibitedWordPatterns {
            let regexPattern = #"(?i)(?<![A-Za-z])"# + pattern + #"(?![A-Za-z])"#
            if text.range(of: regexPattern, options: .regularExpression) != nil {
                reasons.append(pattern)
            }
        }

        return reasons
    }

    private static func joinedFields(
        summarySentence: String,
        mostConsistentPrayer: String,
        leastConsistentPrayer: String,
        notableObservation: String?
    ) -> String {
        [
            summarySentence,
            mostConsistentPrayer,
            leastConsistentPrayer,
            notableObservation
        ]
        .compactMap(\.self)
        .joined(separator: " ")
    }
}
