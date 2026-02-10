import SwiftUI
import SwiftData
import AppIntents

struct WorkoutPlanView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var plan: WorkoutPlan
    
    @State private var showAddExerciseSheet = false
    @State private var showCancelWorkoutPlanConfirmation = false
    @State private var showExerciseListView = false
    @State private var showTitleEditorSheet = false
    @State private var showNotesEditorSheet = false
    
    init(plan: WorkoutPlan) {
        self.plan = plan
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if showExerciseListView {
                    exerciseListView
                } else {
                    planDetailView
                }
            }
            .navigationTitle(plan.originalPlan != nil ? "Edit Plan" : plan.title)
            .toolbarTitleMenu {
                Button("Change Title", systemImage: "pencil") {
                    showTitleEditorSheet = true
                }
                Button("Plan Notes", systemImage: "note.text") {
                    showNotesEditorSheet = true
                }
            }
            .toolbarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.immediately)
            .animation(.smooth, value: showExerciseListView)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", systemImage: "xmark", role: .cancel) {
                        Haptics.selection()
                        if plan.isEditing {
                            cancelEditingAndDismiss()
                        } else if plan.sortedExercises.isEmpty {
                            deleteWorkoutPlanAndDismiss()
                        } else {
                            showCancelWorkoutPlanConfirmation = true
                        }
                    }
                    .labelStyle(.iconOnly)
                    .accessibilityIdentifier("workoutPlanCancelButton")
                    .confirmationDialog("Cancel Workout Plan?", isPresented: $showCancelWorkoutPlanConfirmation) {
                        Button("Cancel Plan", role: .destructive) {
                            deleteWorkoutPlanAndDismiss()
                        }
                        .accessibilityIdentifier("workoutPlanConfirmCancelButton")
                    } message: {
                        Text("Are you sure you want to cancel this workout plan?")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(plan.originalPlan != nil ? "Done" : "Save") {
                        Haptics.selection()
                        if plan.originalPlan != nil {
                            // Editing existing plan - detect changes and apply
                            plan.finishEditing(context: context)
                            saveContext(context: context)
                            SpotlightIndexer.index(workoutPlan: plan.originalPlan!)
                        } else {
                            // Creating new plan
                            plan.completed = true
                            saveContext(context: context)
                            SpotlightIndexer.index(workoutPlan: plan)
                        }
                        dismiss()
                    }
                    .disabled(plan.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || plan.sortedExercises.isEmpty)
                    .accessibilityIdentifier("workoutPlanSaveButton")
                }
                ToolbarItem(placement: .bottomBar) {
                    if !plan.sortedExercises.isEmpty {
                        Button(showExerciseListView ? "Done Editing" : "Edit Exercises", systemImage: showExerciseListView ? "checkmark" : "pencil") {
                            Haptics.selection()
                            showExerciseListView.toggle()
                        }
                        .tint(showExerciseListView ? .blue : .primary)
                        .accessibilityIdentifier("workoutPlanEditExercisesButton")
                        .accessibilityHint(showExerciseListView ? "Finishes editing the list of exercises." : "Shows the list of exercises.")
                    }
                }
                ToolbarSpacer(.flexible, placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    Button("Add Exercise", systemImage: "plus") {
                        Haptics.selection()
                        showAddExerciseSheet = true
                    }
                    .accessibilityIdentifier("workoutPlanAddExerciseButton")
                    .accessibilityHint("Adds an exercise.")
                }
            }
            .sheet(isPresented: $showAddExerciseSheet) {
                AddExerciseView(plan: plan)
                    .interactiveDismissDisabled()
            }
            .sheet(isPresented: $showNotesEditorSheet) {
                TextEntryEditorView(title: "Notes", placeholder: "Plan Notes", text: $plan.notes, accessibilityIdentifier: AccessibilityIdentifiers.workoutPlanNotesEditorField)
                    .presentationDetents([.fraction(0.4)])
                    .onChange(of: plan.notes) {
                        scheduleSave(context: context)
                    }
                    .onDisappear {
                        saveContext(context: context)
                    }
            }
            .userActivity("com.villainarc.workoutPlan.edit", element: plan) { plan, activity in
                activity.title = plan.title
                activity.isEligibleForSearch = false
                activity.isEligibleForPrediction = true
                let entity = WorkoutPlanEntity(workoutPlan: plan)
                activity.appEntityIdentifier = .init(for: entity)
            }
            .sheet(isPresented: $showTitleEditorSheet) {
                TextEntryEditorView(title: "Title", placeholder: "Workout Plan Title", text: $plan.title, accessibilityIdentifier: AccessibilityIdentifiers.workoutPlanTitleEditorField)
                    .presentationDetents([.fraction(0.2)])
                    .onChange(of: plan.title) {
                        scheduleSave(context: context)
                    }
                    .onDisappear {
                        if plan.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            plan.title = "New Workout Plan"
                        }
                        saveContext(context: context)
                    }
            }
        }
    }
    
    private var planDetailView: some View {
        ScrollView {
            if plan.sortedExercises.isEmpty {
                ContentUnavailableView("No Exercises Added", systemImage: "dumbbell.fill", description: Text("Click the '\(Image(systemName: "plus"))' icon to add some exercises."))
                    .padding(.horizontal)
                    .containerRelativeFrame([.horizontal, .vertical])
                    .accessibilityIdentifier("workoutPlanExercisesEmptyState")
            } else {
                LazyVStack(spacing: 60) {
                    ForEach(plan.sortedExercises) { exercise in
                        WorkoutPlanExerciseView(exercise: exercise)
                            .accessibilityIdentifier("workoutPlanExerciseView-\(exercise.catalogID)-\(exercise.index)")
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .simultaneousGesture(
            TapGesture().onEnded {
                dismissKeyboard()
            }
        )
        .accessibilityIdentifier("workoutPlanEditingForm")
    }
    
    private var exerciseListView: some View {
        List {
            ForEach(plan.sortedExercises) { exercise in
                VStack(alignment: .leading) {
                    Text(exercise.name)
                        .font(.title3)
                        .bold()
                        .lineLimit(1)
                    HStack(alignment: .bottom) {
                        Text(exercise.displayMuscle)
                            .foregroundStyle(.secondary)
                            .fontWeight(.semibold)
                            .font(.headline)
                        Spacer()
                        Text("^[\(exercise.sortedSets.count) set](inflect: true)")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                }
                .listRowSeparator(.hidden)
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanExerciseListRow(exercise))
                .accessibilityLabel(exercise.name)
                .accessibilityValue(AccessibilityText.workoutPlanExerciseListValue(for: exercise))
            }
            .onDelete(perform: deleteExercise)
            .onMove(perform: moveExercise)
        }
        .scrollIndicators(.hidden)
        .listStyle(.plain)
        .environment(\.editMode, .constant(.active))
        .accessibilityIdentifier("workoutPlanExerciseList")
    }
    
    private func deleteExercise(offsets: IndexSet) {
        guard !offsets.isEmpty else { return }
        // Check if deleting these would leave us with no exercises
        if plan.sortedExercises.count - offsets.count == 0 {
            if plan.originalPlan != nil {
                // Editing existing - delete both copy and original
                plan.deletePlanEntirely(context: context)
            } else {
                // Creating new - just delete the plan
                deleteWorkoutPlanAndDismiss()
            }
            dismiss()
            return
        }
        deleteExercises(at: offsets)
    }
    
    private func deleteExercises(at offsets: IndexSet) {
        Haptics.selection()
        let exercisesToDelete = offsets.map { plan.sortedExercises[$0] }
        
        for exercise in exercisesToDelete {
            plan.deleteExercise(exercise)
            context.delete(exercise)
        }
        saveContext(context: context)
        
        if plan.sortedExercises.isEmpty {
            showExerciseListView = false
        }
    }
    
    private func moveExercise(from source: IndexSet, to destination: Int) {
        plan.moveExercise(from: source, to: destination)
        saveContext(context: context)
    }
    
    private func deleteWorkoutPlanAndDismiss() {
        Haptics.selection()
        context.delete(plan)
        saveContext(context: context)
        dismiss()
    }
    
    private func cancelEditingAndDismiss() {
        Haptics.selection()
        if plan.originalPlan != nil {
            // Editing existing - delete the copy, original unchanged
            plan.cancelEditing(context: context)
        } else {
            // Creating new - delete incomplete plan
            context.delete(plan)
            saveContext(context: context)
        }
        dismiss()
    }
}

private struct WorkoutPlanExerciseView: View {
    @Environment(\.modelContext) private var context
    @Bindable var exercise: ExercisePrescription
    
    @State private var showRepRangeEditor = false
    @State private var showRestTimeEditor = false
    
    var body: some View {
        VStack(spacing: 12) {
            headerView
                .padding(.horizontal)
            
            Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    Text("Set")
                    Text("Reps")
                        .gridColumnAlignment(.leading)
                    Text("Weight")
                        .gridColumnAlignment(.leading)
                }
                .font(.title3)
                .bold()
                .accessibilityHidden(true)
                
                ForEach(exercise.sortedSets) { set in
                    GridRow {
                        WorkoutPlanSetRowView(set: set, exercise: exercise)
                    }
                    .font(.title3)
                    .fontWeight(.semibold)
                }
            }
            .padding(.horizontal)
            
            Button {
                addSet()
            } label: {
                Label("Add Set", systemImage: "plus")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .padding(.vertical, 5)
            }
            .tint(.blue)
            .buttonStyle(.glass)
            .buttonSizing(.flexible)
            .padding(.horizontal)
            .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanExerciseAddSetButton(exercise))
            .accessibilityHint("Adds a new set.")
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(exercise.name)
                .font(.title3)
                .bold()
                .lineLimit(1)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.displayMuscle)
                        .foregroundStyle(.secondary)
                        .fontWeight(.semibold)
                    Button {
                        Haptics.selection()
                        showRepRangeEditor = true
                    } label: {
                        Text(exercise.repRange.displayText)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Rep range")
                    .accessibilityValue(exercise.repRange.displayText)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanExerciseRepRangeButton(exercise))
                    .accessibilityHint("Edits the rep range.")
                }
                Spacer()
                Button("Rest Times", systemImage: "timer") {
                    Haptics.selection()
                    showRestTimeEditor = true
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanExerciseRestTimesButton(exercise))
                .accessibilityHint("Edits rest times.")
                .labelStyle(.iconOnly)
                .font(.title)
                .tint(.primary)
            }
            
            TextField("Notes", text: $exercise.notes)
                .padding(.top, 8)
                .onChange(of: exercise.notes) {
                    scheduleSave(context: context)
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanExerciseNotesField(exercise))
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .sheet(isPresented: $showRepRangeEditor) {
            RepRangeEditorView(repRange: exercise.repRange, catalogID: exercise.catalogID)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showRestTimeEditor) {
            RestTimeEditorView(exercise: exercise)
        }
    }
    
    private func addSet() {
        Haptics.selection()
        exercise.addSet()
        saveContext(context: context)
    }
}

