//
//  SyncApplyPhone.swift
//  TakeCareApp — Apply received watch data to iPhone SwiftData.
//

import Foundation
import SwiftData

public enum SyncApplyPhone {

    /// Call once when the app has a model context (e.g. from MainTabView .onAppear).
    public static func configure(modelContext: ModelContext) {
        let manager = WatchConnectivityManager.shared
        manager.onReceiveSession = { [weak modelContext] tuple in
            guard let modelContext else { return }
            applySession(context: modelContext, id: tuple.0, startedAt: tuple.1, sensitivityMode: tuple.2, hydrationCadence: tuple.3, autoEndTimeoutMinutes: tuple.4)
        }
        manager.onReceiveLog = { [weak modelContext] tuple in
            guard let modelContext else { return }
            applyLog(context: modelContext, tuple: tuple)
        }
        manager.onReceiveEndSession = { [weak modelContext] sessionId, endedAt in
            guard let modelContext else { return }
            applyEndSession(context: modelContext, sessionId: sessionId, endedAt: endedAt)
        }
    }

    private static func applySession(context: ModelContext, id: UUID, startedAt: Date, sensitivityMode: String, hydrationCadence: Int, autoEndTimeoutMinutes: Int) {
        let repo = SessionRepository(modelContext: context)
        if repo.session(by: id) != nil { return }
        let session = Session(id: id, startedAt: startedAt, endedAt: nil, sensitivityMode: sensitivityMode, hydrationCadence: hydrationCadence, autoEndTimeoutMinutes: autoEndTimeoutMinutes)
        context.insert(session)
        try? context.save()
    }

    private static func applyLog(context: ModelContext, tuple: (id: UUID, sessionId: UUID, timestamp: Date, drinkTypeId: String, standardDrinkUnits: Double, isAlcoholic: Bool, sourceDevice: String)) {
        let idStr = tuple.id.uuidString
        let descriptor = FetchDescriptor<DrinkLog>(predicate: #Predicate<DrinkLog> { $0.idString == idStr })
        if (try? context.fetch(descriptor).first) != nil { return }
        let sessionRepo = SessionRepository(modelContext: context)
        if sessionRepo.session(by: tuple.sessionId) == nil {
            let session = Session(id: tuple.sessionId, startedAt: tuple.timestamp, endedAt: nil, sensitivityMode: AppConstants.SensitivityMode.balanced.rawValue, hydrationCadence: 2, autoEndTimeoutMinutes: 180)
            context.insert(session)
        }
        let log = DrinkLog(id: tuple.id, sessionId: tuple.sessionId, timestamp: tuple.timestamp, drinkTypeId: tuple.drinkTypeId, standardDrinkUnits: tuple.standardDrinkUnits, isAlcoholic: tuple.isAlcoholic, sourceDevice: tuple.sourceDevice)
        context.insert(log)
        try? context.save()
    }

    private static func applyEndSession(context: ModelContext, sessionId: UUID, endedAt: Date) {
        let repo = SessionRepository(modelContext: context)
        guard let session = repo.session(by: sessionId) else { return }
        session.endedAt = endedAt
        try? context.save()
    }

    /// Call from phone when it has context and wants to push latest settings + drink types to watch (e.g. on app appear).
    public static func pushSettingsToWatch(context: ModelContext) {
        let settingsRepo = UserSettingsRepository(modelContext: context)
        let drinkTypeRepo = DrinkTypeConfigRepository(modelContext: context)
        guard let settings = settingsRepo.fetch() else { return }
        let configs = drinkTypeRepo.all()
        WatchConnectivityManager.shared.pushSettingsAndDrinkTypes(settings: settings, drinkTypes: configs)
    }
}
