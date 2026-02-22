//
//  SyncPayloadsTests.swift
//  TakeCareAppTests — Encode/decode round-trip for sync payloads.
//

import Foundation
import XCTest
@testable import TakeCareApp

final class SyncPayloadsTests: XCTestCase {

    func testSessionPayloadRoundTrip() {
        let id = UUID()
        let startedAt = Date()
        let payload = SyncPayloads.sessionPayload(id: id, startedAt: startedAt, sensitivityMode: "balanced", hydrationCadence: 2, autoEndTimeoutMinutes: 180)
        let parsed = SyncPayloads.parseSession(payload)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed!.id, id)
        XCTAssertEqual(parsed!.sensitivityMode, "balanced")
        XCTAssertEqual(parsed!.hydrationCadence, 2)
    }

    func testLogPayloadRoundTrip() {
        let id = UUID()
        let sessionId = UUID()
        let timestamp = Date()
        let payload = SyncPayloads.logPayload(id: id, sessionId: sessionId, timestamp: timestamp, drinkTypeId: AppConstants.DrinkTypeId.beer, standardDrinkUnits: 1, isAlcoholic: true, sourceDevice: AppConstants.SourceDevice.watch.rawValue)
        let parsed = SyncPayloads.parseLog(payload)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed!.id, id)
        XCTAssertEqual(parsed!.sessionId, sessionId)
        XCTAssertEqual(parsed!.drinkTypeId, AppConstants.DrinkTypeId.beer)
        XCTAssertEqual(parsed!.standardDrinkUnits, 1)
        XCTAssertTrue(parsed!.isAlcoholic)
    }

    func testEndSessionPayloadRoundTrip() {
        let sessionId = UUID()
        let endedAt = Date()
        let payload = SyncPayloads.endSessionPayload(sessionId: sessionId, endedAt: endedAt)
        let parsed = SyncPayloads.parseEndSession(payload)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed!.sessionId, sessionId)
    }
}
