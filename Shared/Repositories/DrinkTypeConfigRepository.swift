//
//  DrinkTypeConfigRepository.swift
//  TakeCareApp — Drink type defaults (editable in settings).
//

import Foundation
import SwiftData

public protocol DrinkTypeConfigRepositoryProtocol: Sendable {
    func all() -> [DrinkTypeConfig]
    func config(for id: String) -> DrinkTypeConfig?
    func update(_ config: DrinkTypeConfig)
    func seedDefaultsIfNeeded()
}

public final class DrinkTypeConfigRepository: DrinkTypeConfigRepositoryProtocol {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func all() -> [DrinkTypeConfig] {
        let descriptor = FetchDescriptor<DrinkTypeConfig>(sortBy: [SortDescriptor(\.sortOrder, order: .forward)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    public func config(for id: String) -> DrinkTypeConfig? {
        let descriptor = FetchDescriptor<DrinkTypeConfig>(predicate: #Predicate<DrinkTypeConfig> { $0.id == id })
        return try? modelContext.fetch(descriptor).first
    }

    public func update(_ config: DrinkTypeConfig) {
        try? modelContext.save()
    }

    public func seedDefaultsIfNeeded() {
        let existing = all()
        guard existing.isEmpty else { return }
        let defaults: [(String, String, Double, Bool, Int)] = [
            (AppConstants.DrinkTypeId.shot, "Shot", 1.0, true, 0),
            (AppConstants.DrinkTypeId.beer, "Beer", 1.0, true, 1),
            (AppConstants.DrinkTypeId.cocktail, "Cocktail", 1.5, true, 2),
            (AppConstants.DrinkTypeId.wine, "Wine", 1.0, true, 3),
            (AppConstants.DrinkTypeId.water, "Water", 0.0, false, 4)
        ]
        for (id, name, units, alcoholic, order) in defaults {
            let config = DrinkTypeConfig(id: id, displayName: name, defaultStandardUnits: units, isAlcoholic: alcoholic, isEnabled: true, sortOrder: order)
            modelContext.insert(config)
        }
        try? modelContext.save()
    }
}
