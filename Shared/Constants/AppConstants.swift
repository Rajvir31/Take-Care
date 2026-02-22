//
//  AppConstants.swift
//  TakeCareApp — Drink Pacing Coach
//

import Foundation

enum AppConstants {

    // MARK: - Drink type IDs (match DrinkTypeConfig.id)

    enum DrinkTypeId {
        static let shot = "shot"
        static let beer = "beer"
        static let cocktail = "cocktail"
        static let wine = "wine"
        static let water = "water"
        static let all: [String] = [shot, beer, cocktail, wine, water]
    }

    // MARK: - Sensitivity modes

    enum SensitivityMode: String, CaseIterable {
        case relaxed
        case balanced
        case strict
        var displayName: String {
            switch self {
            case .relaxed: return "Relaxed"
            case .balanced: return "Balanced"
            case .strict: return "Strict"
            }
        }
    }

    // MARK: - Source device (for DrinkLog.sourceDevice)

    enum SourceDevice: String {
        case watch
        case phone
    }

    // MARK: - Pacing event types and codes

    enum PacingEventType: String {
        case warning
        case reminder
        case positiveReinforcement = "positive_reinforcement"
    }

    enum PacingEventCode: String {
        case rapidRepeat = "rapid_repeat"
        case fastPace = "fast_pace"
        case escalation = "escalation"
        case shotStacking = "shot_stacking"
        case hydrate = "hydrate"
        case positiveReinforcement = "positive_reinforcement"
    }

    // MARK: - Pace status (engine output)

    enum PaceStatus: String {
        case good
        case caution
        case slowDown
    }

    // MARK: - Cooldowns (minutes)

    static let warningCooldownMinutes: Int = 15
    static let hydrationReminderCooldownMinutes: Int = 20
    static let positiveReinforcementMinutesWithoutDrink: Int = 20
}
