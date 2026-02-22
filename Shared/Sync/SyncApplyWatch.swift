//
//  SyncApplyWatch.swift
//  TakeCareApp — Apply received phone settings/drink types to watch SwiftData.
//

import Foundation
import SwiftData

public enum SyncApplyWatch {

    /// Call once when the watch app has a model context (e.g. from WatchMainView).
    public static func configure(modelContext: ModelContext) {
        let manager = WatchConnectivityManager.shared
        manager.onReceiveSettings = { [weak modelContext] dict in
            guard let modelContext else { return }
            applySettings(context: modelContext, dict: dict)
        }
        manager.onReceiveDrinkTypes = { [weak modelContext] items in
            guard let modelContext else { return }
            applyDrinkTypes(context: modelContext, items: items)
        }
    }

    private static func applySettings(context: ModelContext, dict: [String: Any]) {
        let repo = UserSettingsRepository(modelContext: context)
        let existing = repo.fetch()
        if let existing {
            existing.displayName = dict["displayName"] as? String
            existing.weight = dict["weight"] as? Double
            if let v = dict["sensitivityMode"] as? String { existing.sensitivityMode = v }
            if let v = dict["hydrationRemindersEnabled"] as? Bool { existing.hydrationRemindersEnabled = v }
            if let v = dict["hydrationCadence"] as? Int { existing.hydrationCadence = v }
            if let v = dict["notificationsEnabled"] as? Bool { existing.notificationsEnabled = v }
            if let v = dict["autoEndTimeoutMinutes"] as? Int { existing.autoEndTimeoutMinutes = v }
            if let ts = dict["disclaimerAcceptedAt"] as? TimeInterval { existing.disclaimerAcceptedAt = Date(timeIntervalSince1970: ts) }
        } else {
            let settings = UserSettings(
                displayName: dict["displayName"] as? String,
                weight: dict["weight"] as? Double,
                sensitivityMode: (dict["sensitivityMode"] as? String) ?? AppConstants.SensitivityMode.balanced.rawValue,
                hydrationRemindersEnabled: (dict["hydrationRemindersEnabled"] as? Bool) ?? true,
                hydrationCadence: (dict["hydrationCadence"] as? Int) ?? 2,
                notificationsEnabled: (dict["notificationsEnabled"] as? Bool) ?? true,
                autoEndTimeoutMinutes: (dict["autoEndTimeoutMinutes"] as? Int) ?? 180,
                disclaimerAcceptedAt: (dict["disclaimerAcceptedAt"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) }
            )
            context.insert(settings)
        }
        try? context.save()
    }

    private static func applyDrinkTypes(context: ModelContext, items: [[String: Any]]) {
        let repo = DrinkTypeConfigRepository(modelContext: context)
        for item in items {
            guard let id = item["id"] as? String,
                  let displayName = item["displayName"] as? String,
                  let defaultStandardUnits = item["defaultStandardUnits"] as? Double,
                  let isAlcoholic = item["isAlcoholic"] as? Bool,
                  let isEnabled = item["isEnabled"] as? Bool,
                  let sortOrder = item["sortOrder"] as? Int else { continue }
            if let existing = repo.config(for: id) {
                existing.displayName = displayName
                existing.defaultStandardUnits = defaultStandardUnits
                existing.isAlcoholic = isAlcoholic
                existing.isEnabled = isEnabled
                existing.sortOrder = sortOrder
            } else {
                let config = DrinkTypeConfig(id: id, displayName: displayName, defaultStandardUnits: defaultStandardUnits, isAlcoholic: isAlcoholic, isEnabled: isEnabled, sortOrder: sortOrder)
                context.insert(config)
            }
        }
        try? context.save()
    }
}
