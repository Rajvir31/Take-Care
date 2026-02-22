//
//  DrinkTypeConfig.swift
//  TakeCareApp — SwiftData model for drink type defaults (editable in settings).
//

import Foundation
import SwiftData

@Model
final class DrinkTypeConfig {

    @Attribute(.unique) var id: String
    var displayName: String
    var defaultStandardUnits: Double
    var isAlcoholic: Bool
    var isEnabled: Bool
    var sortOrder: Int

    init(
        id: String,
        displayName: String,
        defaultStandardUnits: Double,
        isAlcoholic: Bool,
        isEnabled: Bool = true,
        sortOrder: Int
    ) {
        self.id = id
        self.displayName = displayName
        self.defaultStandardUnits = defaultStandardUnits
        self.isAlcoholic = isAlcoholic
        self.isEnabled = isEnabled
        self.sortOrder = sortOrder
    }
}
