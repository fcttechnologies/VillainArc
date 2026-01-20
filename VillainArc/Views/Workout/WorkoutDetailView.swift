import SwiftUI

struct WorkoutDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let workout: Workout
    let onStartFromWorkout: (Workout) -> Void
    let onDeleteWorkout: (Workout) -> Void
    
    @State private var showDeleteWorkoutConfirmation: Bool = false
    
    var body: some View {
        List {
            if !workout.notes.isEmpty {
                Section("Workout Notes") {
                    Text(workout.notes)
                }
            }
            ForEach(workout.sortedExercises) { exercise in
                Section {
                    Grid {
                        GridRow {
                            Text("Set")
                            Spacer()
                            Text("Reps")
                            Spacer()
                            Text("Weight")
                        }
                        .font(.title3)
                        .bold()
                        
                        ForEach(exercise.sortedSets) { set in
                            GridRow {
                                Text(set.type == .regular ? String(set.index + 1) : set.type.shortLabel)
                                    .foregroundStyle(set.type.tintColor)
                                    .gridColumnAlignment(.leading)
                                Spacer()
                                Text(set.reps, format: .number)
                                    .gridColumnAlignment(.leading)
                                Spacer()
                                Text("\(set.weight, format: .number) lbs")
                                    .gridColumnAlignment(.leading)
                            }
                            .font(.title3)
                        }
                    }
                } header: {
                    Text(exercise.name)
                        .lineLimit(1)
                } footer: {
                    if !exercise.notes.isEmpty {
                        Text("Notes: \(exercise.notes)")
                            .multilineTextAlignment(.leading)
                    }
                }
            }
        }
        .navigationTitle(workout.title)
        .navigationSubtitle(Text(workout.startTime, style: .date))
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu("Options", systemImage: "ellipsis") {
                    Button("Start Workout", systemImage: "arrow.triangle.2.circlepath") {
                        onStartFromWorkout(workout)
                        dismiss()
                    }
                    Button("Delete Workout", systemImage: "trash", role: .destructive) {
                        showDeleteWorkoutConfirmation = true
                    }
                }
                .confirmationDialog("Delete Workout", isPresented: $showDeleteWorkoutConfirmation) {
                    Button("Delete", role: .destructive) {
                        onDeleteWorkout(workout)
                        dismiss()
                    }
                } message: {
                    Text("Are you sure you want to delete this workout? This cannot be undone.")
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        WorkoutDetailView(workout: sampleWorkout(), onStartFromWorkout: { _ in }, onDeleteWorkout: { _ in })
    }
}
