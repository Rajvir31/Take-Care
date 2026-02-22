//
//  SessionRepository.swift
//  TakeCareApp — Session persistence and current-session logic.
//

import Foundation
import SwiftData

public protocol SessionRepositoryProtocol: Sendable {
    func currentSession() -> Session?
    func startSession(settings: UserSettings) -> Session
    func endSession(_ session: Session)
    func session(by id: UUID) -> Session?
    func sessions(from start: Date, to end: Date) -> [Session]
    func endedSessions(limit: Int?) -> [Session]
    func autoEndIfNeeded(timeoutMinutes: Int, now: Date) -> Bool
}

public final class SessionRepository: SessionRepositoryProtocol {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func currentSession() -> Session? {
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { $0.endedAt == nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return try? modelContext.fetch(descriptor).first
    }

    public func startSession(settings: UserSettings) -> Session {
        let session = Session(
            sensitivityMode: settings.sensitivityMode,
            hydrationCadence: settings.hydrationCadence,
            autoEndTimeoutMinutes: settings.autoEndTimeoutMinutes
        )
        modelContext.insert(session)
        try? modelContext.save()
        return session
    }

    public func endSession(_ session: Session) {
        session.endedAt = Date()
        try? modelContext.save()
    }

    public func session(by id: UUID) -> Session? {
        let idStr = id.uuidString
        let descriptor = FetchDescriptor<Session>(predicate: #Predicate<Session> { $0.idString == idStr })
        return try? modelContext.fetch(descriptor).first
    }

    public func sessions(from start: Date, to end: Date) -> [Session] {
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { $0.startedAt >= start && $0.startedAt <= end },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Ended sessions for History tab; most recent first. Pass nil for no limit.
    public func endedSessions(limit: Int?) -> [Session] {
        let oldDate = Calendar.current.date(byAdding: .year, value: -10, to: Date()) ?? Date()
        var descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { $0.startedAt >= oldDate },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 500
        let filtered = ((try? modelContext.fetch(descriptor)) ?? []).filter { $0.endedAt != nil }
        if let limit { return Array(filtered.prefix(limit)) }
        return filtered
    }

    /// If current session exists and last alcoholic drink was longer than timeout ago, end session. Returns true if ended.
    public func autoEndIfNeeded(timeoutMinutes: Int, now: Date) -> Bool {
        guard let session = currentSession() else { return false }
        let logs = (try? modelContext.fetch(FetchDescriptor<DrinkLog>(
            predicate: #Predicate<DrinkLog> { $0.sessionIdString == session.idString }
        ))) ?? []
        let snapshots = logs.map { DrinkLogSnapshot(timestamp: $0.timestamp, drinkTypeId: $0.drinkTypeId, standardDrinkUnits: $0.standardDrinkUnits, isAlcoholic: $0.isAlcoholic) }
        guard let interval = RollingWindowHelpers.timeSinceLastAlcoholicDrink(from: now, logs: snapshots) else {
            return false
        }
        if interval >= TimeInterval(timeoutMinutes * 60) {
            endSession(session)
            return true
        }
        return false
    }
}
