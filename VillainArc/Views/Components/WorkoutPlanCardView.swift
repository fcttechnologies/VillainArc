import SwiftUI

struct WorkoutPlanCardView: View {
    let workoutPlan: WorkoutPlan

    var body: some View {
        VStack(alignment: .leading) {
            VStack(alignment: .trailing, spacing: 0) {
                HStack(alignment: .top) {
                    if workoutPlan.favorite {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                    }
                    Spacer()
                    Text(workoutPlan.title)
                        .font(.title3)
                        .lineLimit(1)
                }
                Text(workoutPlan.musclesTargeted())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(workoutPlan.sortedExercises) { exercise in
                    HStack(alignment: .center, spacing: 3) {
                        Text("\(exercise.sets?.count ?? 0)x")
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
        .accessibilityLabel(workoutPlan.title)
        .accessibilityValue("\(workoutPlan.sortedExercises.count) exercises, \(workoutPlan.musclesTargeted())")
        .accessibilityHint(AccessibilityText.workoutPlanRowHint)
    }
}

#Preview {
    NavigationStack {
        WorkoutPlanCardView(workoutPlan: sampleCompletedPlan())
    }
    .sampleDataContainer()
}
