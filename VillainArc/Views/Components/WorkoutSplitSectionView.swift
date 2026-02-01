import SwiftUI
import SwiftData

struct WorkoutSplitSectionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query private var splits: [WorkoutSplit]
    private let appRouter = AppRouter.shared

    private var activeSplit: WorkoutSplit? {
        splits.first { $0.isActive }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                appRouter.navigate(to: .splitList)
            } label: {
                HStack(spacing: 1) {
                    Text("Workout Split")
                        .font(.title2)
                        .fontDesign(.rounded)
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
                .fontWeight(.semibold)
                .accessibilityElement(children: .combine)
            }
            .buttonStyle(.plain)
            .padding(.leading, 10)
            .accessibilityIdentifier("workoutSplitLink")
            .accessibilityHint("Shows your workout split settings.")

            content
        }
        .onAppear {
            refreshRotationIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            refreshRotationIfNeeded()
        }
    }

    @ViewBuilder
    private var content: some View {
        if splits.isEmpty {
            splitUnavailableView(
                title: "No Workout Split Yet",
                description: "Create a split to plan your training days."
            )
            .accessibilityIdentifier("recentWorkoutSplitEmptyState")
        } else if let activeSplit {
            if let day = activeSplit.todaysSplitDay {
                activeSplitCard(split: activeSplit, day: day)
                    .accessibilityIdentifier("recentWorkoutSplitActiveRow")
            } else {
                splitUnavailableView(
                    title: "No Split Day Configured",
                    description: "Add days to your split to get started."
                )
                .accessibilityIdentifier("recentWorkoutSplitNoDayState")
            }
        } else {
            splitUnavailableView(
                title: "No Active Split",
                description: "Set one of your splits as active."
            )
            .accessibilityIdentifier("recentWorkoutSplitNoActiveState")
        }
    }

    private func splitUnavailableView(title: String, description: String) -> some View {
        Button {
            appRouter.navigate(to: .splitList)
        } label: {
            ContentUnavailableView(title, systemImage: "calendar.badge.exclamationmark", description: Text(description))
                .frame(maxWidth: .infinity)
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens workout split settings.")
    }

    private func activeSplitCard(split: WorkoutSplit, day: WorkoutSplitDay) -> some View {
        let isRestDay = day.isRestDay
        let titleText = isRestDay ? "Today is your rest day" : activeSplitTitle(for: day)
        let subtitleText = isRestDay ? "Enjoy the day off." : activeSplitSubtitle(for: split)

        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(titleText)
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(subtitleText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !isRestDay, let plan = day.workoutPlan {
                Button {
                    appRouter.navigate(to: .workoutPlanDetail(plan, true))
                } label: {
                    Image(systemName: "list.clipboard")
                        .font(.title3)
                }
                .buttonStyle(.glass)
                .accessibilityIdentifier("recentWorkoutSplitPlanButton-\(plan.id)")
                .accessibilityLabel("Open workout plan")
                .accessibilityHint("Opens the workout plan for today.")
            }
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
        .contentShape(.rect)
        .onTapGesture {
            appRouter.navigate(to: .splitList)
        }
        .accessibilityHint("Shows workout split details.")
    }

    private func activeSplitTitle(for day: WorkoutSplitDay) -> String {
        let name = day.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Unnamed split day" : name
    }

    private func activeSplitSubtitle(for split: WorkoutSplit) -> String {
        switch split.mode {
        case .weekly:
            return "Weekly · \(weeklyScheduleStatus(for: split))"
        case .rotation:
            let count = max(1, split.sortedDays.count)
            let dayNumber = (split.todaysDayIndex ?? 0) + 1
            return "Rotation · Cycle Day \(dayNumber) of \(count)"
        }
    }

    private func weeklyScheduleStatus(for split: WorkoutSplit) -> String {
        let offset = split.normalizedWeeklyOffset
        let behindDays = abs(offset)
        return behindDays == 0 ? "On schedule" : "\(behindDays) day\(behindDays == 1 ? "" : "s") behind"
    }

    private func refreshRotationIfNeeded() {
        guard let split = splits.first(where: { $0.isActive }), split.mode == .rotation else { return }
        split.refreshRotationIfNeeded(context: context)
    }
}

#Preview {
    NavigationStack {
        WorkoutSplitSectionView()
            .padding()
    }
    .sampleDataContainer()
}
