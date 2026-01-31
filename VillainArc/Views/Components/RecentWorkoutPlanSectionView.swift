import SwiftUI
import SwiftData

struct RecentWorkoutPlanSectionView: View {
    @Query(WorkoutPlan.recent) private var recentWorkoutPlan: [WorkoutPlan]
    private let appRouter = AppRouter.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                appRouter.navigate(to: .workoutPlansList)
                Task { await IntentDonations.donateShowWorkoutPlans() }
            } label: {
                HStack(spacing: 1) {
                    Text("Workout Plans")
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
            .accessibilityIdentifier("allWorkoutPlansLink")
            .accessibilityHint("Shows all your workout plans.")

            if recentWorkoutPlan.isEmpty {
                ContentUnavailableView("No Workout Plans Created", systemImage: "list.clipboard", description: Text("Click the '\(Image(systemName: "plus"))' to create a workout plan."))
                    .frame(maxWidth: .infinity)
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))
                    .accessibilityIdentifier("recentWorkoutPlanEmptyState")
            } else if let plan = recentWorkoutPlan.first {
                WorkoutPlanRowView(workoutPlan: plan)
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
