import Foundation
import SwiftData

@Model
public final class DayRecord {
    public var id: UUID = UUID()

    public var forDate: Date = Date.distantPast
    public var loggedTimeZoneIdentifier: String = TimeZone.current.identifier

    @Attribute(.allowsCloudEncryption)
    public var musharataNote: String?

    public var calculationMethodSnapshot: String = CalculationMethodChoice.isna.rawValue
    public var madhabSnapshot: String = MadhabChoice.standard.rawValue
    public var highLatitudeRuleSnapshot: String?

    @Attribute(.allowsCloudEncryption)
    public var locationLabel: String?

    public var isPaused: Bool = false
    public var isTraveling: Bool = false
    public var createdAt: Date = Date.distantPast
    public var modifiedAt: Date = Date.distantPast

    public init(
        id: UUID = UUID(),
        forDate: Date,
        loggedTimeZoneIdentifier: String,
        musharataNote: String? = nil,
        calculationMethod: CalculationMethodChoice = .isna,
        madhab: MadhabChoice = .standard,
        highLatitudeRule: HighLatitudeRule? = nil,
        locationLabel: String? = nil,
        isPaused: Bool = false,
        isTraveling: Bool = false,
        createdAt: Date = .now,
        modifiedAt: Date = .now
    ) {
        self.id = id
        self.forDate = forDate
        self.loggedTimeZoneIdentifier = loggedTimeZoneIdentifier
        self.musharataNote = musharataNote
        self.calculationMethodSnapshot = calculationMethod.rawValue
        self.madhabSnapshot = madhab.rawValue
        self.highLatitudeRuleSnapshot = highLatitudeRule?.rawValue
        self.locationLabel = locationLabel
        self.isPaused = isPaused
        self.isTraveling = isTraveling
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

public extension DayRecord {
    var calculationMethod: CalculationMethodChoice? {
        CalculationMethodChoice(rawValue: calculationMethodSnapshot)
    }

    var madhab: MadhabChoice? {
        MadhabChoice(rawValue: madhabSnapshot)
    }

    var highLatitudeRule: HighLatitudeRule? {
        highLatitudeRuleSnapshot.flatMap(HighLatitudeRule.init(rawValue:))
    }
}
