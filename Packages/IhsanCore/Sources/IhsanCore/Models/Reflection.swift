import Foundation
import SwiftData

@Model
public final class Reflection {
    public var id: UUID = UUID()

    public var kindRaw: String = ReflectionKind.daily.rawValue
    public var forDate: Date = Date.distantPast
    public var loggedTimeZoneIdentifier: String = TimeZone.current.identifier

    @Attribute(.allowsCloudEncryption)
    public var promptText: String?

    @Attribute(.allowsCloudEncryption)
    public var promptCitation: String?

    @Attribute(.allowsCloudEncryption)
    public var typedText: String?

    @Attribute(.allowsCloudEncryption)
    public var transcript: String?

    public var voiceMemoID: UUID?

    @Attribute(.allowsCloudEncryption)
    public var aiSummaryTitle: String?

    @Attribute(.allowsCloudEncryption)
    public var aiTagsJSON: String?

    public var aiGeneratedAt: Date?
    public var aiModelVersion: String?
    public var linkedPrayerLogID: UUID?
    public var wordCount: Int?
    public var createdAt: Date = Date.distantPast
    public var modifiedAt: Date = Date.distantPast

    public init(
        id: UUID = UUID(),
        kind: ReflectionKind,
        forDate: Date,
        loggedTimeZoneIdentifier: String,
        promptText: String? = nil,
        promptCitation: String? = nil,
        typedText: String? = nil,
        transcript: String? = nil,
        voiceMemoID: UUID? = nil,
        aiSummaryTitle: String? = nil,
        aiTagsJSON: String? = nil,
        aiGeneratedAt: Date? = nil,
        aiModelVersion: String? = nil,
        linkedPrayerLogID: UUID? = nil,
        createdAt: Date = .now,
        modifiedAt: Date = .now
    ) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.forDate = forDate
        self.loggedTimeZoneIdentifier = loggedTimeZoneIdentifier
        self.promptText = promptText
        self.promptCitation = promptCitation
        self.typedText = typedText
        self.transcript = transcript
        self.voiceMemoID = voiceMemoID
        self.aiSummaryTitle = aiSummaryTitle
        self.aiTagsJSON = aiTagsJSON
        self.aiGeneratedAt = aiGeneratedAt
        self.aiModelVersion = aiModelVersion
        self.linkedPrayerLogID = linkedPrayerLogID
        self.wordCount = Self.countWords(in: typedText ?? transcript)
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    private static func countWords(in text: String?) -> Int? {
        guard let text else {
            return nil
        }

        return text
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .count
    }
}

public extension Reflection {
    var kind: ReflectionKind? {
        ReflectionKind(rawValue: kindRaw)
    }

    var aiTags: [String] {
        guard let aiTagsJSON,
              let data = aiTagsJSON.data(using: .utf8),
              let tags = try? JSONDecoder().decode([String].self, from: data)
        else {
            return []
        }

        return tags
    }
}
