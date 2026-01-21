import SwiftUI
import SwiftData

struct PreviousWorkoutSectionView: View {
    @Query(Workout.recentWorkout) private var previousWorkout: [Workout]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            NavigationLink {
                PreviousWorkoutsListView()
            } label: {
                HStack(spacing: 0) {
                    Text("Workouts")
                        .font(.title2)
                        .fontDesign(.rounded)
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
                .fontWeight(.semibold)
            }
            .buttonStyle(.plain)
            .padding(.leading, 10)

            if previousWorkout.isEmpty {
                ContentUnavailableView("No Previous Workouts", systemImage: "clock.arrow.circlepath", description: Text("Click the '\(Image(systemName: "plus"))' to start your first workout."))
                    .frame(maxWidth: .infinity)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
            } else if let workout = previousWorkout.first {
                WorkoutRowView(workout: workout)
            }
        }
    }
}

#Preview {
    NavigationStack {
        PreviousWorkoutSectionView()
            .sampleDataConainer()
            .padding()
    }
}
