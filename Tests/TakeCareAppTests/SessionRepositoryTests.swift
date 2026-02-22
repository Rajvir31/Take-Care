//
//  SessionRepositoryTests.swift
//  TakeCareAppTests — Session auto-end and repository logic.
//

import Foundation
import SwiftData
import XCTest
@testable import TakeCareApp

final class SessionRepositoryTests: XCTestCase {

    private var modelContext: ModelContext!
    private var container: ModelContainer!

    override func setUp() {
        super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: TakeCareSchema.schema, configurations: [config])
        modelContext = ModelContext(container)
    }

    override func tearDown() {
        modelContext = nil
        container = nil
        super.tearDown()
    }

    func testAutoEndIfNeededEndsSessionAfterTimeout() {
        let settings = UserSettings(sensitivityMode: AppConstants.SensitivityMode.balanced.rawValue, autoEndTimeoutMinutes: 1)
        modelContext.insert(settings)
        try? modelContext.save()

        let repo = SessionRepository(modelContext: modelContext)
        let session = repo.startSession(settings: settings)
        let now = Date()
        let log = DrinkLog(sessionId: session.id, timestamp: now.addingTimeInterval(-90), drinkTypeId: AppConstants.DrinkTypeId.beer, standardDrinkUnits: 1, isAlcoholic: true, sourceDevice: AppConstants.SourceDevice.phone.rawValue)
        modelContext.insert(log)
        try? modelContext.save()

        let ended = repo.autoEndIfNeeded(timeoutMinutes: 60, now: now)
        XCTAssertTrue(ended)
        XCTAssertNotNil(repo.session(by: session.id)?.endedAt)
    }

    func testAutoEndIfNeededDoesNotEndWhenWithinTimeout() {
        let settings = UserSettings(sensitivityMode: AppConstants.SensitivityMode.balanced.rawValue, autoEndTimeoutMinutes: 180)
        modelContext.insert(settings)
        try? modelContext.save()

        let repo = SessionRepository(modelContext: modelContext)
        let session = repo.startSession(settings: settings)
        let now = Date()
        let log = DrinkLog(sessionId: session.id, timestamp: now.addingTimeInterval(-10 * 60), drinkTypeId: AppConstants.DrinkTypeId.beer, standardDrinkUnits: 1, isAlcoholic: true, sourceDevice: AppConstants.SourceDevice.phone.rawValue)
        modelContext.insert(log)
        try? modelContext.save()

        let ended = repo.autoEndIfNeeded(timeoutMinutes: 60, now: now)
        XCTAssertFalse(ended)
        XCTAssertNil(repo.session(by: session.id)?.endedAt)
    }

    func testEndedSessionsExcludesActive() {
        let settings = UserSettings(sensitivityMode: AppConstants.SensitivityMode.balanced.rawValue)
        modelContext.insert(settings)
        try? modelContext.save()

        let repo = SessionRepository(modelContext: modelContext)
        _ = repo.startSession(settings: settings)
        let endedList = repo.endedSessions(limit: 10)
        XCTAssertTrue(endedList.isEmpty)
    }
}
