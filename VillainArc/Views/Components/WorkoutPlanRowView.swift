import SwiftUI

struct WorkoutPlanRowView: View {
    let workoutPlan: WorkoutPlan
    var showsUseOnly: Bool = false
    private let appRouter = AppRouter.shared
    
    var body: some View {
        Button {
            appRouter.navigate(to: .workoutPlanDetail(workoutPlan, showsUseOnly))
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
