//
//  HistoryViewModel.swift
//  TakeCareApp — History tab: list of ended sessions.
//

import Foundation
import SwiftData
import SwiftUI

@Observable
@MainActor
final class HistoryViewModel {

    private let sessionRepo: SessionRepository

    var endedSessions: [Session] = []

    init(modelContext: ModelContext) {
        self.sessionRepo = SessionRepository(modelContext: modelContext)
    }

    func load() {
        endedSessions = sessionRepo.endedSessions(limit: 200)
    }
}
