import SwiftUI
import SwiftData
import AppIntents

struct WorkoutPlanView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var plan: WorkoutPlan
    private let originalPlan: WorkoutPlan?

    @State private var showAddExerciseSheet = false
    @State private var showCancelWorkoutPlanConfirmation = false
    @State private var showExerciseEditSheet = false
    @State private var showTitleEditorSheet = false
    @State private var showNotesEditorSheet = false
    @State private var showDeletePlanConfirmation = false

    init(plan: WorkoutPlan, originalPlan: WorkoutPlan? = nil) {
        self.plan = plan
        self.originalPlan = originalPlan
    }

    private var isEditingExistingPlan: Bool {
        originalPlan != nil
    }

    var body: some View {
        NavigationStack {
            planDetailView
            .navigationTitle(plan.title)
            .toolbarTitleMenu {
                Button("Change Title", systemImage: "pencil") {
                    showTitleEditorSheet = true
                }
                Button("Plan Notes", systemImage: "note.text") {
                    showNotesEditorSheet = true
                }
            }
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", systemImage: "xmark", role: .cancel) {
                        Haptics.selection()
                        if isEditingExistingPlan {
                            cancelEditingAndDismiss()
                        } else if plan.completed {
                            dismiss()
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
                    Button(isEditingExistingPlan || plan.completed ? "Done" : "Save") {
                        Haptics.selection()
                        if let originalPlan {
                            originalPlan.applyEditingCopy(plan, context: context)
                            context.delete(plan)
                            saveContext(context: context)
                            SpotlightIndexer.index(workoutPlan: originalPlan)
                            dismiss()
                            return
                        }
                        if !plan.completed {
                            plan.completed = true
                        }
                        try? context.save()
                        SpotlightIndexer.index(workoutPlan: plan)
                        dismiss()
                    }
                    .disabled(plan.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || plan.sortedExercises.isEmpty)
                    .accessibilityIdentifier("workoutPlanSaveButton")
                }
                ToolbarItem(placement: .bottomBar) {
                    if !plan.sortedExercises.isEmpty {
                        Button("Edit Exercises", systemImage: "pencil") {
                            Haptics.selection()
                            showExerciseEditSheet = true
                        }
                        .accessibilityIdentifier("workoutPlanEditExercisesButton")
                        .accessibilityHint("Shows the list of exercises.")
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
            .sheet(isPresented: $showExerciseEditSheet) {
                NavigationStack {
                    exerciseListView
                        .navigationTitle("Edit Exercises")
                        .toolbarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button(role: .confirm) {
                                    showExerciseEditSheet = false
                                }
                            }
                        }
                }
            }
            .sheet(isPresented: $showAddExerciseSheet) {
                AddExerciseView(plan: plan)
                    .interactiveDismissDisabled()
            }
            .sheet(isPresented: $showNotesEditorSheet) {
                TextEntryEditorView(title: "Notes", promptText: "Plan Notes", text: $plan.notes, accessibilityIdentifier: AccessibilityIdentifiers.workoutPlanNotesEditorField)
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
                TextEntryEditorView(title: "Title", promptText: "Workout Plan Title", text: $plan.title, accessibilityIdentifier: AccessibilityIdentifiers.workoutPlanTitleEditorField)
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
            .alert("Delete Plan?", isPresented: $showDeletePlanConfirmation) {
                Button("Delete Plan", role: .destructive) {
                    deleteWorkoutPlanAndDismiss()
                }
            } message: {
                Text("Removing the last exercise will delete this plan.")
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
                        WorkoutPlanExerciseView(exercise: exercise, onDelete: { deleteExercise(exercise) })
                            .accessibilityIdentifier("workoutPlanExerciseView-\(exercise.catalogID)-\(exercise.index)")
                    }
                }
                Spacer(minLength: 75)
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
                        Text(exercise.equipmentType.rawValue)
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
        .environment(\.editMode, .constant(.active))
        .accessibilityIdentifier("workoutPlanExerciseList")
    }
    
    private func deleteExercise(offsets: IndexSet) {
        guard !offsets.isEmpty else { return }
        // Check if deleting these would leave us with no exercises
        if plan.sortedExercises.count - offsets.count == 0 {
            if isEditingExistingPlan || plan.completed {
                showDeletePlanConfirmation = true
            } else {
                deleteExercises(at: offsets)
            }
            return
        }
        deleteExercises(at: offsets)
    }

    private func deleteExercise(_ exercise: ExercisePrescription) {
        if plan.sortedExercises.count == 1, isEditingExistingPlan || plan.completed {
            showDeletePlanConfirmation = true
            return
        }
        Haptics.selection()
        plan.deleteExercise(exercise)
        context.delete(exercise)
        saveContext(context: context)
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
            showExerciseEditSheet = false
        }
    }

    private func moveExercise(from source: IndexSet, to destination: Int) {
        plan.moveExercise(from: source, to: destination)
        saveContext(context: context)
    }

    private func deleteWorkoutPlanAndDismiss() {
        Haptics.selection()
        if let originalPlan {
            SpotlightIndexer.deleteWorkoutPlan(id: originalPlan.id)
            originalPlan.deleteWithSuggestionCleanup(context: context)
            context.delete(plan)
            try? context.save()
            dismiss()
            return
        }
        if plan.completed {
            SpotlightIndexer.deleteWorkoutPlan(id: plan.id)
        }
        plan.deleteWithSuggestionCleanup(context: context)
        try? context.save()
        dismiss()
    }

    private func cancelEditingAndDismiss() {
        context.delete(plan)
        try? context.save()
        dismiss()
    }
}

