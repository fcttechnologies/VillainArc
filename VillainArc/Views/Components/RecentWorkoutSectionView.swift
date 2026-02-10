import SwiftUI
import SwiftData

struct RecentWorkoutSectionView: View {
    @Query(WorkoutSession.recent) private var recentWorkout: [WorkoutSession]
    private let appRouter = AppRouter.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HomeSectionHeaderButton(title: "Workouts", accessibilityIdentifier: "workoutHistoryLink", accessibilityHint: "Shows your workout history.") {
                appRouter.navigate(to: .workoutSessionsList)
                Task { await IntentDonations.donateShowWorkoutHistory() }
            }

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
    .sampleDataContainer()
}
