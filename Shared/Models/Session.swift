//
//  Session.swift
//  TakeCareApp — SwiftData model for a drinking session.
//

import Foundation
import SwiftData

@Model
final class Session {

    var idString: String
    var startedAt: Date
    var endedAt: Date?
    var sensitivityMode: String
    var hydrationCadence: Int
    var autoEndTimeoutMinutes: Int

    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        sensitivityMode: String,
        hydrationCadence: Int,
        autoEndTimeoutMinutes: Int
    ) {
        self.idString = id.uuidString
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.sensitivityMode = sensitivityMode
        self.hydrationCadence = hydrationCadence
        self.autoEndTimeoutMinutes = autoEndTimeoutMinutes
    }

    var id: UUID { UUID(uuidString: idString) ?? UUID() }
    var isActive: Bool { endedAt == nil }
}
