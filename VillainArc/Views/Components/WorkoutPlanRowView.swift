import SwiftUI

struct WorkoutPlanRowView: View {
    let workoutPlan: WorkoutPlan
    var showsUseOnly: Bool = false
    private let appRouter = AppRouter.shared
    
    var body: some View {
        Button {
            appRouter.navigate(to: .workoutPlanDetail(workoutPlan, showsUseOnly))
            Task { await IntentDonations.donateOpenWorkoutPlan(workoutPlan: workoutPlan) }
        } label: {
            WorkoutPlanCardView(workoutPlan: workoutPlan)
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanRow(workoutPlan))
    }
}

#Preview {
    NavigationStack {
        WorkoutPlanRowView(workoutPlan: sampleCompletedPlan())
    }
    .sampleDataContainer()
}
