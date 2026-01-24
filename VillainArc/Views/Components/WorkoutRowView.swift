import SwiftUI

struct WorkoutRowView: View {
    let workout: Workout
    
    var body: some View {
        NavigationLink {
            WorkoutDetailView(workout: workout)
        } label: {
            VStack(alignment: .leading) {
                HStack {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(workout.title)
                            .font(.title3)
                            .lineLimit(1)
                        Text(workout.startTime, format: .dateTime.day().month(.abbreviated).year())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(workout.sortedExercises) { exercise in
                        HStack(alignment: .center, spacing: 3) {
                            Text("\(exercise.sets.count)x")
                            Text(exercise.name)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .padding()
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
            .tint(.primary)
            .fontDesign(.rounded)
        }
        .navigationLinkIndicatorVisibility(.hidden)
    }
}

#Preview {
    NavigationStack {
        WorkoutRowView(workout: sampleCompletedWorkout())
    }
    .sampleDataConainer()
    .environment(WorkoutRouter())
}
