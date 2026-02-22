//
//  WatchConnectivityManager.swift
//  TakeCareApp — Watch ↔ iPhone sync via WCSession.
//

import Foundation
import WatchConnectivity

/// Callbacks are invoked on the main queue. Set from the app that has ModelContext.
public final class WatchConnectivityManager: NSObject, @unchecked Sendable {

    public static let shared = WatchConnectivityManager()

    private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil

    /// Phone: apply received session from watch. Params: (id, startedAt, sensitivityMode, hydrationCadence, autoEndTimeoutMinutes).
    public var onReceiveSession: (((UUID, Date, String, Int, Int)) -> Void)?

    /// Phone: apply received drink log from watch. Params: decoded log tuple from SyncPayloads.parseLog.
    public var onReceiveLog: (((id: UUID, sessionId: UUID, timestamp: Date, drinkTypeId: String, standardDrinkUnits: Double, isAlcoholic: Bool, sourceDevice: String)) -> Void)?

    /// Phone: apply received end-session from watch. Params: (sessionId, endedAt).
    public var onReceiveEndSession: (((UUID, Date)) -> Void)?

    /// Watch: apply received settings from phone. Param: raw dict from context (settings key).
    public var onReceiveSettings: (([String: Any]) -> Void)?

    /// Watch: apply received drink types from phone. Param: array of item dicts.
    public var onReceiveDrinkTypes: (([[String: Any]]) -> Void)?

    public var isReachable: Bool { session?.isReachable ?? false }

    override init() {
        super.init()
        session?.delegate = self
        session?.activate()
    }

    // MARK: - Watch → Phone (call from watch)

    public func sendSession(id: UUID, startedAt: Date, sensitivityMode: String, hydrationCadence: Int, autoEndTimeoutMinutes: Int) {
        let payload = SyncPayloads.sessionPayload(id: id, startedAt: startedAt, sensitivityMode: sensitivityMode, hydrationCadence: hydrationCadence, autoEndTimeoutMinutes: autoEndTimeoutMinutes)
        send(payload: payload)
    }

    public func sendLog(id: UUID, sessionId: UUID, timestamp: Date, drinkTypeId: String, standardDrinkUnits: Double, isAlcoholic: Bool, sourceDevice: String) {
        let payload = SyncPayloads.logPayload(id: id, sessionId: sessionId, timestamp: timestamp, drinkTypeId: drinkTypeId, standardDrinkUnits: standardDrinkUnits, isAlcoholic: isAlcoholic, sourceDevice: sourceDevice)
        send(payload: payload)
    }

    public func sendEndSession(sessionId: UUID, endedAt: Date) {
        let payload = SyncPayloads.endSessionPayload(sessionId: sessionId, endedAt: endedAt)
        send(payload: payload)
    }

    private func send(payload: [String: Any]) {
        guard let session else { return }
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { [weak self] _ in
                self?.transferUserInfo(payload)
            }
        } else {
            transferUserInfo(payload)
        }
    }

    private func transferUserInfo(_ payload: [String: Any]) {
        session?.transferUserInfo(payload)
    }

    // MARK: - Phone → Watch (call from phone)

    public func pushSettings(_ settings: UserSettings) {
        let payload = SyncPayloads.settingsPayload(from: settings)
        updateApplicationContext(payload)
    }

    public func pushSettingsAndDrinkTypes(settings: UserSettings, drinkTypes: [DrinkTypeConfig]) {
        var ctx = session?.applicationContext ?? [:]
        let settingsPayload = SyncPayloads.settingsPayload(from: settings)
        for (k, v) in settingsPayload { ctx[k] = v }
        ctx[SyncPayloads.Key.type] = SyncPayloads.MessageType.settings.rawValue
        session?.transferUserInfo(SyncPayloads.drinkTypesPayload(configs: drinkTypes))
        session?.updateApplicationContext(ctx)
    }

    private func updateApplicationContext(_ context: [String: Any]) {
        session?.updateApplicationContext(context)
    }
}

extension WatchConnectivityManager: WCSessionDelegate {

    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {}

    #if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {}
    public func sessionDidDeactivate(_ session: WCSession) {}
    #endif

    public func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        dispatchToMain {
            self.applyReceivedContext(applicationContext)
        }
    }

    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        dispatchToMain {
            self.applyReceivedMessage(userInfo)
        }
    }

    public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        dispatchToMain {
            self.applyReceivedMessage(message)
        }
    }

    private func dispatchToMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }

    private func applyReceivedContext(_ dict: [String: Any]) {
        if SyncPayloads.parseSettings(dict) != nil {
            onReceiveSettings?(dict)
        }
    }

    private func applyReceivedMessage(_ dict: [String: Any]) {
        guard let typeStr = dict[SyncPayloads.Key.type] as? String,
              let type = SyncPayloads.MessageType(rawValue: typeStr) else { return }
        switch type {
        case .session:
            if let parsed = SyncPayloads.parseSession(dict) {
                onReceiveSession?((parsed.id, parsed.startedAt, parsed.sensitivityMode, parsed.hydrationCadence, parsed.autoEndTimeoutMinutes))
            }
        case .log:
            if let parsed = SyncPayloads.parseLog(dict) {
                onReceiveLog?(parsed)
            }
        case .endSession:
            if let parsed = SyncPayloads.parseEndSession(dict) {
                onReceiveEndSession?((parsed.sessionId, parsed.endedAt))
            }
        case .settings:
            if SyncPayloads.parseSettings(dict) != nil {
                onReceiveSettings?(dict)
            }
        case .drinkTypes:
            if let items = SyncPayloads.parseDrinkTypes(dict) {
                onReceiveDrinkTypes?(items)
            }
        }
    }
}
