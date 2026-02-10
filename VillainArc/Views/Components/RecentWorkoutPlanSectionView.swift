import SwiftUI
import SwiftData

struct RecentWorkoutPlanSectionView: View {
    @Query(WorkoutPlan.recent) private var recentWorkoutPlan: [WorkoutPlan]
    private let appRouter = AppRouter.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HomeSectionHeaderButton(title: "Workout Plans", accessibilityIdentifier: AccessibilityIdentifiers.allWorkoutPlansLink, accessibilityHint: AccessibilityText.workoutPlansHeaderHint) {
                appRouter.navigate(to: .workoutPlansList)
                Task { await IntentDonations.donateShowWorkoutPlans() }
            }

            if recentWorkoutPlan.isEmpty {
                ContentUnavailableView("No Workout Plans Created", systemImage: "list.clipboard", description: Text("Click the '\(Image(systemName: "plus"))' to create a workout plan."))
                    .frame(maxWidth: .infinity)
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))
                    .accessibilityIdentifier(AccessibilityIdentifiers.recentWorkoutPlanEmptyState)
            } else if let plan = recentWorkoutPlan.first {
                WorkoutPlanRowView(workoutPlan: plan)
                    .accessibilityHint(AccessibilityText.recentWorkoutPlanRowHint)
            }
        }
    }
}

#Preview {
    NavigationStack {
        RecentWorkoutPlanSectionView()
            .padding()
    }
    .sampleDataContainer()
}
