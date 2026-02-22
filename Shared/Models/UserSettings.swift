//
//  UserSettings.swift
//  TakeCareApp — SwiftData singleton-like user preferences.
//

import Foundation
import SwiftData

@Model
final class UserSettings {

    var idString: String
    var displayName: String?
    var weight: Double?
    var sensitivityMode: String
    var hydrationRemindersEnabled: Bool
    var hydrationCadence: Int
    var notificationsEnabled: Bool
    var autoEndTimeoutMinutes: Int
    var disclaimerAcceptedAt: Date?

    init(
        id: UUID = UUID(),
        displayName: String? = nil,
        weight: Double? = nil,
        sensitivityMode: String = AppConstants.SensitivityMode.balanced.rawValue,
        hydrationRemindersEnabled: Bool = true,
        hydrationCadence: Int = 2,
        notificationsEnabled: Bool = true,
        autoEndTimeoutMinutes: Int = 180,
        disclaimerAcceptedAt: Date? = nil
    ) {
        self.idString = id.uuidString
        self.displayName = displayName
        self.weight = weight
        self.sensitivityMode = sensitivityMode
        self.hydrationRemindersEnabled = hydrationRemindersEnabled
        self.hydrationCadence = hydrationCadence
        self.notificationsEnabled = notificationsEnabled
        self.autoEndTimeoutMinutes = autoEndTimeoutMinutes
        self.disclaimerAcceptedAt = disclaimerAcceptedAt
    }

    var id: UUID { UUID(uuidString: idString) ?? UUID() }
}
