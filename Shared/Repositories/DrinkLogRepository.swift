//
//  DrinkLogRepository.swift
//  TakeCareApp — Drink log persistence.
//

import Foundation
import SwiftData

public protocol DrinkLogRepositoryProtocol: Sendable {
    func add(log: DrinkLog)
    func logs(for sessionId: UUID) -> [DrinkLog]
    func lastLog(for sessionId: UUID) -> DrinkLog?
    func delete(log: DrinkLog)
    @discardableResult func undoLast(sessionId: UUID) -> DrinkLog?
}

public final class DrinkLogRepository: DrinkLogRepositoryProtocol {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func add(log: DrinkLog) {
        modelContext.insert(log)
        try? modelContext.save()
    }

    public func logs(for sessionId: UUID) -> [DrinkLog] {
        let idStr = sessionId.uuidString
        let descriptor = FetchDescriptor<DrinkLog>(
            predicate: #Predicate<DrinkLog> { $0.sessionIdString == idStr },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    public func lastLog(for sessionId: UUID) -> DrinkLog? {
        let idStr = sessionId.uuidString
        var descriptor = FetchDescriptor<DrinkLog>(predicate: #Predicate<DrinkLog> { $0.sessionIdString == idStr })
        descriptor.sortBy = [SortDescriptor(\.timestamp, order: .reverse)]
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    public func delete(log: DrinkLog) {
        modelContext.delete(log)
        try? modelContext.save()
    }

    public func undoLast(sessionId: UUID) -> DrinkLog? {
        guard let last = lastLog(for: sessionId) else { return nil }
        delete(log: last)
        return last
    }
}
