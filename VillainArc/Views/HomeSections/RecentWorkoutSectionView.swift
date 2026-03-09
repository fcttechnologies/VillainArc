import SwiftUI
import SwiftData

struct RecentWorkoutSectionView: View {
    @Query(WorkoutSession.recent) private var recentWorkout: [WorkoutSession]
    private let appRouter = AppRouter.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HomeSectionHeaderButton(title: "Workouts", accessibilityIdentifier: AccessibilityIdentifiers.workoutHistoryLink, accessibilityHint: AccessibilityText.workoutHistoryHeaderHint) {
                appRouter.navigate(to: .workoutSessionsList)
                Task { await IntentDonations.donateShowWorkoutHistory() }
            }

            if recentWorkout.isEmpty {
                ContentUnavailableView("No Previous Workouts", systemImage: "clock.arrow.circlepath", description: Text("Click the '\(Image(systemName: "plus"))' to start your first workout."))
                    .frame(maxWidth: .infinity)
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))
                    .accessibilityIdentifier(AccessibilityIdentifiers.recentWorkoutEmptyState)
            } else if let workout = recentWorkout.first {
                WorkoutRowView(workout: workout)
                    .accessibilityIdentifier(AccessibilityIdentifiers.recentWorkoutRow)
                    .accessibilityHint(AccessibilityText.recentWorkoutRowHint)
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
