import SwiftUI
import SwiftData

struct WorkoutSessionContainer: View {
    @Bindable var workout: WorkoutSession

    var body: some View {
        Group {
            switch workout.statusValue {
            case .pending, .active:
                WorkoutView(workout: workout)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            case .summary, .done:
                WorkoutSummaryView(workout: workout)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.5), value: workout.statusValue)
    }
}

#Preview {
    WorkoutSessionContainer(workout: sampleIncompleteSession())
        .sampleDataContainerIncomplete()
}
