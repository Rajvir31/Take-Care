//
//  DrinkLog.swift
//  TakeCareApp — SwiftData model for a single drink log.
//

import Foundation
import SwiftData

@Model
final class DrinkLog {

    var idString: String
    var sessionIdString: String
    var timestamp: Date
    var drinkTypeId: String
    var standardDrinkUnits: Double
    var isAlcoholic: Bool
    var sourceDevice: String

    init(
        id: UUID = UUID(),
        sessionId: UUID,
        timestamp: Date = Date(),
        drinkTypeId: String,
        standardDrinkUnits: Double,
        isAlcoholic: Bool,
        sourceDevice: String
    ) {
        self.idString = id.uuidString
        self.sessionIdString = sessionId.uuidString
        self.timestamp = timestamp
        self.drinkTypeId = drinkTypeId
        self.standardDrinkUnits = standardDrinkUnits
        self.isAlcoholic = isAlcoholic
        self.sourceDevice = sourceDevice
    }

    var id: UUID { UUID(uuidString: idString) ?? UUID() }
    var sessionId: UUID { UUID(uuidString: sessionIdString) ?? UUID() }
}
