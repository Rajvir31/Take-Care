//
//  TonightView.swift
//  TakeCareApp — Tonight tab: active session summary, recent logs, add/undo.
//

import SwiftUI
import SwiftData

struct TonightView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: TonightViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    tonightContent(vm: vm)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Tonight")
            .onAppear {
                if viewModel == nil {
                    viewModel = TonightViewModel(modelContext: modelContext)
                    viewModel?.load()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                viewModel?.load()
            }
        }
    }

    private func tonightContent(vm: TonightViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if vm.currentSession != nil {
                    sessionSummaryCard(vm: vm)
                    paceCard(vm: vm)
                    Button(role: .destructive) {
                        vm.endSession()
                    } label: {
                        Text("End session")
                    }
                    .frame(maxWidth: .infinity)
                    if let msg = vm.lastWarningMessage {
                        warningBanner(message: msg)
                    }
                } else {
                    noSessionCard(vm: vm)
                }
                recentLogsSection(vm: vm)
                addDrinkSection(vm: vm)
                if vm.currentSession != nil, !vm.sessionLogs.isEmpty {
                    undoButton(vm: vm)
                }
            }
            .padding()
        }
    }

    private func sessionSummaryCard(vm: TonightViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This session")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                Label("\(vm.totalAlcoholicDrinks) drinks", systemImage: "wineglass")
                if vm.totalWaterLogs > 0 {
                    Text("·")
                    Label("\(vm.totalWaterLogs) water", systemImage: "drop.fill")
                }
                Spacer()
                Text(String(format: "%.1f units", vm.totalStandardUnits))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .font(.body)
            if let interval = vm.timeSinceLastDrink {
                Text(timeAgo(interval))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func paceCard(vm: TonightViewModel) -> some View {
        HStack {
            Text(paceLabel(vm.paceStatus))
                .font(.subheadline)
                .fontWeight(.medium)
            Spacer()
            Circle()
                .fill(paceColor(vm.paceStatus))
                .frame(width: 12, height: 12)
        }
        .padding()
        .background(paceColor(vm.paceStatus).opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
    }

    private func paceLabel(_ status: String) -> String {
        switch status {
        case AppConstants.PaceStatus.slowDown.rawValue: return "Slow down"
        case AppConstants.PaceStatus.caution.rawValue: return "Caution"
        default: return "Good pace"
        }
    }

    private func paceColor(_ status: String) -> Color {
        switch status {
        case AppConstants.PaceStatus.slowDown.rawValue: return .red
        case AppConstants.PaceStatus.caution.rawValue: return .orange
        default: return .green
        }
    }

    private func warningBanner(message: String) -> some View {
        Text(message)
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
    }

    private func noSessionCard(vm: TonightViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No active session")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Start session") {
                vm.startSession()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func recentLogsSection(vm: TonightViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent logs")
                .font(.headline)
            if vm.sessionLogs.isEmpty {
                Text("No drinks logged yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(vm.sessionLogs.suffix(20).reversed(), id: \.idString) { log in
                    HStack {
                        drinkTypeLabel(log.drinkTypeId)
                        Spacer()
                        Text(log.timestamp, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func drinkTypeLabel(_ id: String) -> String {
        switch id {
        case AppConstants.DrinkTypeId.shot: return "Shot"
        case AppConstants.DrinkTypeId.beer: return "Beer"
        case AppConstants.DrinkTypeId.cocktail: return "Cocktail"
        case AppConstants.DrinkTypeId.wine: return "Wine"
        case AppConstants.DrinkTypeId.water: return "Water"
        default: return id
        }
    }

    private func addDrinkSection(vm: TonightViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Log drink")
                .font(.headline)
            FlowLayout(spacing: 8) {
                ForEach(AppConstants.DrinkTypeId.all, id: \.self) { id in
                    Button(drinkTypeLabel(id)) {
                        vm.addDrink(drinkTypeId: id)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func undoButton(vm: TonightViewModel) -> some View {
        Button(role: .destructive) {
            vm.undoLast()
        } label: {
            Label("Undo last drink", systemImage: "arrow.uturn.backward")
        }
    }

    private func timeAgo(_ interval: TimeInterval) -> String {
        let m = Int(interval / 60)
        if m < 1 { return "Just now" }
        if m == 1 { return "Last drink 1 min ago" }
        return "Last drink \(m) min ago"
    }
}

// Simple flow layout for buttons
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (i, pos) in result.positions.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + pos.x, y: bounds.minY + pos.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var positions: [CGPoint] = []
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        let totalHeight = y + rowHeight
        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}

#Preview {
    TonightView()
        .modelContainer(TakeCareSchema.previewContainer)
}
