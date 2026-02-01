import SwiftUI

struct WorkoutPlanRowView: View {
    let workoutPlan: WorkoutPlan
    private let appRouter = AppRouter.shared
    
    var body: some View {
        Button {
            appRouter.navigate(to: .workoutPlanDetail(workoutPlan))
        } label: {
            WorkoutPlanCardView(workoutPlan: workoutPlan)
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier("workoutPlanRow-\(workoutPlan.id)")
    }
}

#Preview {
    NavigationStack {
        WorkoutPlanRowView(workoutPlan: sampleCompletedPlan())
    }
    .sampleDataContainer()
}
