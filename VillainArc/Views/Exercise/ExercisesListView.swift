import SwiftUI
import SwiftData

struct ExercisesListView: View {
    @Query(Exercise.all) private var exercises: [Exercise]

    var body: some View {
        List {
            ForEach(exercises) { exercise in
                ExerciseSummaryRow(exercise: exercise)
                    .accessibilityIdentifier("exerciseListRow-\(exercise.catalogID)")
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .overlay {
            if exercises.isEmpty {
                ContentUnavailableView("No Exercises", systemImage: "dumbbell", description: Text("Exercises will appear here once the catalog is available."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("exercisesListEmptyState")
                }
        }
        .accessibilityIdentifier("exercisesListScrollView")
        .navigationTitle("Exercises")
        .toolbarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ExercisesListView()
    }
    .sampleDataContainerSuggestionGeneration()
}
