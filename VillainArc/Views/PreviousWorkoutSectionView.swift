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
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                    Image(systemName: "chevron.right")
                        .bold()
                        .foregroundStyle(.secondary)
                }
                .font(.title2)
            }
            .buttonStyle(.plain)
            .padding(.leading)

            if previousWorkout.isEmpty {
                ContentUnavailableView("No Previous Workouts", systemImage: "clock.arrow.circlepath", description: Text("Click the '\(Image(systemName: "plus"))' to start your first workout."))
                    .frame(maxWidth: .infinity)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(previousWorkout) {
                    WorkoutRowView(workout: $0)
                }
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
