//
//  WatchMainView.swift
//  TakeCareWatchApp — Main watch UI: session summary + drink logging buttons.
//

import SwiftUI
import SwiftData

struct WatchMainView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: WatchSessionViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                mainContent(vm: vm)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            SyncApplyWatch.configure(modelContext: modelContext)
            if viewModel == nil {
                viewModel = WatchSessionViewModel(modelContext: modelContext)
                viewModel?.load()
            }
        }
    }

    private func mainContent(vm: WatchSessionViewModel) -> some View {
        ScrollView {
            VStack(spacing: 8) {
                sessionSummary(vm: vm)
                drinkButtons(vm: vm)
                undoButton(vm: vm)
                sessionToggleButton(vm: vm)
            }
            .padding(.horizontal, 4)
        }
    }

    @ViewBuilder
    private func sessionSummary(vm: WatchSessionViewModel) -> some View {
        if vm.currentSession != nil {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    paceBadge(vm.paceStatus)
                    Spacer()
                    Text("\(vm.totalAlcoholicDrinks) drinks")
                        .font(.caption2)
                    if vm.totalWaterLogs > 0 {
                        Text("· \(vm.totalWaterLogs) water")
                            .font(.caption2)
                    }
                }
                if let interval = vm.timeSinceLastDrink {
                    Text(timeAgo(interval))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func paceBadge(_ status: String) -> some View {
        let (label, color) = paceLabelAndColor(status)
        return Text(label)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.3))
            .clipShape(Capsule())
    }

    private func paceLabelAndColor(_ status: String) -> (String, Color) {
        switch status {
        case AppConstants.PaceStatus.slowDown.rawValue:
            return ("Slow down", .red)
        case AppConstants.PaceStatus.caution.rawValue:
            return ("Caution", .orange)
        default:
            return ("Good", .green)
        }
    }

    private func timeAgo(_ interval: TimeInterval) -> String {
        let m = Int(interval / 60)
        if m < 1 { return "Just now" }
        if m == 1 { return "Last: 1m ago" }
        return "Last: \(m)m ago"
    }

    private func drinkButtons(vm: WatchSessionViewModel) -> some View {
        let types: [(String, String)] = [
            (AppConstants.DrinkTypeId.shot, "Shot"),
            (AppConstants.DrinkTypeId.beer, "Beer"),
            (AppConstants.DrinkTypeId.cocktail, "Cocktail"),
            (AppConstants.DrinkTypeId.wine, "Wine"),
            (AppConstants.DrinkTypeId.water, "Water")
        ]
        return VStack(spacing: 6) {
            ForEach(types, id: \.0) { id, label in
                Button {
                    vm.addDrink(drinkTypeId: id)
                } label: {
                    Text(label)
                        .font(.body)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func undoButton(vm: WatchSessionViewModel) -> some View {
        Button {
            vm.undoLast()
        } label: {
            Text("Undo Last")
                .font(.caption)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.bordered)
        .disabled(vm.currentSession == nil || vm.sessionLogs.isEmpty)
    }

    private func sessionToggleButton(vm: WatchSessionViewModel) -> some View {
        Group {
            if vm.currentSession != nil {
                Button(role: .destructive) {
                    vm.endSession()
                } label: {
                    Text("End Session")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
            } else {
                Button {
                    vm.startSession()
                } label: {
                    Text("Start Session")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

#Preview {
    WatchMainView()
        .modelContainer(TakeCareSchema.previewContainer)
}
