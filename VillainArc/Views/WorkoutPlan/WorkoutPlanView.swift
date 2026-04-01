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
    @Query(AppSettings.single) private var appSettings: [AppSettings]

    private var weightUnit: WeightUnit { appSettings.first?.weightUnit ?? .lbs }

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
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanCancelButton)
                    .confirmationDialog("Cancel Workout Plan?", isPresented: $showCancelWorkoutPlanConfirmation) {
                        Button("Cancel Plan", role: .destructive) {
                            deleteWorkoutPlanAndDismiss()
                        }
                        .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanConfirmCancelButton)
                    } message: {
                        Text("Are you sure you want to cancel this workout plan?")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditingExistingPlan || plan.completed ? "Done" : "Save") {
                        Haptics.selection()
                        plan.convertTargetWeightsToKg(from: weightUnit)
                        if let originalPlan {
                            originalPlan.applyEditingCopy(plan, context: context)
                            context.delete(plan)
                            saveContext(context: context)
                            SpotlightIndexer.index(workoutPlan: originalPlan)
                            SpotlightIndexer.reindexLinkedWorkoutSplits(for: originalPlan)
                            dismiss()
                            return
                        }
                        if !plan.completed {
                            plan.completed = true
                        }
                        plan.clearCompletedSessionPerformanceReferences()
                        saveContext(context: context)
                        SpotlightIndexer.index(workoutPlan: plan)
                        SpotlightIndexer.reindexLinkedWorkoutSplits(for: plan)
                        dismiss()
                    }
                    .disabled(plan.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || plan.sortedExercises.isEmpty)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanSaveButton)
                }
                ToolbarItem(placement: .bottomBar) {
                    if !plan.sortedExercises.isEmpty {
                        Button("Edit Exercises", systemImage: "pencil") {
                            Haptics.selection()
                            showExerciseEditSheet = true
                        }
                        .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanEditExercisesButton)
                        .accessibilityHint(AccessibilityText.workoutPlanEditExercisesHint)
                    }
                }
                ToolbarSpacer(.flexible, placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    Button("Add Exercise", systemImage: "plus") {
                        Haptics.selection()
                        showAddExerciseSheet = true
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanAddExerciseButton)
                    .accessibilityHint(AccessibilityText.workoutPlanAddExerciseHint)
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
                TextEntryEditorView(title: "Notes", promptText: "Plan Notes", text: $plan.notes, accessibilityIdentifier: AccessibilityIdentifiers.workoutPlanNotesEditorField, isTitle: true)
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
                ContentUnavailableView("No Exercises Added", systemImage: "dumbbell.fill", description: Text("Tap the \(Image(systemName: "plus")) button to add exercises."))
                    .padding(.horizontal)
                    .containerRelativeFrame([.horizontal, .vertical])
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanExercisesEmptyState)
            } else {
                LazyVStack(spacing: 60) {
                    ForEach(plan.sortedExercises) { exercise in
                        WorkoutPlanExerciseView(exercise: exercise, originalExercise: originalPlan?.sortedExercises.first(where: { $0.id == exercise.id }), onDelete: { deleteExercise(exercise) })
                            .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanExerciseView(exercise))
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
        .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanEditingForm)
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
                        Text(exercise.equipmentType.displayName)
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
        .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanExerciseList)
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
            let linkedSplits = SpotlightIndexer.linkedWorkoutSplits(for: originalPlan)
            SpotlightIndexer.deleteWorkoutPlan(id: originalPlan.id)
            originalPlan.deleteWithSuggestionCleanup(context: context)
            context.delete(plan)
            try? context.save()
            SpotlightIndexer.index(workoutSplits: linkedSplits)
            dismiss()
            return
        }
        let linkedSplits = SpotlightIndexer.linkedWorkoutSplits(for: plan)
        if plan.completed {
            SpotlightIndexer.deleteWorkoutPlan(id: plan.id)
        }
        plan.deleteWithSuggestionCleanup(context: context)
        try? context.save()
        SpotlightIndexer.index(workoutSplits: linkedSplits)
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
    let originalExercise: ExercisePrescription?
    let onDelete: (() -> Void)?

    @State private var showRepRangeEditor = false
    @State private var showRestTimeEditor = false
    @State private var showReplaceExerciseSheet = false
    @State private var showExerciseHistorySheet = false
    @State private var progressionStepExercise: Exercise?

    var body: some View {
        VStack(spacing: 12) {
            headerView
                .padding(.horizontal)

            Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    Text("Set")
                    Text("Reps")
                        .gridColumnAlignment(.leading)
                    Text(exercise.equipmentType.loadDisplayName)
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
            .accessibilityHint(AccessibilityText.workoutPlanExerciseAddSetHint)
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
                    Text(exercise.equipmentType.displayName)
                        .foregroundStyle(.secondary)
                        .fontWeight(.semibold)
                    if let repRange = exercise.repRange {
                        RepRangeButton(repRange: repRange, accessibilityIdentifier: AccessibilityIdentifiers.workoutPlanExerciseRepRangeButton(exercise)) { showRepRangeEditor = true }
                    }
                }
                Spacer()
                HStack(spacing: 16) {
                    Button("History", systemImage: "clock.arrow.circlepath") {
                        Haptics.selection()
                        showExerciseHistorySheet = true
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanExerciseHistoryButton(exercise))
                    .accessibilityHint(AccessibilityText.workoutPlanExerciseHistoryHint)
                    .labelStyle(.iconOnly)
                    .font(.title)
                    .tint(.primary)

                    Button("Rest Times", systemImage: "timer") {
                        Haptics.selection()
                        showRestTimeEditor = true
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanExerciseRestTimesButton(exercise))
                    .accessibilityHint(AccessibilityText.workoutPlanExerciseRestTimesHint)
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
                openProgressionStepEditor()
            } label: {
                Label("Suggestion Settings", systemImage: "slider.horizontal.3")
            }
            Button {
                Haptics.selection()
                showReplaceExerciseSheet = true
            } label: {
                Label("Replace Exercise", systemImage: "arrow.triangle.2.circlepath")
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanExerciseReplaceButton(exercise))
            .accessibilityHint(AccessibilityText.workoutPlanExerciseReplaceHint)
            if let onDelete {
                Button(role: .destructive) {
                    Haptics.selection()
                    onDelete()
                } label: {
                    Label("Delete Exercise", systemImage: "trash")
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanExerciseDeleteButton(exercise))
                .accessibilityHint(AccessibilityText.workoutPlanExerciseDeleteHint)
            }
        }
        .sheet(isPresented: $showRepRangeEditor) {
            RepRangeEditorView(repRange: exercise.repRange ?? RepRangePolicy(), catalogID: exercise.catalogID)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showRestTimeEditor) {
            RestTimeEditorView(exercise: exercise)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showReplaceExerciseSheet) {
            ReplaceExerciseView(currentCatalogID: exercise.catalogID) { newExercise, keepSets in
                exercise.replaceWith(newExercise, keepSets: keepSets, context: context)
                saveContext(context: context)
            }
        }
        .sheet(isPresented: $showExerciseHistorySheet) {
            NavigationStack {
                ExerciseHistoryView(exercise: exercise)
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: Binding(get: { progressionStepExercise != nil }, set: { if !$0 { progressionStepExercise = nil } })) {
            if let progressionStepExercise {
                ExerciseSuggestionSettingsSheet(exercise: progressionStepExercise)
            }
        }
    }

    private func addSet() {
        Haptics.selection()
        exercise.addSet(restoringFrom: originalExercise)
        saveContext(context: context)
    }

    private func openProgressionStepEditor() {
        guard let sourceExercise = try? context.fetch(Exercise.withCatalogID(exercise.catalogID)).first else { return }
        progressionStepExercise = sourceExercise
        Haptics.selection()
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
    @Query(AppSettings.single) private var appSettings: [AppSettings]
    @FocusState private var focusedField: Field?

    private var weightUnit: WeightUnit { appSettings.first?.weightUnit ?? .lbs }
    private var loadFieldLabel: String { exercise.equipmentType.loadDisplayName }

    var body: some View {
        Group {
            Menu {
                Picker("", selection: Binding(get: { set.type }, set: { newValue in
                    let oldValue = set.type
                    set.type = newValue
                    if newValue != oldValue {
                        Haptics.selection()
                        if newValue == .warmup {
                            set.targetRPE = 0
                        }
                        saveContext(context: context)
                    }
                })) {
                    ForEach(ExerciseSetType.allCases, id: \.self) { type in
                        Text(type.displayName)
                            .tag(type)
                    }
                }
                Divider()
                if set.type != .warmup {
                    Menu {
                        Picker("Target RPE", selection: Binding(
                            get: { set.targetRPE },
                            set: { newValue in
                                updateTargetRPE(to: set.targetRPE == newValue ? 0 : newValue)
                            }
                        )) {
                            ForEach(RPEValue.selectableValues, id: \.self) { value in
                                Label(RPEValue.pickerDescription(for: value, style: .target), systemImage: "\(value).circle")
                                    .tag(value)
                            }
                        }
                    } label: {
                        Label(targetRPELabel, systemImage: "flag.fill")
                        Text(RPEValue.menuSubtitle(for: set.visibleTargetRPE, style: .target))
                    }
                }
                if (exercise.sets?.count ?? 0) > 1 {
                    Button("Delete Set", systemImage: "trash", role: .destructive) {
                        deleteSet()
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanSetDeleteButton(exercise, set: set))
                }
            } label: {
                setIndicator
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanSetMenu(exercise, set: set))
            .accessibilityLabel(AccessibilityText.exerciseSetMenuLabel(for: set))
            .accessibilityValue(AccessibilityText.exerciseSetMenuValue(for: set))
            .accessibilityHint(AccessibilityText.exerciseSetMenuHint)

            TextField("Reps", value: $set.targetReps, format: .number)
                .keyboardType(.numberPad)
                .focused($focusedField, equals: .reps)
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanSetRepsField(exercise, set: set))
                .accessibilityLabel(AccessibilityText.exerciseSetRepsLabel)

            TextField(loadFieldLabel, value: $set.targetWeight, format: .number)
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: .weight)
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanSetWeightField(exercise, set: set))
                .accessibilityLabel(loadFieldLabel)
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

    private func updateTargetRPE(to value: Int) {
        guard set.targetRPE != value else { return }
        dismissKeyboard()
        focusedField = nil
        Haptics.selection()
        set.targetRPE = value
        saveContext(context: context)
    }

    private var targetRPELabel: String {
        if set.targetRPE == 0 {
            return String(localized: "Target RPE")
        }
        return String(localized: "Target RPE: \(set.targetRPE)")
    }

    private var setIndicator: some View {
        Text(set.type == .working ? String(set.index + 1) : set.type.shortLabel)
            .foregroundStyle(set.type.tintColor)
            .frame(width: 40, height: 40)
            .glassEffect(.regular, in: .circle)
            .overlay(alignment: .topTrailing) {
                if let visibleTargetRPE = set.visibleTargetRPE {
                    RPEBadge(value: visibleTargetRPE, style: .target)
                        .offset(x: visibleTargetRPE == 10 ? -2 : -8)
                }
            }
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
