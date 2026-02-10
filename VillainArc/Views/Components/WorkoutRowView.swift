import SwiftUI
import SwiftData

struct WorkoutRowView: View {
    let workout: WorkoutSession
    private let appRouter = AppRouter.shared
    
    var body: some View {
        Button {
            appRouter.navigate(to: .workoutSessionDetail(workout))
            Task { await IntentDonations.donateOpenWorkout(workout: workout) }
        } label: {
            VStack(alignment: .leading) {
                HStack {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(workout.title)
                            .font(.title3)
                            .lineLimit(1)
                        Text(workout.startedAt, format: .dateTime.day().month(.abbreviated).year())
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
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(AccessibilityText.workoutRowLabel(for: workout))
            .accessibilityValue(AccessibilityText.workoutRowValue(for: workout))
            .accessibilityHint(AccessibilityText.workoutRowHint)
        }
        .buttonStyle(.borderless)
    }
}

#Preview {
    NavigationStack {
        WorkoutRowView(workout: sampleCompletedSession())
    }
    .sampleDataContainer()
}
