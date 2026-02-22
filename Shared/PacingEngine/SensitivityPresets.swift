//
//  SensitivityPresets.swift
//  TakeCareApp — Configurable thresholds per sensitivity mode (Pacing Engine spec).
//

import Foundation

/// Thresholds for pacing rules; all time windows in minutes.
public struct SensitivityPreset: Sendable {
    /// Fast pace: > this many standard units in 60 min triggers "slow down".
    public let fastPaceUnitsPer60Min: Double
    /// Escalation: >= this many units in 90 min triggers stronger warning + hydrate.
    public let escalationUnitsPer90Min: Double
    /// Rapid repeat: 2+ alcoholic drinks within this many minutes.
    public let rapidRepeatWindowMinutes: Int
    /// Shot stacking: 2+ shots within this many minutes.
    public let shotStackWindowMinutes: Int

    public init(
        fastPaceUnitsPer60Min: Double,
        escalationUnitsPer90Min: Double,
        rapidRepeatWindowMinutes: Int,
        shotStackWindowMinutes: Int
    ) {
        self.fastPaceUnitsPer60Min = fastPaceUnitsPer60Min
        self.escalationUnitsPer90Min = escalationUnitsPer90Min
        self.rapidRepeatWindowMinutes = rapidRepeatWindowMinutes
        self.shotStackWindowMinutes = shotStackWindowMinutes
    }
}

public enum SensitivityPresets {

    public static func preset(for sensitivityMode: String) -> SensitivityPreset {
        switch AppConstants.SensitivityMode(rawValue: sensitivityMode) {
        case .relaxed:
            return .relaxed
        case .strict:
            return .strict
        case .balanced, nil:
            return .balanced
        }
    }

    /// Relaxed: fewer nudges, higher thresholds.
    public static let relaxed = SensitivityPreset(
        fastPaceUnitsPer60Min: 3.0,
        escalationUnitsPer90Min: 5.0,
        rapidRepeatWindowMinutes: 8,
        shotStackWindowMinutes: 12
    )

    /// Balanced: default.
    public static let balanced = SensitivityPreset(
        fastPaceUnitsPer60Min: 2.0,
        escalationUnitsPer90Min: 4.0,
        rapidRepeatWindowMinutes: 10,
        shotStackWindowMinutes: 15
    )

    /// Strict: more sensitive, lower thresholds.
    public static let strict = SensitivityPreset(
        fastPaceUnitsPer60Min: 1.5,
        escalationUnitsPer90Min: 3.0,
        rapidRepeatWindowMinutes: 12,
        shotStackWindowMinutes: 20
    )
}
