//
//  InsightsViewModel.swift
//  TakeCareApp — Insights: aggregates for charts and stats.
//

import Foundation
import SwiftData
import SwiftUI

struct SessionStats: Identifiable {
    var sessionId: UUID
    var startedAt: Date
    var drinkCount: Int
    var totalUnits: Double
    var durationMinutes: Int?
    var warningCount: Int
    var id: UUID { sessionId }
}

@Observable
@MainActor
final class InsightsViewModel {

    private let modelContext: ModelContext
    private let sessionRepo: SessionRepository
    private let drinkLogRepo: DrinkLogRepository
    private let pacingEventRepo: PacingEventRepository

    var sessionStats: [SessionStats] = []
    var averageSessionDurationMinutes: Double?
    var totalWarningsCount: Int = 0
    var mostCommonDrinkTypeId: String?
    var drinkTypeCounts: [String: Int] = [:]
    /// Hour of day (0–23) when warnings most often occurred (for "typical fast-pace window").
    var typicalWarningHour: Int?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.sessionRepo = SessionRepository(modelContext: modelContext)
        self.drinkLogRepo = DrinkLogRepository(modelContext: modelContext)
        self.pacingEventRepo = PacingEventRepository(modelContext: modelContext)
    }

    func load() {
        let sessions = sessionRepo.endedSessions(limit: 500)
        var stats: [SessionStats] = []
        var allDrinkTypes: [String: Int] = [:]
        var warningHours: [Int] = []

        for session in sessions {
            let logs = drinkLogRepo.logs(for: session.id)
            let events = pacingEventRepo.events(for: session.id)
            let alcoholicCount = logs.filter { $0.isAlcoholic }.count
            let units = logs.reduce(0) { $0 + $1.standardDrinkUnits }
            var durationMinutes: Int? = nil
            if let end = session.endedAt {
                durationMinutes = Int(end.timeIntervalSince(session.startedAt) / 60)
            }
            stats.append(SessionStats(
                sessionId: session.id,
                startedAt: session.startedAt,
                drinkCount: alcoholicCount,
                totalUnits: units,
                durationMinutes: durationMinutes,
                warningCount: events.count
            ))
            for log in logs where log.isAlcoholic {
                allDrinkTypes[log.drinkTypeId, default: 0] += 1
            }
            let calendar = Calendar.current
            for ev in events {
                warningHours.append(calendar.component(.hour, from: ev.timestamp))
            }
        }

        sessionStats = stats
        drinkTypeCounts = allDrinkTypes
        mostCommonDrinkTypeId = allDrinkTypes.max(by: { $0.value < $1.value })?.key

        let durations = stats.compactMap { $0.durationMinutes }.filter { $0 > 0 }
        if !durations.isEmpty {
            averageSessionDurationMinutes = Double(durations.reduce(0, +)) / Double(durations.count)
        } else {
            averageSessionDurationMinutes = nil
        }

        totalWarningsCount = stats.reduce(0) { $0 + $1.warningCount }

        if !warningHours.isEmpty {
            let byHour = Dictionary(grouping: warningHours, by: { $0 }).mapValues { $0.count }
            typicalWarningHour = byHour.max(by: { $0.value < $1.value })?.key
        } else {
            typicalWarningHour = nil
        }
    }
}
