import SwiftUI
import SwiftData

struct WorkoutSessionContainer: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var workout: WorkoutSession

    var body: some View {
        Group {
            switch workout.statusValue {
            case .pending:
                DeferredSuggestionsView(workout: workout)
                    .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
            case .active:
                WorkoutView(workout: workout)
                    .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
            case .summary, .done:
                WorkoutSummaryView(workout: workout)
                    .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.5), value: workout.statusValue)
    }
}

#Preview(traits: .sampleDataIncomplete) {
    WorkoutSessionContainer(workout: sampleIncompleteSession())
}

#Preview("Suggestions", traits: .sampleDataSuggestions) {
    WorkoutSessionContainer(workout: sampleSessionWithSuggestions())
}
