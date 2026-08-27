import FCTMetrics
import SwiftUI
import SwiftData
import AppIntents

struct WorkoutPlanView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var router = AppRouter.shared
    
    @Bindable var plan: WorkoutPlan
    private let originalPlan: WorkoutPlan?
    @State private var initialStructureSnapshot: PlanStructureSnapshot

    @State private var showAddExerciseSheet = false
    @State private var showCancelWorkoutPlanConfirmation = false
    @State private var showExerciseEditSheet = false
    @State private var showTitleEditorSheet = false
    @State private var showNotesEditorSheet = false
    @State private var showDeletePlanConfirmation = false
    @State private var planDeletionAssessment: WorkoutPlanDeletionCoordinator.Assessment?
    /// True while any set field in a `WorkoutPlanExerciseView` owns keyboard focus. Drives the Save
    /// button to temporarily become a keyboard-dismiss button.
    @State private var isSetFieldFocused = false
    @Query(AppSettings.single) private var appSettings: [AppSettings]

    private var weightUnit: WeightUnit { appSettings.first?.weightUnit ?? .lbs }

    init(plan: WorkoutPlan, originalPlan: WorkoutPlan? = nil) {
        self.plan = plan
        self.originalPlan = originalPlan
        _initialStructureSnapshot = State(initialValue: Self.makeStructureSnapshot(for: plan))
    }

    private var isEditingExistingPlan: Bool {
        originalPlan != nil
    }

    private func animated<Result>(_ animation: Animation, _ updates: () -> Result) -> Result {
        withAnimation(reduceMotion ? nil : animation, updates)
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
                .scrollContentBackground(.hidden)
                .appBackground()
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel", systemImage: "xmark", role: .cancel) {
                            Haptics.selection()
                            if isEditingExistingPlan {
                                if Self.makeStructureSnapshot(for: plan) != initialStructureSnapshot {
                                    showCancelWorkoutPlanConfirmation = true
                                } else {
                                    discardEditingCopyAndDismiss()
                                }
                            } else if plan.completed {
                                dismissPresentedPlanEditor()
                            } else if plan.sortedExercises.isEmpty {
                                deleteDraftPlanAndDismiss()
                            } else {
                                showCancelWorkoutPlanConfirmation = true
                            }
                        }
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanCancelButton)
                        .confirmationDialog(isEditingExistingPlan ? "Discard Changes?" : "Cancel Workout Plan?", isPresented: $showCancelWorkoutPlanConfirmation) {
                            Button(isEditingExistingPlan ? "Discard Changes" : "Cancel Plan", role: .destructive) {
                                if isEditingExistingPlan {
                                    discardEditingCopyAndDismiss()
                                } else {
                                    deleteDraftPlanAndDismiss()
                                }
                            }
                            .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanConfirmCancelButton)
                        } message: {
                            Text(isEditingExistingPlan ? "Are you sure you want to discard your changes to this workout plan?" : "Are you sure you want to cancel this workout plan?")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        if isSetFieldFocused {
                            // While a set field is focused the Save button becomes the keyboard-dismiss
                            // button (the old keyboard-accessory button never fired — see learnings).
                            Button("Done", systemImage: "keyboard.chevron.compact.down", role: .confirm) {
                                dismissKeyboard()
                            }
                            .accessibilityLabel("Dismiss Keyboard")
                        } else {
                            Button(isEditingExistingPlan || plan.completed ? "Done" : "Save") {
                                Haptics.selection()
                                plan.convertTargetWeightsToKg(from: weightUnit)
                                if let originalPlan {
                                    originalPlan.applyEditingCopy(plan, context: context)
                                    saveContext(context: context)
                                    SpotlightIndexer.index(workoutPlan: originalPlan)
                                    SpotlightIndexer.reindexLinkedWorkoutSplits(for: originalPlan)
                                    discardEditingCopyAndDismiss()
                                    return
                                }
                                if !plan.completed {
                                    plan.completed = true
                                    Diag.breadcrumb(VACrumb.planCreated)
                                }
                                plan.clearCompletedSessionPerformanceReferences()
                                saveContext(context: context)
                                SpotlightIndexer.index(workoutPlan: plan)
                                SpotlightIndexer.reindexLinkedWorkoutSplits(for: plan)
                                dismissPresentedPlanEditor()
                            }
                            .disabled(plan.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || plan.sortedExercises.isEmpty)
                            .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanSaveButton)
                        }
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
                .presentationBackground(Color.sheetBg)
            }
                .sheet(isPresented: $showAddExerciseSheet) {
                    AddExerciseView(plan: plan)
                        .presentationBackground(Color.sheetBg)
                }
                .sheet(isPresented: $showNotesEditorSheet) {
                    TextEntryEditorView(title: "Notes", promptText: "Plan Notes", text: $plan.notes, accessibilityIdentifier: AccessibilityIdentifiers.workoutPlanNotesEditorField, isTitle: true)
                        .presentationDetents([.fraction(0.4)])
                        .presentationBackground(Color.sheetBg)
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
                    TextEntryEditorView(title: "Title", promptText: "Workout Plan Title", text: $plan.title, accessibilityIdentifier: AccessibilityIdentifiers.workoutPlanTitleEditorField, initialSelectionBehavior: .whenTextMatches(["New Workout Plan"]))
                        .presentationDetents([.fraction(0.2)])
                        .presentationBackground(Color.sheetBg)
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
                        confirmDeletePlanAndDismiss()
                    }
                } message: {
                    Text("Removing the last exercise will delete this plan.")
                }
                .alert(planDeletionAssessment?.confirmationTitle ?? "Delete Workout Plan?", isPresented: planDeletionAlertBinding) {
                    Button(planDeletionAssessment?.destructiveButtonTitle ?? "Delete", role: .destructive) {
                        guard let planDeletionAssessment else { return }
                        performDeletePlanAndDismiss(using: planDeletionAssessment)
                    }
                    Button("Cancel", role: .cancel) {
                        planDeletionAssessment = nil
                    }
                } message: {
                    Text(planDeletionAssessment?.confirmationMessage ?? "")
                }
        }
        // Soft scroll-edge fade for this separate presentation context — ContentView's root
        // modifier doesn't reach full-screen covers. Inert on the iOS 26 SDK (see ContentView).
        .scrollEdgeEffectStyle(.soft, for: .all)
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
                        WorkoutPlanExerciseView(exercise: exercise, originalExercise: originalPlan?.sortedExercises.first(where: { $0.id == exercise.id }), isFieldFocused: $isSetFieldFocused, onDelete: { deleteExercise(exercise) })
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
        let exercises = plan.sortedExercises

        return ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(exercises, id: \.id) { exercise in
                    exerciseEditorRow(
                        for: exercise,
                        index: exercises.firstIndex(where: { $0.id == exercise.id }) ?? 0
                    )
                }
                .reorderable()
            }
            .reorderContainer(for: ExercisePrescription.self) { difference in
                applyNativeExerciseReorder(difference)
            }
            .padding()
        }
        .scrollIndicators(.hidden)
        .sheetBackground()
        .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanExerciseList)
    }

    @ViewBuilder
    private func exerciseEditorRow(for exercise: ExercisePrescription, index: Int) -> some View {
        HStack(spacing: 14) {
            Button {
                deleteExercise(exercise)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.red)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete \(exercise.name)")
            .accessibilityHint("Removes this exercise from the workout plan.")

            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.title3)
                    .bold()
                    .lineLimit(1)
                HStack(alignment: .bottom) {
                    Text(exercise.equipmentType.displayName)
                        .foregroundStyle(.secondary)
                        .fontWeight(.semibold)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text(localizedCountText(exercise.sortedSets.count, singular: "set", plural: "sets"))
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanExerciseListRow(exercise))
            .accessibilityLabel(exercise.name)
            .accessibilityValue(AccessibilityText.workoutPlanExerciseListValue(for: exercise))

            Image(systemName: "line.3.horizontal")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 28, height: 28)
                .contentShape(.rect)
                .accessibilityLabel("Reorder \(exercise.name)")
                .accessibilityHint("Drag to change the exercise order.")
        }
        .contentShape(.rect)
        .appGroupedStackRow(position: rowPosition(for: index, count: plan.sortedExercises.count))
    }

    private func applyNativeExerciseReorder(
        _ difference: ReorderDifference<UUID, ReorderableSingleCollectionIdentifier>
    ) {
        let exercises = plan.sortedExercises
        let destinationID: UUID?
        switch difference.destination.position {
        case .before(let id):
            destinationID = id
        case .end:
            destinationID = nil
        }
        let orderedIDs = ReorderSupport.applying(
            current: exercises.map(\.id),
            sources: difference.sources,
            destinationBefore: destinationID
        )
        let exercisesByID = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })

        animated(.snappy) {
            for (index, id) in orderedIDs.enumerated() {
                exercisesByID[id]?.index = index
            }
        }
        saveContext(context: context)
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
        if plan.sortedExercises.isEmpty {
            showExerciseEditSheet = false
        }
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

    private func rowPosition(for index: Int, count: Int) -> AppGroupedListRowPosition {
        if count <= 1 { return .single }
        if index == 0 { return .top }
        if index == count - 1 { return .bottom }
        return .middle
    }

    private func confirmDeletePlanAndDismiss() {
        guard let targetPlan = deletionTargetPlan else {
            deleteDraftPlanAndDismiss()
            return
        }
        let assessment = WorkoutPlanDeletionCoordinator.assess(plans: [targetPlan], context: context)
        if assessment.requiresWarning {
            planDeletionAssessment = assessment
            return
        }
        performDeletePlanAndDismiss(using: assessment)
    }

    private var deletionTargetPlan: WorkoutPlan? {
        if let originalPlan {
            return originalPlan
        }
        return plan.completed ? plan : nil
    }

    private func performDeletePlanAndDismiss(using assessment: WorkoutPlanDeletionCoordinator.Assessment) {
        let wasPresentedEditor = router.activeWorkoutPlan?.id == plan.id
        planDeletionAssessment = nil
        WorkoutPlanDeletionCoordinator.delete(assessment, context: context)
        if !wasPresentedEditor {
            dismissPresentedPlanEditor()
        }
    }

    private func deleteDraftPlanAndDismiss() {
        Haptics.selection()
        plan.deleteWithSuggestionCleanup(context: context)
        try? context.save()
        dismissPresentedPlanEditor()
    }

    private func dismissPresentedPlanEditor() {
        if router.activeWorkoutPlan?.id == plan.id {
            router.activeWorkoutPlan = nil
        } else {
            dismiss()
        }
    }

    private func discardEditingCopyAndDismiss() {
        let editingCopy = plan
        if router.activeWorkoutPlan?.id == plan.id {
            router.pendingWorkoutPlanDismissCleanup = {
                context.delete(editingCopy)
            }
        } else {
            context.delete(editingCopy)
        }
        dismissPresentedPlanEditor()
    }

    private static func makeStructureSnapshot(for plan: WorkoutPlan) -> PlanStructureSnapshot {
        PlanStructureSnapshot(
            title: plan.title.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: plan.notes.trimmingCharacters(in: .whitespacesAndNewlines),
            exercises: plan.sortedExercises.map {
                ExerciseStructureSnapshot(id: $0.id, catalogID: $0.catalogID, setCount: $0.sortedSets.count)
            }
        )
    }

    private var planDeletionAlertBinding: Binding<Bool> {
        Binding(
            get: { planDeletionAssessment != nil },
            set: { isPresented in
                if !isPresented {
                    planDeletionAssessment = nil
                }
            }
        )
    }
}

