import SwiftUI
import SwiftData

struct WorkoutSessionContainer: View {
    @Bindable var workout: WorkoutSession

    var body: some View {
        switch workout.statusValue {
        case .pending, .active:
            WorkoutView(workout: workout)
        case .summary, .done:
            WorkoutSummaryView(workout: workout)
        }
    }
}

#Preview {
    WorkoutSessionContainer(workout: sampleIncompleteSession())
        .sampleDataContainerIncomplete()
}
