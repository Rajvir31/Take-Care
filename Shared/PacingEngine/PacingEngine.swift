//
//  PacingEngine.swift
//  TakeCareApp — Rule-based pacing coach (no BAC). Deterministic, testable.
//

import Foundation

/// Result of a single evaluation: events to emit, pace status, and optional next check interval (seconds).
public struct PacingEngineResult: Sendable {
    public let eventsToEmit: [PacingEventToEmit]
    public let paceStatus: String
    public let nextCheckIntervalSeconds: TimeInterval?

    public init(eventsToEmit: [PacingEventToEmit], paceStatus: String, nextCheckIntervalSeconds: TimeInterval? = nil) {
        self.eventsToEmit = eventsToEmit
        self.paceStatus = paceStatus
        self.nextCheckIntervalSeconds = nextCheckIntervalSeconds
    }
}

/// Suggested event for the caller to persist and trigger haptic/notification.
public struct PacingEventToEmit: Sendable {
    public let eventType: String
    public let code: String
    public let message: String
    public let severity: Int

    public init(eventType: String, code: String, message: String, severity: Int) {
        self.eventType = eventType
        self.code = code
        self.message = message
        self.severity = severity
    }
}

public enum PacingEngine {

    /// Evaluate pacing given current session logs, settings, time, and recent events (for dedupe).
    /// Caller should persist emitted events and trigger haptics/notifications.
    public static func evaluate(
        logs: [DrinkLogSnapshot],
        settings: UserSettingsSnapshot,
        currentTime: Date = Date(),
        recentEvents: [PacingEventSnapshot] = []
    ) -> PacingEngineResult {
        let preset = SensitivityPresets.preset(for: settings.sensitivityMode)
        var events: [PacingEventToEmit] = []
        var paceStatus: String = AppConstants.PaceStatus.good.rawValue

        // Helper: same code fired within last 15 min?
        func lastFired(code: String, withinMinutes minutes: Int = AppConstants.warningCooldownMinutes) -> Bool {
            let cutoff = currentTime.addingTimeInterval(-TimeInterval(minutes * 60))
            return recentEvents.contains { $0.code == code && $0.timestamp >= cutoff }
        }

        // Helper: last hydration reminder within 20 min?
        func lastHydrationWithin20Min() -> Bool {
            lastFired(code: AppConstants.PacingEventCode.hydrate.rawValue, withinMinutes: AppConstants.hydrationReminderCooldownMinutes)
        }

        // 1) Rapid repeat: 2+ alcoholic drinks in window
        let rapidCount = RollingWindowHelpers.alcoholicDrinkCount(in: preset.rapidRepeatWindowMinutes, from: currentTime, logs: logs)
        if rapidCount >= 2, !lastFired(code: AppConstants.PacingEventCode.rapidRepeat.rawValue) {
            events.append(PacingEventToEmit(
                eventType: AppConstants.PacingEventType.warning.rawValue,
                code: AppConstants.PacingEventCode.rapidRepeat.rawValue,
                message: "Two drinks close together. Slow it down.",
                severity: 1
            ))
            if paceStatus == AppConstants.PaceStatus.good.rawValue { paceStatus = AppConstants.PaceStatus.caution.rawValue }
        }

        // 2) Fast pace: > X units in 60 min
        let units60 = RollingWindowHelpers.standardDrinkUnits(in: 60, from: currentTime, logs: logs)
        if units60 > preset.fastPaceUnitsPer60Min, !lastFired(code: AppConstants.PacingEventCode.fastPace.rawValue) {
            events.append(PacingEventToEmit(
                eventType: AppConstants.PacingEventType.warning.rawValue,
                code: AppConstants.PacingEventCode.fastPace.rawValue,
                message: "You're pacing fast. Take a 20 min break.",
                severity: 2
            ))
            paceStatus = AppConstants.PaceStatus.slowDown.rawValue
        }

        // 3) Escalation: >= Y units in 90 min
        let units90 = RollingWindowHelpers.standardDrinkUnits(in: 90, from: currentTime, logs: logs)
        if units90 >= preset.escalationUnitsPer90Min, !lastFired(code: AppConstants.PacingEventCode.escalation.rawValue) {
            events.append(PacingEventToEmit(
                eventType: AppConstants.PacingEventType.warning.rawValue,
                code: AppConstants.PacingEventCode.escalation.rawValue,
                message: "Slow down and drink some water.",
                severity: 3
            ))
            paceStatus = AppConstants.PaceStatus.slowDown.rawValue
            if settings.hydrationRemindersEnabled, !lastHydrationWithin20Min() {
                events.append(PacingEventToEmit(
                    eventType: AppConstants.PacingEventType.reminder.rawValue,
                    code: AppConstants.PacingEventCode.hydrate.rawValue,
                    message: "Water check 💧",
                    severity: 1
                ))
            }
        }

        // 4) Shot stacking: 2+ shots in window
        let shotCount = RollingWindowHelpers.count(drinkTypeId: AppConstants.DrinkTypeId.shot, in: preset.shotStackWindowMinutes, from: currentTime, logs: logs)
        if shotCount >= 2, !lastFired(code: AppConstants.PacingEventCode.shotStacking.rawValue) {
            events.append(PacingEventToEmit(
                eventType: AppConstants.PacingEventType.warning.rawValue,
                code: AppConstants.PacingEventCode.shotStacking.rawValue,
                message: "Two shots close together. Take a break for 20 min.",
                severity: 2
            ))
            if paceStatus == AppConstants.PaceStatus.good.rawValue { paceStatus = AppConstants.PaceStatus.caution.rawValue }
        }

        // 5) Hydration reminder: every N alcoholic drinks, max once per 20 min
        if settings.hydrationRemindersEnabled, !lastHydrationWithin20Min() {
            let totalAlcoholic = RollingWindowHelpers.totalAlcoholicDrinkCount(from: currentTime, logs: logs)
            let n = settings.hydrationCadence
            if n > 0, totalAlcoholic > 0, totalAlcoholic % n == 0 {
                events.append(PacingEventToEmit(
                    eventType: AppConstants.PacingEventType.reminder.rawValue,
                    code: AppConstants.PacingEventCode.hydrate.rawValue,
                    message: "Water check 💧",
                    severity: 1
                ))
            }
        }

        // 6) Positive reinforcement: a warning fired before and no alcoholic drinks for 20 min
        let hasWarningRecently = recentEvents.contains { ev in
            let codes: [String] = [
                AppConstants.PacingEventCode.rapidRepeat.rawValue,
                AppConstants.PacingEventCode.fastPace.rawValue,
                AppConstants.PacingEventCode.escalation.rawValue,
                AppConstants.PacingEventCode.shotStacking.rawValue
            ]
            return codes.contains(ev.code) && ev.timestamp >= currentTime.addingTimeInterval(-TimeInterval(60 * 60)) // any warning in last hour
        }
        let timeSinceLast = RollingWindowHelpers.timeSinceLastAlcoholicDrink(from: currentTime, logs: logs)
        let noDrink20Min = (timeSinceLast ?? 0) >= TimeInterval(AppConstants.positiveReinforcementMinutesWithoutDrink * 60)
        if hasWarningRecently, noDrink20Min, !lastFired(code: AppConstants.PacingEventCode.positiveReinforcement.rawValue, withinMinutes: 60) {
            events.append(PacingEventToEmit(
                eventType: AppConstants.PacingEventType.positiveReinforcement.rawValue,
                code: AppConstants.PacingEventCode.positiveReinforcement.rawValue,
                message: "Nice reset. You've slowed the pace.",
                severity: 1
            ))
        }

        let nextInterval: TimeInterval? = (events.isEmpty && paceStatus == AppConstants.PaceStatus.good.rawValue) ? 60 : 60
        return PacingEngineResult(
            eventsToEmit: events,
            paceStatus: paceStatus,
            nextCheckIntervalSeconds: nextInterval
        )
    }
}
