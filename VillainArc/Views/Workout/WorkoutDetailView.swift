import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    var router = AppRouter.shared
    @Bindable var workout: Workout
    
    @State private var showDeleteWorkoutConfirmation: Bool = false
    @State private var editWorkout: Bool = false
    @State private var newTemplate: WorkoutTemplate?
    
    var body: some View {
        List {
            if !workout.notes.isEmpty {
                Section("Workout Notes") {
                    Text(workout.notes)
                        .accessibilityIdentifier("workoutDetailNotesText")
                }
            }
            ForEach(workout.sortedExercises) { exercise in
                Section {
                    Grid(verticalSpacing: 6) {
                        GridRow {
                            Text("Set")
                            Spacer()
                            Text("Reps")
                            Spacer()
                            Text("Weight")
                        }
                        .font(.title3)
                        .bold()
                        .accessibilityHidden(true)
                        
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
                            .accessibilityElement(children: .ignore)
                            .accessibilityIdentifier(AccessibilityIdentifiers.workoutDetailSet(exercise, set: set))
                            .accessibilityLabel(AccessibilityText.exerciseSetLabel(for: set))
                            .accessibilityValue(AccessibilityText.exerciseSetValue(for: set))
                        }
                    }
                } header: {
                    Text(exercise.name)
                        .lineLimit(1)
                        .accessibilityIdentifier(AccessibilityIdentifiers.workoutDetailExerciseHeader(exercise))
                } footer: {
                    if !exercise.notes.isEmpty {
                        Text("Notes: \(exercise.notes)")
                            .multilineTextAlignment(.leading)
                            .accessibilityIdentifier("workoutDetailExerciseNotes-\(exercise.workout.id.uuidString)-\(exercise.catalogID)-\(exercise.index)")
                    }
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutDetailExercise(exercise))
            }
        }
        .accessibilityIdentifier("workoutDetailList")
        .navigationTitle(workout.title)
        .navigationSubtitle(Text(formattedDateRange(start: workout.startTime, end: workout.endTime, includeTime: true)))
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu("Options", systemImage: "ellipsis") {
                    Button("Edit Workout", systemImage: "pencil") {
                        Haptics.selection()
                        editWorkout = true
                    }
                    .accessibilityIdentifier("workoutDetailEditButton")
                    .accessibilityHint("Edits this workout.")
                    Button("Start Workout", systemImage: "arrow.triangle.2.circlepath") {
                        router.startWorkout(from: workout)
                        donateStartLastWorkoutAgainIfNeeded()
                        dismiss()
                    }
                    .accessibilityIdentifier("workoutDetailStartButton")
                    .accessibilityHint("Starts a workout based on this one.")
                    Button("Save as Template", systemImage: "list.clipboard") {
                        saveWorkoutAsTemplate()
                    }
                    .accessibilityIdentifier("workoutDetailSaveTemplateButton")
                    .accessibilityHint("Saves this workout as a template.")
                    Button("Delete Workout", systemImage: "trash", role: .destructive) {
                        showDeleteWorkoutConfirmation = true
                    }
                    .accessibilityIdentifier("workoutDetailDeleteButton")
                    .accessibilityHint("Deletes this workout.")
                }
                .accessibilityIdentifier("workoutDetailOptionsMenu")
                .accessibilityHint("Workout actions.")
                .confirmationDialog("Delete Workout", isPresented: $showDeleteWorkoutConfirmation) {
                    Button("Delete", role: .destructive) {
                        deleteWorkout()
                    }
                    .accessibilityIdentifier("workoutDetailConfirmDeleteButton")
                } message: {
                    Text("Are you sure you want to delete this workout?")
                }
            }
        }
        .fullScreenCover(isPresented: $editWorkout) {
            WorkoutView(workout: workout, isEditing: true, onDeleteFromEdit: {
                editWorkout = false
                deleteWorkout()
            })
        }
        .fullScreenCover(item: $newTemplate) {
            TemplateView(template: $0)
        }
    }

    private func deleteWorkout() {
        Haptics.selection()
        SpotlightIndexer.deleteWorkout(id: workout.id)
        context.delete(workout)
        saveContext(context: context)
        dismiss()
    }

    private func saveWorkoutAsTemplate() {
        Haptics.selection()
        let template = WorkoutTemplate(from: workout)
        context.insert(template)
        saveContext(context: context)
        newTemplate = template
    }

    private func donateStartLastWorkoutAgainIfNeeded() {
        let latestWorkout = (try? context.fetch(Workout.recentWorkout).first)
        guard latestWorkout?.id == workout.id else { return }
        Task { await IntentDonations.donateStartLastWorkoutAgain() }
    }
}

#Preview {
    NavigationStack {
        WorkoutDetailView(workout: sampleCompletedWorkout())
    }
    .sampleDataConainer()
}
