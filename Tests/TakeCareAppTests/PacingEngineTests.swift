//
//  PacingEngineTests.swift
//  TakeCareAppTests — Unit tests for PacingEngine and rolling-window helpers.
//

import Foundation
import XCTest
@testable import TakeCareApp

// Use @Suite and @Test (Swift Testing) if available, else XCTest. Prefer XCTest for widest compatibility.
import XCTest

private func log(_ t: Date, _ typeId: String, units: Double, alcoholic: Bool) -> DrinkLogSnapshot {
    DrinkLogSnapshot(timestamp: t, drinkTypeId: typeId, standardDrinkUnits: units, isAlcoholic: alcoholic)
}

private func event(_ t: Date, code: String, severity: Int = 1) -> PacingEventSnapshot {
    PacingEventSnapshot(timestamp: t, code: code, severity: severity)
}

private func settings(_ mode: String, hydration: Bool = true, cadence: Int = 2) -> UserSettingsSnapshot {
    UserSettingsSnapshot(sensitivityMode: mode, hydrationRemindersEnabled: hydration, hydrationCadence: cadence)
}

final class PacingEngineTests: XCTestCase {

    // MARK: - Rolling window helpers

    func testAlcoholicDrinkCount() {
        let base = Date()
        let logs: [DrinkLogSnapshot] = [
            log(base.addingTimeInterval(-5 * 60), AppConstants.DrinkTypeId.beer, units: 1, alcoholic: true),
            log(base.addingTimeInterval(-3 * 60), AppConstants.DrinkTypeId.water, units: 0, alcoholic: false),
            log(base.addingTimeInterval(-2 * 60), AppConstants.DrinkTypeId.shot, units: 1, alcoholic: true)
        ]
        XCTAssertEqual(RollingWindowHelpers.alcoholicDrinkCount(in: 10, from: base, logs: logs), 2)
        XCTAssertEqual(RollingWindowHelpers.alcoholicDrinkCount(in: 2, from: base, logs: logs), 1)
    }

    func testStandardDrinkUnits() {
        let base = Date()
        let logs: [DrinkLogSnapshot] = [
            log(base.addingTimeInterval(-50 * 60), AppConstants.DrinkTypeId.beer, units: 1, alcoholic: true),
            log(base.addingTimeInterval(-30 * 60), AppConstants.DrinkTypeId.wine, units: 1, alcoholic: true),
            log(base.addingTimeInterval(-10 * 60), AppConstants.DrinkTypeId.cocktail, units: 1.5, alcoholic: true)
        ]
        XCTAssertEqual(RollingWindowHelpers.standardDrinkUnits(in: 60, from: base, logs: logs), 3.5)
        XCTAssertEqual(RollingWindowHelpers.standardDrinkUnits(in: 20, from: base, logs: logs), 1.5)
    }

    func testTimeSinceLastAlcoholicDrink() {
        let base = Date()
        let logs: [DrinkLogSnapshot] = [
            log(base.addingTimeInterval(-25 * 60), AppConstants.DrinkTypeId.beer, units: 1, alcoholic: true)
        ]
        let interval = RollingWindowHelpers.timeSinceLastAlcoholicDrink(from: base, logs: logs)
        XCTAssertNotNil(interval)
        XCTAssertEqual(Int(interval! / 60), 25)
        XCTAssertNil(RollingWindowHelpers.timeSinceLastAlcoholicDrink(from: base, logs: []))
    }

    func testCountDrinkTypeInWindow() {
        let base = Date()
        let logs: [DrinkLogSnapshot] = [
            log(base.addingTimeInterval(-5 * 60), AppConstants.DrinkTypeId.shot, units: 1, alcoholic: true),
            log(base.addingTimeInterval(-2 * 60), AppConstants.DrinkTypeId.shot, units: 1, alcoholic: true)
        ]
        XCTAssertEqual(RollingWindowHelpers.count(drinkTypeId: AppConstants.DrinkTypeId.shot, in: 10, from: base, logs: logs), 2)
        XCTAssertEqual(RollingWindowHelpers.count(drinkTypeId: AppConstants.DrinkTypeId.beer, in: 10, from: base, logs: logs), 0)
    }

    // MARK: - PacingEngine: 2 shots within 10 min triggers warning in Balanced