private struct WorkoutPlanSetRowView: View {
    @Environment(\.modelContext) private var context
    @Bindable var set: SetPrescription
    @Bindable var exercise: ExercisePrescription
    
    var body: some View {
        Group {
            Menu {
                Picker("", selection: Binding(get: { set.type }, set: { newValue in
                    let oldValue = set.type
                    set.type = newValue
                    if newValue != oldValue {
                        Haptics.selection()
                        saveContext(context: context)
                    }
                })) {
                    ForEach(ExerciseSetType.allCases, id: \.self) { type in
                        Text(type.displayName)
                            .tag(type)
                    }
                }
                Divider()
                if exercise.sets.count > 1 {
                    Button("Delete Set", systemImage: "trash", role: .destructive) {
                        deleteSet()
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanSetDeleteButton(exercise, set: set))
                }
            } label: {
                Text(set.type == .working ? String(set.index + 1) : set.type.shortLabel)
                    .foregroundStyle(set.type.tintColor)
                    .frame(width: 40, height: 40)
                    .glassEffect(.regular, in: .circle)
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanSetMenu(exercise, set: set))
            .accessibilityLabel(AccessibilityText.exerciseSetMenuLabel(for: set))
            .accessibilityValue(AccessibilityText.exerciseSetMenuValue(for: set))
            .accessibilityHint("Opens set options.")
            
            TextField("Reps", value: $set.targetReps, format: .number)
                .keyboardType(.numberPad)
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanSetRepsField(exercise, set: set))
                .accessibilityLabel("Reps")
            
            TextField("Weight", value: $set.targetWeight, format: .number)
                .keyboardType(.decimalPad)
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanSetWeightField(exercise, set: set))
                .accessibilityLabel("Weight")
        }
        .onChange(of: set.targetReps) {
            scheduleSave(context: context)
        }
        .onChange(of: set.targetWeight) {
            scheduleSave(context: context)
        }
    }
    
    private func deleteSet() {
        Haptics.selection()
        exercise.deleteSet(set)
        context.delete(set)
        saveContext(context: context)
    }
}

#Preview("Creating") {
    WorkoutPlanView(plan: sampleIncompletePlan())
        .sampleDataContainerIncomplete()
}

#Preview("Editing") {
    WorkoutPlanView(plan: sampleEditingPlan())
        .sampleDataContainer()
}
