import SwiftUI
import SwiftData

struct RecentWorkoutSectionView: View {
    @Query(Workout.recentWorkout) private var recentWorkout: [Workout]
    private var appRouter = AppRouter.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                appRouter.navigate(to: .workoutsList)
                Task { await IntentDonations.donateShowWorkoutHistory() }
            } label: {
                HStack(spacing: 1) {
                    Text("Workouts")
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
            .accessibilityIdentifier("recentWorkoutHistoryLink")
            .accessibilityHint("Shows your workout history.")

            if recentWorkout.isEmpty {
                ContentUnavailableView("No Previous Workouts", systemImage: "clock.arrow.circlepath", description: Text("Click the '\(Image(systemName: "plus"))' to start your first workout."))
                    .frame(maxWidth: .infinity)
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))
                    .accessibilityIdentifier("recentWorkoutEmptyState")
            } else if let workout = recentWorkout.first {
                WorkoutRowView(workout: workout)
                    .accessibilityIdentifier("recentWorkoutRow")
                    .accessibilityHint("Shows details for your most recent workout.")
                    .onTapGesture {
                        Task { await IntentDonations.donateViewLastWorkout() }
                    }
            }
        }
    }
}

#Preview {
    NavigationStack {
        RecentWorkoutSectionView()
            .padding()
    }
    .sampleDataConainer()
    .environment(WorkoutRouter())
}
