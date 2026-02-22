//
//  WatchHaptics.swift
//  TakeCareWatchApp — Haptic feedback for logging and warnings.
//

import WatchKit

enum WatchHaptics {

    /// Play on successful drink log.
    static func playLogSuccess() {
        WKInterfaceDevice.current().play(.success)
    }

    /// Play for pacing warning / reminder (distinct from success).
    static func playWarning() {
        WKInterfaceDevice.current().play(.notification(type: .warning))
    }

    /// Light tap for neutral reminder (e.g. hydration).
    static func playNotification() {
        WKInterfaceDevice.current().play(.notification(type: .directionDown))
    }
}