private struct WorkoutPlanExerciseView: View {
    @Environment(\.modelContext) private var context
    @Bindable var exercise: ExercisePrescription
    let onDelete: (() -> Void)?

    @State private var showRepRangeEditor = false
    @State private var showRestTimeEditor = false
    @State private var showReplaceExerciseSheet = false
    @State private var showExerciseHistorySheet = false

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
                    Text(exercise.equipmentType.rawValue)
                        .foregroundStyle(.secondary)
                        .fontWeight(.semibold)
                    Button {
                        Haptics.selection()
                        showRepRangeEditor = true
                    } label: {
                        Text(exercise.repRange?.displayText ?? "")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Rep range")
                    .accessibilityValue(exercise.repRange?.displayText ?? "")
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanExerciseRepRangeButton(exercise))
                    .accessibilityHint("Edits the rep range.")
                }
                Spacer()
                HStack(spacing: 16) {
                    Button("History", systemImage: "clock.arrow.circlepath") {
                        Haptics.selection()
                        showExerciseHistorySheet = true
                    }
                    .accessibilityIdentifier("workoutPlanExerciseHistoryButton-\(exercise.catalogID)-\(exercise.index)")
                    .accessibilityHint("Shows prior performances for this exercise.")
                    .labelStyle(.iconOnly)
                    .font(.title)
                    .tint(.primary)

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
        .contextMenu {
            Button {
                Haptics.selection()
                showReplaceExerciseSheet = true
            } label: {
                Label("Replace Exercise", systemImage: "arrow.triangle.2.circlepath")
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanExerciseReplaceButton(exercise))
            .accessibilityHint("Replaces this exercise with another.")
            if let onDelete {
                Button(role: .destructive) {
                    Haptics.selection()
                    onDelete()
                } label: {
                    Label("Delete Exercise", systemImage: "trash")
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanExerciseDeleteButton(exercise))
                .accessibilityHint("Deletes this exercise.")
            }
        }
        .sheet(isPresented: $showRepRangeEditor, onDismiss: {
            saveContext(context: context)
        }) {
            RepRangeEditorView(repRange: exercise.repRange ?? RepRangePolicy(), catalogID: exercise.catalogID)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showRestTimeEditor, onDismiss: {
            saveContext(context: context)
        }) {
            RestTimeEditorView(exercise: exercise)
        }
        .sheet(isPresented: $showReplaceExerciseSheet) {
            ReplaceExerciseView { newExercise, keepSets in
                exercise.replaceWith(newExercise, keepSets: keepSets)
                saveContext(context: context)
            }
        }
        .sheet(isPresented: $showExerciseHistorySheet) {
            NavigationStack {
                ExerciseHistoryView(exercise: exercise)
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func addSet() {
        Haptics.selection()
        exercise.addSet()
        saveContext(context: context)
    }
}

private struct WorkoutPlanSetRowView: View {
    private enum Field {
        case reps
        case weight
    }

    @Environment(\.modelContext) private var context
    @Bindable var set: SetPrescription
    @Bindable var exercise: ExercisePrescription
    @FocusState private var focusedField: Field?

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
                if (exercise.sets?.count ?? 0) > 1 {
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
                .focused($focusedField, equals: .reps)
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanSetRepsField(exercise, set: set))
                .accessibilityLabel("Reps")

            TextField("Weight", value: $set.targetWeight, format: .number)
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: .weight)
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanSetWeightField(exercise, set: set))
                .accessibilityLabel("Weight")
        }
        .onChange(of: focusedField) { _, field in
            guard field != nil else { return }
            selectAllFocusedText()
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
