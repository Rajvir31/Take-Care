//
//  PacingEventRepository.swift
//  TakeCareApp — Pacing event persistence (for dedupe and history).
//

import Foundation
import SwiftData

public protocol PacingEventRepositoryProtocol: Sendable {
    func add(event: PacingEvent)
    func events(for sessionId: UUID) -> [PacingEvent]
    func lastEvent(code: String, sessionId: UUID, withinMinutes: Int?) -> PacingEvent?
}

public final class PacingEventRepository: PacingEventRepositoryProtocol {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func add(event: PacingEvent) {
        modelContext.insert(event)
        try? modelContext.save()
    }

    public func events(for sessionId: UUID) -> [PacingEvent] {
        let idStr = sessionId.uuidString
        let descriptor = FetchDescriptor<PacingEvent>(
            predicate: #Predicate<PacingEvent> { $0.sessionIdString == idStr },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    public func lastEvent(code: String, sessionId: UUID, withinMinutes: Int?) -> PacingEvent? {
        let idStr = sessionId.uuidString
        var descriptor = FetchDescriptor<PacingEvent>(
            predicate: #Predicate<PacingEvent> { $0.sessionIdString == idStr && $0.code == code }
        )
        descriptor.sortBy = [SortDescriptor(\.timestamp, order: .reverse)]
        descriptor.fetchLimit = 1
        guard var events = try? modelContext.fetch(descriptor), let last = events.first else { return nil }
        if let min = withinMinutes {
            let cutoff = Date().addingTimeInterval(-TimeInterval(min * 60))
            if last.timestamp < cutoff { return nil }
        }
        return last
    }
}
