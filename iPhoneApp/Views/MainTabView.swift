//
//  MainTabView.swift
//  TakeCareApp — iPhone tab bar: Tonight, History, Insights, Settings.
//

import SwiftUI
import SwiftData
import UIKit

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            TonightView()
                .tabItem {
                    Label("Tonight", systemImage: "moon.fill")
                }
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.bar.fill")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .onAppear {
            SyncApplyPhone.configure(modelContext: modelContext)
            SyncApplyPhone.pushSettingsToWatch(context: modelContext)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            SyncApplyPhone.pushSettingsToWatch(context: modelContext)
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(TakeCareSchema.previewContainer)
}
