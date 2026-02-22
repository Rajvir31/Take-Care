//
//  TakeCareApp.swift
//  TakeCareApp — iOS app entry; TabView + SwiftData container.
//

import SwiftUI
import SwiftData

@main
struct TakeCareApp: App {
    var sharedModelContainer: ModelContainer = {
        TakeCareSchema.modelContainer
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .modelContainer(sharedModelContainer)
        }
    }
}
