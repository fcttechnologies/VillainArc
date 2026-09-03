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
                    .transition(.sessionAdvance(reduceMotion: reduceMotion))
            case .active:
                WorkoutView(workout: workout)
                    .transition(.sessionAdvance(reduceMotion: reduceMotion))
            case .summary, .done:
                WorkoutSummaryView(workout: workout)
                    .transition(.sessionAdvance(reduceMotion: reduceMotion))
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