    func testTwoShotsWithin10MinutesBalancedTriggersWarning() {
        let base = Date()
        let logs: [DrinkLogSnapshot] = [
            log(base.addingTimeInterval(-8 * 60), AppConstants.DrinkTypeId.shot, units: 1, alcoholic: true),
            log(base.addingTimeInterval(-1 * 60), AppConstants.DrinkTypeId.shot, units: 1, alcoholic: true)
        ]
        let result = PacingEngine.evaluate(logs: logs, settings: settings(AppConstants.SensitivityMode.balanced.rawValue), currentTime: base, recentEvents: [])
        let shotStack = result.eventsToEmit.first { $0.code == AppConstants.PacingEventCode.shotStacking.rawValue }
        XCTAssertNotNil(shotStack)
        XCTAssertEqual(result.paceStatus, AppConstants.PaceStatus.caution.rawValue)
    }

    // MARK: - 4 drinks across 90 min triggers escalation in Balanced

    func testFourUnitsIn90MinutesBalancedTriggersEscalation() {
        let base = Date()
        let logs: [DrinkLogSnapshot] = [
            log(base.addingTimeInterval(-80 * 60), AppConstants.DrinkTypeId.beer, units: 1, alcoholic: true),
            log(base.addingTimeInterval(-50 * 60), AppConstants.DrinkTypeId.beer, units: 1, alcoholic: true),
            log(base.addingTimeInterval(-30 * 60), AppConstants.DrinkTypeId.wine, units: 1, alcoholic: true),
            log(base.addingTimeInterval(-5 * 60), AppConstants.DrinkTypeId.beer, units: 1, alcoholic: true)
        ]
        let result = PacingEngine.evaluate(logs: logs, settings: settings(AppConstants.SensitivityMode.balanced.rawValue), currentTime: base, recentEvents: [])
        let escalation = result.eventsToEmit.first { $0.code == AppConstants.PacingEventCode.escalation.rawValue }
        XCTAssertNotNil(escalation)
        XCTAssertEqual(result.paceStatus, AppConstants.PaceStatus.slowDown.rawValue)
    }

    // MARK: - Hydration reminder every 2 alcoholic drinks

    func testHydrationReminderEveryTwoAlcoholicDrinks() {
        let base = Date()
        let logs: [DrinkLogSnapshot] = [
            log(base.addingTimeInterval(-60 * 60), AppConstants.DrinkTypeId.beer, units: 1, alcoholic: true),
            log(base.addingTimeInterval(-30 * 60), AppConstants.DrinkTypeId.beer, units: 1, alcoholic: true)
        ]
        let result = PacingEngine.evaluate(logs: logs, settings: settings(AppConstants.SensitivityMode.balanced.rawValue, hydration: true, cadence: 2), currentTime: base, recentEvents: [])
        let hydrate = result.eventsToEmit.first { $0.code == AppConstants.PacingEventCode.hydrate.rawValue }
        XCTAssertNotNil(hydrate)
    }

    // MARK: - Same warning does not repeat within cooldown

    func testSameWarningDoesNotRepeatWithinCooldown() {
        let base = Date()
        let logs: [DrinkLogSnapshot] = [
            log(base.addingTimeInterval(-8 * 60), AppConstants.DrinkTypeId.shot, units: 1, alcoholic: true),
            log(base.addingTimeInterval(-1 * 60), AppConstants.DrinkTypeId.shot, units: 1, alcoholic: true)
        ]
        let recent = [event(base.addingTimeInterval(-10 * 60), code: AppConstants.PacingEventCode.shotStacking.rawValue)]
        let result = PacingEngine.evaluate(logs: logs, settings: settings(AppConstants.SensitivityMode.balanced.rawValue), currentTime: base, recentEvents: recent)
        let shotStackAgain = result.eventsToEmit.first { $0.code == AppConstants.PacingEventCode.shotStacking.rawValue }
        XCTAssertNil(shotStackAgain)
    }

    // MARK: - Sensitivity presets

    func testStrictThresholdsTighterThanBalanced() {
        let presetS = SensitivityPresets.strict
        let presetB = SensitivityPresets.balanced
        XCTAssertLessThan(presetS.fastPaceUnitsPer60Min, presetB.fastPaceUnitsPer60Min)
        XCTAssertLessThan(presetS.escalationUnitsPer90Min, presetB.escalationUnitsPer90Min)
    }

    func testGoodPaceWithNoLogs() {
        let result = PacingEngine.evaluate(logs: [], settings: settings(AppConstants.SensitivityMode.balanced.rawValue), currentTime: Date(), recentEvents: [])
        XCTAssertEqual(result.paceStatus, AppConstants.PaceStatus.good.rawValue)
        XCTAssertTrue(result.eventsToEmit.isEmpty)
    }
}
