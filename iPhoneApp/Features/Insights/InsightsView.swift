//
//  InsightsView.swift
//  TakeCareApp — Insights tab: Swift Charts and stats.
//

import SwiftUI
import SwiftData
import Charts

struct InsightsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: InsightsViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            overviewCards(vm: vm)
                            drinksPerSessionChart(vm: vm)
                            averageSessionCard(vm: vm)
                            warningsCard(vm: vm)
                            mostCommonDrinkCard(vm: vm)
                            typicalFastPaceCard(vm: vm)
                        }
                        .padding()
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Insights")
            .onAppear {
                if viewModel == nil {
                    viewModel = InsightsViewModel(modelContext: modelContext)
                }
                viewModel?.load()
            }
        }
    }

    private func overviewCards(vm: InsightsViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Overview")
                .font(.headline)
            HStack(spacing: 12) {
                card(value: "\(vm.sessionStats.count)", label: "Sessions")
                card(value: "\(vm.totalWarningsCount)", label: "Warnings")
            }
        }
    }

    private func card(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func drinksPerSessionChart(vm: InsightsViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Drinks per session")
                .font(.headline)
            if vm.sessionStats.isEmpty {
                Text("No session data yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
            } else {
                Chart {
                    ForEach(Array(vm.sessionStats.prefix(14).reversed())) { s in
                        BarMark(
                            x: .value("Session", s.startedAt, unit: .day),
                            y: .value("Drinks", s.drinkCount)
                        )
                        .foregroundStyle(.blue.gradient)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .frame(height: 180)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func averageSessionCard(vm: InsightsViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Average session length")
                .font(.headline)
            if let avg = vm.averageSessionDurationMinutes {
                let h = Int(avg) / 60
                let m = Int(avg) % 60
                Text(h > 0 ? "\(h)h \(m)m" : "\(m) min")
                    .font(.title2)
                    .fontWeight(.medium)
            } else {
                Text("—")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func warningsCard(vm: InsightsViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Warnings across sessions")
                .font(.headline)
            if vm.sessionStats.isEmpty {
                Text("No data yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(vm.sessionStats.prefix(14).reversed()) { s in
                    BarMark(
                        x: .value("Session", s.startedAt, unit: .day),
                        y: .value("Warnings", s.warningCount)
                    )
                    .foregroundStyle(.orange.gradient)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .frame(height: 160)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func mostCommonDrinkCard(vm: InsightsViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Most common drink type")
                .font(.headline)
            if let id = vm.mostCommonDrinkTypeId, let count = vm.drinkTypeCounts[id] {
                Text("\(drinkTypeName(id)) — \(count) times")
                    .font(.subheadline)
            } else {
                Text("—")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func typicalFastPaceCard(vm: InsightsViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Typical fast-pace window")
                .font(.headline)
            if let hour = vm.typicalWarningHour {
                let formatter = DateFormatter()
                formatter.dateFormat = "ha"
                var comps = DateComponents()
                comps.hour = hour
                comps.minute = 0
                let date = Calendar.current.date(from: comps) ?? Date()
                Text("Around \(formatter.string(from: date))")
                    .font(.subheadline)
            } else {
                Text("No warning data yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func drinkTypeName(_ id: String) -> String {
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
    InsightsView()
        .modelContainer(TakeCareSchema.previewContainer)
}
