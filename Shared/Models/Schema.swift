//
//  Schema.swift
//  TakeCareApp — SwiftData schema and container setup.
//

import SwiftData

enum TakeCareSchema {

    static var schema: Schema {
        Schema([
            DrinkLog.self,
            Session.self,
            DrinkTypeConfig.self,
            PacingEvent.self,
            UserSettings.self
        ])
    }

    static var modelContainer: ModelContainer {
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    /// In-memory container for previews and tests.
    static var previewContainer: ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create preview ModelContainer: \(error)")
        }
    }
}
