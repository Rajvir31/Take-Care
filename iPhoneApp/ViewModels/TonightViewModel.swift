//
//  TonightViewModel.swift
//  TakeCareApp — Tonight tab: current session, logs, pacing (iPhone).
//

import Foundation
import SwiftData
import SwiftUI

@Observable
@MainActor
final class TonightViewModel {

    private let modelContext: ModelContext
    private let sessionRepo: SessionRepository
    private let drinkLogRepo: DrinkLogRepository
    private let pacingEventRepo: PacingEventRepository
    private let userSettingsRepo: UserSettingsRepository
    private let drinkTypeRepo: DrinkTypeConfigRepository

    var currentSession: Session?
    var sessionLogs: [DrinkLog] = []
    var paceStatus: String = AppConstants.PaceStatus.good.rawValue
    var timeSinceLastDrink: TimeInterval?
    var totalAlcoholicDrinks: Int { sessionLogs.filter { $0.isAlcoholic }.count }
    var totalWaterLogs: Int { sessionLogs.filter { $0.drinkTypeId == AppConstants.DrinkTypeId.water }.count }
    var totalStandardUnits: Double { sessionLogs.reduce(0) { $0 + $1.standardDrinkUnits } }
    var lastWarningMessage: String?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.sessionRepo = SessionRepository(modelContext: modelContext)
        self.drinkLogRepo = DrinkLogRepository(modelContext: modelContext)
        self.pacingEventRepo = PacingEventRepository(modelContext: modelContext)
        self.userSettingsRepo = UserSettingsRepository(modelContext: modelContext)
        self.drinkTypeRepo = DrinkTypeConfigRepository(modelContext: modelContext)
        drinkTypeRepo.seedDefaultsIfNeeded()
    }

    func load() {
        ensureUserSettingsExists()
        currentSession = sessionRepo.currentSession()
        refreshLogsAndPace()
    }

    private func ensureUserSettingsExists() {
        if userSettingsRepo.fetch() == nil {
            let settings = UserSettings()
            modelContext.insert(settings)
            try? modelContext.save()
        }
    }

    private func refreshLogsAndPace() {
        guard let session = currentSession else {
            sessionLogs = []
            paceStatus = AppConstants.PaceStatus.good.rawValue
            timeSinceLastDrink = nil
            return
        }
        sessionLogs = drinkLogRepo.logs(for: session.id)
        let now = Date()
        let snapshots = sessionLogs.map { DrinkLogSnapshot(timestamp: $0.timestamp, drinkTypeId: $0.drinkTypeId, standardDrinkUnits: $0.standardDrinkUnits, isAlcoholic: $0.isAlcoholic) }
        timeSinceLastDrink = RollingWindowHelpers.timeSinceLastAlcoholicDrink(from: now, logs: snapshots)

        guard let settings = userSettingsRepo.fetch() else { return }
        let settingsSnapshot = UserSettingsSnapshot(
            sensitivityMode: settings.sensitivityMode,
            hydrationRemindersEnabled: settings.hydrationRemindersEnabled,
            hydrationCadence: settings.hydrationCadence
        )
        let recentEvents = pacingEventRepo.events(for: session.id).suffix(50).map { PacingEventSnapshot(timestamp: $0.timestamp, code: $0.code, severity: $0.severity) }
        let result = PacingEngine.evaluate(logs: snapshots, settings: settingsSnapshot, currentTime: now, recentEvents: Array(recentEvents))
        paceStatus = result.paceStatus
    }

    func addDrink(drinkTypeId: String) {
        guard let config = drinkTypeRepo.config(for: drinkTypeId), config.isEnabled else { return }
        var session = currentSession
        if session == nil, let settings = userSettingsRepo.fetch() {
            session = sessionRepo.startSession(settings: settings)
            currentSession = session
        }
        guard let session else { return }

        let log = DrinkLog(
            sessionId: session.id,
            drinkTypeId: config.id,
            standardDrinkUnits: config.defaultStandardUnits,
            isAlcoholic: config.isAlcoholic,
            sourceDevice: AppConstants.SourceDevice.phone.rawValue
        )
        drinkLogRepo.add(log: log)
        sessionLogs = drinkLogRepo.logs(for: session.id)

        let now = Date()
        let snapshots = sessionLogs.map { DrinkLogSnapshot(timestamp: $0.timestamp, drinkTypeId: $0.drinkTypeId, standardDrinkUnits: $0.standardDrinkUnits, isAlcoholic: $0.isAlcoholic) }
        guard let settings = userSettingsRepo.fetch() else {
            refreshLogsAndPace()
            return
        }
        let settingsSnapshot = UserSettingsSnapshot(
            sensitivityMode: settings.sensitivityMode,
            hydrationRemindersEnabled: settings.hydrationRemindersEnabled,
            hydrationCadence: settings.hydrationCadence
        )
        let recentEvents = pacingEventRepo.events(for: session.id).map { PacingEventSnapshot(timestamp: $0.timestamp, code: $0.code, severity: $0.severity) }
        let result = PacingEngine.evaluate(logs: snapshots, settings: settingsSnapshot, currentTime: now, recentEvents: recentEvents)

        for eventToEmit in result.eventsToEmit {
            let event = PacingEvent(
                sessionId: session.id,
                eventType: eventToEmit.eventType,
                code: eventToEmit.code,
                message: eventToEmit.message,
                severity: eventToEmit.severity
            )
            pacingEventRepo.add(event: event)
            lastWarningMessage = eventToEmit.message
        }
        paceStatus = result.paceStatus
        timeSinceLastDrink = RollingWindowHelpers.timeSinceLastAlcoholicDrink(from: now, logs: snapshots)
    }

    func undoLast() {
        guard let session = currentSession else { return }
        _ = drinkLogRepo.undoLast(sessionId: session.id)
        refreshLogsAndPace()
    }

    func startSession() {
        guard currentSession == nil, let settings = userSettingsRepo.fetch() else { return }
        currentSession = sessionRepo.startSession(settings: settings)
        sessionLogs = []
        paceStatus = AppConstants.PaceStatus.good.rawValue
        timeSinceLastDrink = nil
        lastWarningMessage = nil
    }

    func endSession() {
        guard let session = currentSession else { return }
        sessionRepo.endSession(session)
        currentSession = nil
        sessionLogs = []
        paceStatus = AppConstants.PaceStatus.good.rawValue
        timeSinceLastDrink = nil
        lastWarningMessage = nil
    }
}
