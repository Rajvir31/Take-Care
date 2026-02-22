//
//  UserSettingsRepository.swift
//  TakeCareApp — User settings (singleton-like fetch/save).
//

import Foundation
import SwiftData

public protocol UserSettingsRepositoryProtocol: Sendable {
    func fetch() -> UserSettings?
    func save(_ settings: UserSettings)
}

public final class UserSettingsRepository: UserSettingsRepositoryProtocol {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func fetch() -> UserSettings? {
        let descriptor = FetchDescriptor<UserSettings>()
        return try? modelContext.fetch(descriptor).first
    }

    public func save(_ settings: UserSettings) {
        try? modelContext.save()
    }
}