private struct PlanStructureSnapshot: Equatable {
    let title: String
    let notes: String
    let exercises: [ExerciseStructureSnapshot]
}

private struct ExerciseStructureSnapshot: Equatable {
    let id: UUID
    let catalogID: String
    let setCount: Int
}

private struct WorkoutPlanExerciseView: View {
    @Environment(\.modelContext) private var context
    @Bindable var exercise: ExercisePrescription
    let originalExercise: ExercisePrescription?
    // Declared before `onDelete` so the synthesized memberwise-init argument order matches the call
    // site (memberwise-init order follows stored-property declaration order — see learnings).
    let isFieldFocused: Binding<Bool>
    let onDelete: (() -> Void)?

    @State private var showRepRangeEditor = false
    @State private var showRestTimeEditor = false
    @State private var showReplaceExerciseSheet = false
    @State private var showExerciseHistorySheet = false
    @State private var progressionStepExercise: Exercise?
    @FocusState private var focusedSetField: SetFieldFocus?

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
                        WorkoutPlanSetRowView(set: set, exercise: exercise, focusedField: $focusedSetField)
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
        .onChange(of: focusedSetField) { _, field in
            isFieldFocused.wrappedValue = field != nil
            guard field != nil else { return }
            selectAllFocusedText()
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
        .appCardStyle()
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
                .presentationDetents([.medium])
                .presentationBackground(Color.sheetBg)
        }
        .sheet(isPresented: $showRestTimeEditor) {
            RestTimeEditorView(exercise: exercise)
                .presentationDetents([.medium, .large])
                .presentationBackground(Color.sheetBg)
        }
        .sheet(isPresented: $showReplaceExerciseSheet) {
            ReplaceExerciseView(currentCatalogID: exercise.catalogID, sourceMuscles: Set(exercise.musclesTargeted), sourceEquipmentType: exercise.equipmentType) { newExercise, keepSets in
                exercise.replaceWith(newExercise, keepSets: keepSets, context: context)
                saveContext(context: context)
            }
            .presentationBackground(Color.sheetBg)
        }
        .sheet(isPresented: $showExerciseHistorySheet) {
            NavigationStack {
                ExerciseHistoryView(exercise: exercise, showSheetBackground: true)
            }
            .presentationDetents([.medium, .large])
            .presentationBackground(Color.sheetBg)
        }
        .sheet(item: $progressionStepExercise) { progressionStepExercise in
            ExerciseSuggestionSettingsSheet(exercise: progressionStepExercise)
                .presentationBackground(Color.sheetBg)
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
    @Environment(\.modelContext) private var context
    @Bindable var set: SetPrescription
    @Bindable var exercise: ExercisePrescription
    @Query(AppSettings.single) private var appSettings: [AppSettings]
    // The keyboard accessory and focus are owned by the parent `WorkoutPlanExerciseView` so there
    // is exactly ONE `.keyboard` toolbar in the hierarchy (see learnings.md "Keyboard toolbar").
    var focusedField: FocusState<SetFieldFocus?>.Binding

    private var weightUnit: WeightUnit { appSettings.first?.weightUnit ?? .lbs }
    private var loadFieldLabel: String { exercise.equipmentType.loadDisplayName }

    var body: some View {
        Group {
            Menu {
                Picker(selection: Binding(get: { set.type }, set: { newValue in
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
                } label: {
                    EmptyView()
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
                .focused(focusedField, equals: .reps(set.id))
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanSetRepsField(exercise, set: set))
                .accessibilityLabel(AccessibilityText.exerciseSetRepsLabel)

            TextField(loadFieldLabel, value: $set.targetWeight, format: .number)
                .keyboardType(.decimalPad)
                .focused(focusedField, equals: .weight(set.id))
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanSetWeightField(exercise, set: set))
                .accessibilityLabel(loadFieldLabel)
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
        focusedField.wrappedValue = nil
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
            .appCircleStyle()
            .overlay(alignment: .topTrailing) {
                if let visibleTargetRPE = set.visibleTargetRPE {
                    RPEBadge(value: visibleTargetRPE, style: .target)
                        .offset(x: visibleTargetRPE == 10 ? -2 : -8)
                }
            }
    }
}

#Preview("Creating", traits: .sampleDataIncomplete) {
    WorkoutPlanView(plan: sampleIncompletePlan())
}

#Preview("Editing", traits: .sampleData) {
    WorkoutPlanView(plan: sampleEditingPlan())
}
