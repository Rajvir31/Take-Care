//
//  SettingsView.swift
//  TakeCareApp — Settings tab: drink defaults, sensitivity, about (placeholder).
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            List {
                Section("Pacing") {
                    NavigationLink("Sensitivity") {
                        Text("Relaxed / Balanced / Strict — coming soon")
                            .foregroundStyle(.secondary)
                    }
                    NavigationLink("Hydration reminders") {
                        Text("Cadence and on/off — coming soon")
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Session") {
                    NavigationLink("Auto-end timeout") {
                        Text("Minutes of inactivity — coming soon")
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Data") {
                    NavigationLink("Export data") {
                        Text("JSON or CSV export — coming soon")
                            .foregroundStyle(.secondary)
                    }
                    NavigationLink("Delete all data", destination: Text("Confirmation — coming soon"))
                }
                Section("About") {
                    Text("If you've been drinking, do not drive.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("This app does not estimate BAC and is not medical or legal advice.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(TakeCareSchema.previewContainer)
}
