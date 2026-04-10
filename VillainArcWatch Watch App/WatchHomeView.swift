import SwiftData
import SwiftUI

struct WatchHomeView: View {
    @State private var runtimeCoordinator: WatchWorkoutRuntimeCoordinator
    @Query(WorkoutSplit.active) private var activeSplits: [WorkoutSplit]
    @Query(WorkoutPlan.all) private var workoutPlans: [WorkoutPlan]
    @Query(WorkoutSession.completedSession) private var completedWorkouts: [WorkoutSession]

    init(runtimeCoordinator: WatchWorkoutRuntimeCoordinator) {
        _runtimeCoordinator = State(initialValue: runtimeCoordinator)
    }

    private var todaysPlan: WorkoutPlan? { activeSplits.first?.todaysWorkoutPlan }

    var body: some View {
        List {
            todaysPlanSection
            plansSection
            workoutsSection
            statusSection
        }
        .navigationTitle("Villain Arc")
    }

    @ViewBuilder
    private var todaysPlanSection: some View {
        Section("Today’s Plan") {
            if let todaysPlan {
                VStack(alignment: .leading, spacing: 8) {
                    Text(todaysPlan.title)
                        .font(.headline)
                    Text(planSummary(for: todaysPlan))
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button {
                        Task {
                            await runtimeCoordinator.startWorkout(planID: todaysPlan.id)
                        }
                    } label: {
                        Label(runtimeCoordinator.isBusy ? "Starting..." : "Start on Apple Watch", systemImage: "figure.strengthtraining.traditional")
                    }
                    .disabled(runtimeCoordinator.isBusy)
                    .frame(minHeight: 44)
                    .accessibilityHint("Starts today’s workout plan using your iPhone as the source of truth.")
                }
            } else if activeSplits.isEmpty {
                emptyState(title: "No Active Split", message: "Set an active split on iPhone to show today’s workout here.")
            } else {
                emptyState(title: "No Workout Today", message: "There isn’t a workout plan assigned for today.")
            }
        }
    }

    @ViewBuilder
    private var plansSection: some View {
        Section("All Plans") {
            if workoutPlans.isEmpty {
                emptyState(title: "No Plans Yet", message: "Create a plan on iPhone to start workouts from Apple Watch.")
            } else {
                ForEach(workoutPlans.prefix(8)) { plan in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(plan.title)
                            .font(.headline)
                        Text(planSummary(for: plan))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button {
                            Task {
                                await runtimeCoordinator.startWorkout(planID: plan.id)
                            }
                        } label: {
                            Text("Start Plan")
                        }
                        .disabled(runtimeCoordinator.isBusy)
                        .frame(minHeight: 44)
                        .accessibilityLabel("Start \(plan.title)")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
                }
            }
        }
    }

    @ViewBuilder
    private var workoutsSection: some View {
        Section("All Workouts") {
            if completedWorkouts.isEmpty {
                emptyState(title: "No Workouts Yet", message: "Completed workouts from iPhone will show up here after they sync.")
            } else {
                ForEach(completedWorkouts.prefix(8)) { workout in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(workout.title)
                            .font(.headline)
                        Text(workoutSummary(for: workout))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if let statusMessage = runtimeCoordinator.statusMessage {
            Section("Status") {
                VStack(alignment: .leading, spacing: 6) {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button("Dismiss") {
                        runtimeCoordinator.clearStatusMessage()
                    }
                    .frame(minHeight: 44)

                    Button("Continue on iPhone") {
                        WatchPhoneHandoffCoordinator.openAppOnPhone()
                    }
                    .frame(minHeight: 44)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func emptyState(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private func planSummary(for plan: WorkoutPlan) -> String {
        let exerciseCount = plan.totalExercises
        let setCount = plan.totalSets
        return "\(exerciseCount) exercises • \(setCount) sets"
    }

    private func workoutSummary(for workout: WorkoutSession) -> String {
        let dateText = workout.startedAt.formatted(date: .abbreviated, time: .omitted)
        return "\(dateText) • \(workout.totalExercises) exercises"
    }
}

#Preview {
    NavigationStack {
        WatchHomeView(runtimeCoordinator: .shared)
    }
    .modelContainer(WatchSharedModelContainer.container)
}
