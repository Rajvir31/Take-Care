//
//  PacingEvent.swift
//  TakeCareApp — SwiftData model for warnings/reminders/positive reinforcement.
//

import Foundation
import SwiftData

@Model
final class PacingEvent {

    var idString: String
    var sessionIdString: String
    var timestamp: Date
    var eventType: String
    var code: String
    var message: String
    var severity: Int

    init(
        id: UUID = UUID(),
        sessionId: UUID,
        timestamp: Date = Date(),
        eventType: String,
        code: String,
        message: String,
        severity: Int
    ) {
        self.idString = id.uuidString
        self.sessionIdString = sessionId.uuidString
        self.timestamp = timestamp
        self.eventType = eventType
        self.code = code
        self.message = message
        self.severity = severity
    }

    var id: UUID { UUID(uuidString: idString) ?? UUID() }
    var sessionId: UUID { UUID(uuidString: sessionIdString) ?? UUID() }
}
