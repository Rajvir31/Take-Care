//
//  HistoryView.swift
//  TakeCareApp — History tab: list of past sessions.
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: HistoryViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    if vm.endedSessions.isEmpty {
                        ContentUnavailableView(
                            "No sessions yet",
                            systemImage: "clock.arrow.circlepath",
                            description: Text("End a session on the Tonight tab to see it here.")
                        )
                    } else {
                        List {
                            ForEach(vm.endedSessions, id: \.idString) { session in
                                NavigationLink(value: session.id) {
                                    SessionRowView(session: session, modelContext: modelContext)
                                }
                            }
                        }
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("History")
            .navigationDestination(for: UUID.self) { sessionId in
                SessionDetailView(sessionId: sessionId)
            }
            .onAppear {
                if viewModel == nil {
                    viewModel = HistoryViewModel(modelContext: modelContext)
                }
                viewModel?.load()
            }
        }
    }
}

struct SessionRowView: View {
    let session: Session
    let modelContext: ModelContext

    private var drinkCount: Int {
        let repo = DrinkLogRepository(modelContext: modelContext)
        let logs = repo.logs(for: session.id)
        return logs.filter { $0.isAlcoholic }.count
    }

    private var totalUnits: Double {
        let repo = DrinkLogRepository(modelContext: modelContext)
        return repo.logs(for: session.id).reduce(0) { $0 + $1.standardDrinkUnits }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.startedAt, style: .date)
                .font(.headline)
            if let end = session.endedAt {
                Text("\(session.startedAt, style: .time) – \(end, style: .time)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("\(drinkCount) drinks")
                    .font(.subheadline)
                Text("·")
                Text(String(format: "%.1f units", totalUnits))
                    .font(.subheadline)
            }
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    HistoryView()
        .modelContainer(TakeCareSchema.previewContainer)
}
