import SwiftUI
import SwiftData
import AppIntents

struct WorkoutPlanDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var plan: WorkoutPlan
    private let router = AppRouter.shared
    private let onSelect: (() -> Void)?

    @State private var showDeleteWorkoutPlanConfirmation = false
    @State private var editWorkoutPlan = false

    init(plan: WorkoutPlan, onSelect: (() -> Void)? = nil) {
        self.plan = plan
        self.onSelect = onSelect
    }

    var body: some View {
        List {
            if !plan.notes.isEmpty {
                Section("Plan Notes") {
                    Text(plan.notes)
                        .accessibilityIdentifier("workoutPlanDetailNotesText")
                }
            }

            ForEach(plan.sortedExercises) { exercise in
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
                                Text(set.targetReps > 0 ? "\(set.targetReps)" : "-")
                                    .gridColumnAlignment(.leading)
                                Spacer()
                                Text(set.targetWeight > 0 ? "\(set.targetWeight, format: .number) lbs" : "-")
                                    .gridColumnAlignment(.leading)
                            }
                            .font(.title3)
                            .accessibilityElement(children: .ignore)
                            .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanDetailSet(exercise, set: set))
                            .accessibilityLabel(AccessibilityText.exerciseSetLabel(for: set))
                            .accessibilityValue(AccessibilityText.exerciseSetValue(for: set))
                        }
                    }
                } header: {
                    Text(exercise.name)
                        .lineLimit(1)
                        .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanDetailExerciseHeader(exercise))
                } footer: {
                    if !exercise.notes.isEmpty {
                        Text("Notes: \(exercise.notes)")
                            .multilineTextAlignment(.leading)
                            .accessibilityIdentifier("workoutPlanDetailExerciseNotes-\(String(describing: exercise.planSnapshot?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)")
                    }
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanDetailExercise(exercise))
            }
        }
        .accessibilityIdentifier("workoutPlanDetailList")
        .navigationTitle(plan.title)
        .navigationSubtitle(Text(plan.musclesTargeted()))
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let onSelect {
                    Button("Select") {
                        Haptics.selection()
                        onSelect()
                        dismiss()
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanDetailSelectButton)
                    .accessibilityHint("Selects this workout plan.")
                } else {
                    Menu("Options", systemImage: "ellipsis") {
                        Button("Start Workout", systemImage: "figure.strengthtraining.traditional") {
                            router.startWorkoutSession(from: plan)
                            Task { await IntentDonations.donateStartWorkoutWithPlan(workoutPlan: plan) }
                            dismiss()
                        }
                        .accessibilityIdentifier("workoutPlanDetailStartWorkoutButton")
                        .accessibilityHint("Starts a workout from this plan.")

                        Button("Edit Plan", systemImage: "pencil") {
                            Haptics.selection()
                            plan.startEditing()
                            saveContext(context: context)
                            editWorkoutPlan = true
                        }
                        .accessibilityIdentifier("templateDetailEditButton")
                        .accessibilityHint("Edits this template.")

                        Button(plan.favorite ? "Undo" : "Favorite", systemImage: plan.favorite ? "star.slash.fill" : "star.fill") {
                            Haptics.selection()
                            plan.favorite.toggle()
                            saveContext(context: context)
                        }
                        .accessibilityIdentifier("workoutPlanDetailFavoriteButton")
                        .accessibilityHint("Toggles favorite.")

                        Button("Delete Workout Plan", systemImage: "trash", role: .destructive) {
                            showDeleteWorkoutPlanConfirmation = true
                        }
                        .accessibilityIdentifier("workoutPlanDetailDeleteButton")
                        .accessibilityHint("Deletes this workout plan.")
                    }
                    .accessibilityIdentifier("workoutPlanDetailOptionsMenu")
                    .accessibilityHint("Workout Plan actions.")
                    .confirmationDialog("Delete Workout Plan?", isPresented: $showDeleteWorkoutPlanConfirmation) {
                        Button("Delete", role: .destructive) {
                            deleteWorkoutPlan()
                        }
                        .accessibilityIdentifier("workoutPlanDetailConfirmDeleteButton")
                    } message: {
                        Text("Are you sure you want to delete this workout plan?")
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $editWorkoutPlan) {
            WorkoutPlanView(plan: plan)
        }
        .userActivity("com.villainarc.workoutPlan.view", element: plan) { plan, activity in
            activity.title = plan.title
            activity.isEligibleForSearch = true
            activity.isEligibleForPrediction = true
            let entity = WorkoutPlanEntity(workoutPlan: plan)
            activity.appEntityIdentifier = .init(for: entity)
        }
    }

    private func deleteWorkoutPlan() {
        Haptics.selection()
        SpotlightIndexer.deleteWorkoutPlan(id: plan.id)
        context.delete(plan)
        saveContext(context: context)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        WorkoutPlanDetailView(plan: sampleCompletedPlan())
    }
    .sampleDataContainer()
}
