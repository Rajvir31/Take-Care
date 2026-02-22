//
//  SessionDetailView.swift
//  TakeCareApp — Session detail: timeline, breakdown, warnings.
//

import SwiftUI
import SwiftData

struct SessionDetailView: View {
    let sessionId: UUID
    @Environment(\.modelContext) private var modelContext

    @State private var session: Session?
    @State private var logs: [DrinkLog] = []
    @State private var events: [PacingEvent] = []

    private var totalUnits: Double { logs.reduce(0) { $0 + $1.standardDrinkUnits } }
    private var alcoholicCount: Int { logs.filter { $0.isAlcoholic }.count }
    private var waterCount: Int { logs.filter { $0.drinkTypeId == AppConstants.DrinkTypeId.water }.count }
    private var drinkTypeBreakdown: [(String, Int)] {
        let counts = Dictionary(grouping: logs.filter { $0.isAlcoholic }, by: { $0.drinkTypeId })
            .mapValues { $0.count }
        return counts.sorted { ($0.value, $1.key) > ($1.value, $0.key) }
    }

    var body: some View {
        Group {
            if let session {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        summaryCard(session: session)
                        breakdownCard
                        if !events.isEmpty {
                            warningsCard
                        }
                        timelineSection
                    }
                    .padding()
                }
            } else {
                ProgressView("Loading…")
            }
        }
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { load() }
    }

    private func load() {
        let sessionRepo = SessionRepository(modelContext: modelContext)
        let drinkLogRepo = DrinkLogRepository(modelContext: modelContext)
        let eventRepo = PacingEventRepository(modelContext: modelContext)
        session = sessionRepo.session(by: sessionId)
        guard let session else { return }
        logs = drinkLogRepo.logs(for: session.id)
        events = eventRepo.events(for: session.id)
    }

    private func summaryCard(session: Session) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Summary")
                .font(.headline)
            HStack {
                Text(session.startedAt, style: .date)
                Text("–")
            }
            .font(.subheadline)
            if let end = session.endedAt {
                Text("\(session.startedAt, style: .time) – \(end, style: .time)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(alcoholicCount)")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("drinks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "%.1f", totalUnits))
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("units")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(waterCount)")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("water")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var breakdownCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Drink breakdown")
                .font(.headline)
            if drinkTypeBreakdown.isEmpty {
                Text("No alcoholic drinks")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(drinkTypeBreakdown, id: \.0) { typeId, count in
                    HStack {
                        Text(drinkTypeDisplayName(typeId))
                        Spacer()
                        Text("\(count)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var warningsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Warnings & reminders")
                .font(.headline)
            ForEach(events, id: \.idString) { ev in
                HStack(alignment: .top, spacing: 8) {
                    Text(ev.timestamp, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(ev.message)
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Timeline")
                .font(.headline)
            let merged: [TimelineItem] = logs.map { .log($0) } + events.map { .event($0) }
            let sorted = merged.sorted { itemTime($0) < itemTime($1) }
            ForEach(sorted, id: \.id) { item in
                timelineRow(item: item)
            }
        }
    }

    private enum TimelineItem: Identifiable {
        case log(DrinkLog)
        case event(PacingEvent)
        var id: String {
            switch self {
            case .log(let l): return "log-\(l.idString)"
            case .event(let e): return "ev-\(e.idString)"
            }
        }
    }

    private func itemTime(_ item: TimelineItem) -> Date {
        switch item {
        case .log(let l): return l.timestamp
        case .event(let e): return e.timestamp
        }
    }

    private func timelineRow(item: TimelineItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            switch item {
            case .log(let log):
                Text(log.timestamp, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .leading)
                Image(systemName: "wineglass")
                    .font(.caption)
                Text(drinkTypeDisplayName(log.drinkTypeId))
                    .font(.subheadline)
            case .event(let ev):
                Text(ev.timestamp, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .leading)
                Image(systemName: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text(ev.message)
                    .font(.subheadline)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func drinkTypeDisplayName(_ id: String) -> String {
        switch id {
        case AppConstants.DrinkTypeId.shot: return "Shot"
        case AppConstants.DrinkTypeId.beer: return "Beer"
        case AppConstants.DrinkTypeId.cocktail: return "Cocktail"
        case AppConstants.DrinkTypeId.wine: return "Wine"
        case AppConstants.DrinkTypeId.water: return "Water"
        default: return id
        }
    }
}

#Preview {
    NavigationStack {
        SessionDetailView(sessionId: UUID())
            .modelContainer(TakeCareSchema.previewContainer)
    }
}
