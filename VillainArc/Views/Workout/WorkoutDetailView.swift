import SwiftUI
import SwiftData
import AppIntents

struct WorkoutDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    var router = AppRouter.shared
    let workout: WorkoutSession
    
    @State private var showDeleteWorkoutConfirmation: Bool = false
    @State private var newWorkoutPlan: WorkoutPlan?
    
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
                                Text(set.type == .working ? String(set.index + 1) : set.type.shortLabel)
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
                            .accessibilityIdentifier("workoutDetailExerciseNotes-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)")
                    }
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutDetailExercise(exercise))
            }
        }
        .accessibilityIdentifier("workoutDetailList")
        .navigationTitle(workout.title)
        .navigationSubtitle(Text(formattedDateRange(start: workout.startedAt, end: workout.endedAt, includeTime: true)))
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu("Options", systemImage: "ellipsis") {
                    if let linkedPlan = workout.workoutPlan {
                        Button("Open Workout Plan", systemImage: "arrowshape.turn.up.right") {
                            openWorkoutPlan(linkedPlan)
                        }
                        .accessibilityIdentifier("workoutDetailOpenWorkoutPlanButton")
                        .accessibilityHint("Opens the linked workout plan.")
                    } else {
                        Button("Save as Workout Plan", systemImage: "list.clipboard") {
                            saveWorkoutAsPlan()
                        }
                        .accessibilityIdentifier("workoutDetailSaveWorkoutPlanButton")
                        .accessibilityHint("Saves this workout as a workout plan.")
                    }
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
        .fullScreenCover(item: $newWorkoutPlan) {
            WorkoutPlanView(plan: $0)
        }
        .userActivity("com.villainarc.workoutSession.view", element: workout) { session, activity in
            activity.title = session.title
            activity.isEligibleForSearch = true
            activity.isEligibleForPrediction = true
            let entity = WorkoutSessionEntity(workoutSession: session)
            activity.appEntityIdentifier = .init(for: entity)
        }
    }

    private func deleteWorkout() {
        Haptics.selection()
        let deletedWorkout = workout
        SpotlightIndexer.deleteWorkoutSession(id: workout.id)
        // Collect all affected catalogIDs before deleting
        var affectedCatalogIDs = Set<String>()
        affectedCatalogIDs.formUnion((workout.exercises ?? []).map { $0.catalogID })
        context.delete(workout)
        
        // Update exercise histories for affected exercises
        // This will delete histories where no performances remain
        for catalogID in affectedCatalogIDs {
            ExerciseHistoryUpdater.updateHistory(for: catalogID, context: context)
        }

        Task { await IntentDonations.donateDeleteWorkout(workout: deletedWorkout) }
        
        dismiss()
    }

    private func saveWorkoutAsPlan() {
        guard workout.workoutPlan == nil else { return }
        Haptics.selection()
        let plan = WorkoutPlan(from: workout)
        context.insert(plan)
        workout.workoutPlan = plan
        saveContext(context: context)
        newWorkoutPlan = plan
    }

    private func openWorkoutPlan(_ plan: WorkoutPlan) {
        Haptics.selection()
        router.popToRoot()
        router.navigate(to: .workoutPlanDetail(plan, false))
        Task { await IntentDonations.donateOpenWorkoutPlan(workoutPlan: plan) }
    }
}

#Preview {
    NavigationStack {
        WorkoutDetailView(workout: sampleCompletedSession())
    }
    .sampleDataContainer()
}
