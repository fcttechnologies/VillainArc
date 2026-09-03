import SwiftUI
import SwiftData

struct RecentWorkoutSectionView: View {
    @Query(WorkoutSession.recent) private var workouts: [WorkoutSession]
    @Query(HealthWorkout.recentStandalone) private var healthWorkouts: [HealthWorkout]
    @Query(CardioSession.recentCompleted(limit: 1)) private var cardioSessions: [CardioSession]
    @Query(AppSettings.single) private var appSettings: [AppSettings]
    private let appRouter = AppRouter.shared

    private var recentItem: WorkoutHistoryItem? {
        [
            workouts.first.map { WorkoutHistoryItem(source: .session($0)) },
            healthWorkouts.first.map { WorkoutHistoryItem(source: .health($0)) },
            cardioSessions.first.map { WorkoutHistoryItem(source: .cardio($0)) }
        ]
            .compactMap(\.self)
            .max { $0.sortDate < $1.sortDate }
    }

    private var appSettingsSnapshot: AppSettingsSnapshot {
        AppSettingsSnapshot(settings: appSettings.first)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HomeSectionHeaderButton(title: "Workouts", accessibilityIdentifier: AccessibilityIdentifiers.workoutHistoryLink, accessibilityHint: AccessibilityText.workoutHistoryHeaderHint) {
                appRouter.push(to: .workoutSessionsList)
                Task { await IntentDonations.donateShowWorkoutHistory() }
            }

            if recentItem == nil {
                AccountEmptyState {
                    ContentUnavailableView("No Previous Workouts", systemImage: "clock.arrow.circlepath", description: Text("Tap the \(Image(systemName: "plus")) button to start your first workout."))
                        .frame(maxWidth: .infinity)
                        .appCardStyle()
                        .accessibilityIdentifier(AccessibilityIdentifiers.recentWorkoutEmptyState)
                }
            } else if let recentItem {
                switch recentItem.source {
                case .session(let workout):
                    WorkoutRowView(workout: workout, deletionSettings: appSettings.first)
                        .accessibilityIdentifier(AccessibilityIdentifiers.recentWorkoutRow)
                        .accessibilityHint(AccessibilityText.recentWorkoutRowHint)
                        .simultaneousGesture(
                            TapGesture().onEnded {
                                Task { await IntentDonations.donateViewLastWorkout() }
                            }
                        )
                case .health, .cardio:
                    WorkoutHistoryRowView(item: recentItem, appSettingsSnapshot: appSettingsSnapshot, deletionSettings: appSettings.first)
                        .accessibilityIdentifier(AccessibilityIdentifiers.recentWorkoutRow)
                        .accessibilityHint(AccessibilityText.recentWorkoutRowHint)
                }
            }
        }
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        RecentWorkoutSectionView()
            .padding()
    }
}
