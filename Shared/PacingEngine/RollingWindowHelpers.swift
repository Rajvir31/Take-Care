//
//  RollingWindowHelpers.swift
//  TakeCareApp — Pure helpers for rolling-window drink counts (used by PacingEngine).
//

import Foundation

/// Lightweight log entry for PacingEngine (no SwiftData dependency).
public struct DrinkLogSnapshot: Sendable {
    public let timestamp: Date
    public let drinkTypeId: String
    public let standardDrinkUnits: Double
    public let isAlcoholic: Bool

    public init(timestamp: Date, drinkTypeId: String, standardDrinkUnits: Double, isAlcoholic: Bool) {
        self.timestamp = timestamp
        self.drinkTypeId = drinkTypeId
        self.standardDrinkUnits = standardDrinkUnits
        self.isAlcoholic = isAlcoholic
    }
}

/// Lightweight event entry for dedupe checks.
public struct PacingEventSnapshot: Sendable {
    public let timestamp: Date
    public let code: String
    public let severity: Int

    public init(timestamp: Date, code: String, severity: Int) {
        self.timestamp = timestamp
        self.code = code
        self.severity = severity
    }
}

/// Lightweight settings for PacingEngine (no SwiftData dependency).
public struct UserSettingsSnapshot: Sendable {
    public let sensitivityMode: String
    public let hydrationRemindersEnabled: Bool
    public let hydrationCadence: Int

    public init(sensitivityMode: String, hydrationRemindersEnabled: Bool, hydrationCadence: Int) {
        self.sensitivityMode = sensitivityMode
        self.hydrationRemindersEnabled = hydrationRemindersEnabled
        self.hydrationCadence = hydrationCadence
    }
}

// MARK: - Rolling window helpers (pure functions)

public enum RollingWindowHelpers {

    /// Number of alcoholic drinks in the last `minutes` before `from`.
    public static func alcoholicDrinkCount(
        in minutes: Int,
        from date: Date,
        logs: [DrinkLogSnapshot]
    ) -> Int {
        let cutoff = date.addingTimeInterval(-TimeInterval(minutes * 60))
        return logs.filter { $0.isAlcoholic && $0.timestamp >= cutoff && $0.timestamp <= date }.count
    }

    /// Sum of standard drink units in the last `minutes` before `from`.
    public static func standardDrinkUnits(
        in minutes: Int,
        from date: Date,
        logs: [DrinkLogSnapshot]
    ) -> Double {
        let cutoff = date.addingTimeInterval(-TimeInterval(minutes * 60))
        return logs
            .filter { $0.timestamp >= cutoff && $0.timestamp <= date }
            .reduce(0) { $0 + $1.standardDrinkUnits }
    }

    /// Time interval from the most recent alcoholic drink to `date`, or nil if none.
    public static func timeSinceLastAlcoholicDrink(
        from date: Date,
        logs: [DrinkLogSnapshot]
    ) -> TimeInterval? {
        let alcoholic = logs.filter { $0.isAlcoholic && $0.timestamp <= date }.sorted { $0.timestamp > $1.timestamp }
        guard let last = alcoholic.first else { return nil }
        return date.timeIntervalSince(last.timestamp)
    }

    /// Count of logs with the given drink type in the last `minutes` before `from`.
    public static func count(
        drinkTypeId: String,
        in minutes: Int,
        from date: Date,
        logs: [DrinkLogSnapshot]
    ) -> Int {
        let cutoff = date.addingTimeInterval(-TimeInterval(minutes * 60))
        return logs.filter { $0.drinkTypeId == drinkTypeId && $0.timestamp >= cutoff && $0.timestamp <= date }.count
    }

    /// Total alcoholic drink count in the session (all logs up to `date`).
    public static func totalAlcoholicDrinkCount(from date: Date, logs: [DrinkLogSnapshot]) -> Int {
        logs.filter { $0.isAlcoholic && $0.timestamp <= date }.count
    }
}
