//
//  SyncPayloads.swift
//  TakeCareApp — Dictionary payloads for WatchConnectivity (plist-compatible).
//

import Foundation

enum SyncPayloads {

    enum Key {
        static let type = "type"
        static let session = "session"
        static let log = "log"
        static let endSession = "endSession"
        static let settings = "settings"
        static let drinkTypes = "drinkTypes"
    }

    enum MessageType: String {
        case session
        case log
        case endSession
        case settings
        case drinkTypes
    }

    // MARK: - Session

    static func sessionPayload(id: UUID, startedAt: Date, sensitivityMode: String, hydrationCadence: Int, autoEndTimeoutMinutes: Int) -> [String: Any] {
        [
            Key.type: MessageType.session.rawValue,
            "id": id.uuidString,
            "startedAt": startedAt.timeIntervalSince1970,
            "sensitivityMode": sensitivityMode,
            "hydrationCadence": hydrationCadence,
            "autoEndTimeoutMinutes": autoEndTimeoutMinutes
        ] as [String: Any]
    }

    static func parseSession(_ dict: [String: Any]) -> (id: UUID, startedAt: Date, sensitivityMode: String, hydrationCadence: Int, autoEndTimeoutMinutes: Int)? {
        guard let idStr = dict["id"] as? String,
              let id = UUID(uuidString: idStr),
              let startedAtTs = dict["startedAt"] as? TimeInterval,
              let sensitivityMode = dict["sensitivityMode"] as? String,
              let hydrationCadence = dict["hydrationCadence"] as? Int,
              let autoEndTimeoutMinutes = dict["autoEndTimeoutMinutes"] as? Int else { return nil }
        return (id, Date(timeIntervalSince1970: startedAtTs), sensitivityMode, hydrationCadence, autoEndTimeoutMinutes)
    }

    // MARK: - Log

    static func logPayload(id: UUID, sessionId: UUID, timestamp: Date, drinkTypeId: String, standardDrinkUnits: Double, isAlcoholic: Bool, sourceDevice: String) -> [String: Any] {
        [
            Key.type: MessageType.log.rawValue,
            "id": id.uuidString,
            "sessionId": sessionId.uuidString,
            "timestamp": timestamp.timeIntervalSince1970,
            "drinkTypeId": drinkTypeId,
            "standardDrinkUnits": standardDrinkUnits,
            "isAlcoholic": isAlcoholic,
            "sourceDevice": sourceDevice
        ] as [String: Any]
    }

    static func parseLog(_ dict: [String: Any]) -> (id: UUID, sessionId: UUID, timestamp: Date, drinkTypeId: String, standardDrinkUnits: Double, isAlcoholic: Bool, sourceDevice: String)? {
        guard let idStr = dict["id"] as? String, let id = UUID(uuidString: idStr),
              let sessionIdStr = dict["sessionId"] as? String, let sessionId = UUID(uuidString: sessionIdStr),
              let ts = dict["timestamp"] as? TimeInterval,
              let drinkTypeId = dict["drinkTypeId"] as? String,
              let standardDrinkUnits = dict["standardDrinkUnits"] as? Double,
              let isAlcoholic = dict["isAlcoholic"] as? Bool,
              let sourceDevice = dict["sourceDevice"] as? String else { return nil }
        return (id, sessionId, Date(timeIntervalSince1970: ts), drinkTypeId, standardDrinkUnits, isAlcoholic, sourceDevice)
    }

    // MARK: - End session

    static func endSessionPayload(sessionId: UUID, endedAt: Date) -> [String: Any] {
        [
            Key.type: MessageType.endSession.rawValue,
            "sessionId": sessionId.uuidString,
            "endedAt": endedAt.timeIntervalSince1970
        ] as [String: Any]
    }

    static func parseEndSession(_ dict: [String: Any]) -> (sessionId: UUID, endedAt: Date)? {
        guard let idStr = dict["sessionId"] as? String, let sessionId = UUID(uuidString: idStr),
              let ts = dict["endedAt"] as? TimeInterval else { return nil }
        return (sessionId, Date(timeIntervalSince1970: ts))
    }

    // MARK: - Settings (phone → watch)

    static func settingsPayload(from settings: UserSettings) -> [String: Any] {
        var dict: [String: Any] = [
            Key.type: MessageType.settings.rawValue,
            "sensitivityMode": settings.sensitivityMode,
            "hydrationRemindersEnabled": settings.hydrationRemindersEnabled,
            "hydrationCadence": settings.hydrationCadence,
            "notificationsEnabled": settings.notificationsEnabled,
            "autoEndTimeoutMinutes": settings.autoEndTimeoutMinutes
        ]
        if let name = settings.displayName { dict["displayName"] = name }
        if let w = settings.weight { dict["weight"] = w }
        if let d = settings.disclaimerAcceptedAt { dict["disclaimerAcceptedAt"] = d.timeIntervalSince1970 }
        return dict
    }

    static func parseSettings(_ dict: [String: Any]) -> [String: Any]? {
        guard dict["sensitivityMode"] as? String != nil else { return nil }
        return dict
    }

    // MARK: - Drink types (phone → watch)

    static func drinkTypesPayload(configs: [DrinkTypeConfig]) -> [String: Any] {
        let array = configs.map { c in
            [
                "id": c.id,
                "displayName": c.displayName,
                "defaultStandardUnits": c.defaultStandardUnits,
                "isAlcoholic": c.isAlcoholic,
                "isEnabled": c.isEnabled,
                "sortOrder": c.sortOrder
            ] as [String: Any]
        }
        return [Key.type: MessageType.drinkTypes.rawValue, "items": array] as [String: Any]
    }

    static func parseDrinkTypes(_ dict: [String: Any]) -> [[String: Any]]? {
        guard let items = dict["items"] as? [[String: Any]] else { return nil }
        return items
    }
}
