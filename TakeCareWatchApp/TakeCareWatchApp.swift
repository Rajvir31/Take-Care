//
//  TakeCareWatchApp.swift
//  TakeCareWatchApp — watchOS app entry; provides ModelContainer to environment.
//

import SwiftUI
import SwiftData

@main
struct TakeCareWatchApp: App {
    var sharedModelContainer: ModelContainer = {
        TakeCareSchema.modelContainer
    }()

    var body: some Scene {
        WindowGroup {
            WatchMainView()
                .modelContainer(sharedModelContainer)
        }
    }
}
