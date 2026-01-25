import SwiftUI
import SwiftData

struct TemplateView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var template: WorkoutTemplate
    let isEditing: Bool
    let onDeleteFromEdit: (() -> Void)?
    
    @State private var showAddExerciseSheet = false
    @State private var showDeleteTemplateConfirmation = false
    @State private var showCancelTemplateConfirmation = false
    
    init(template: WorkoutTemplate, isEditing: Bool = false, onDeleteFromEdit: (() -> Void)? = nil) {
        self.template = template
        self.isEditing = isEditing
        self.onDeleteFromEdit = onDeleteFromEdit
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Template Name", text: $template.name)
                        .accessibilityIdentifier("templateNameField")
                }
                
                Section("Notes") {
                    TextField("Notes", text: $template.notes, axis: .vertical)
                        .accessibilityIdentifier("templateNotesField")
                }
                
                ForEach(template.sortedExercises) { exercise in
                    Section {
                        TemplateExerciseEditSection(exercise: exercise)
                    }
                }
                .onDelete(perform: deleteExercise)
                .onMove(perform: moveExercise)
            }
            .accessibilityIdentifier("templateEditingForm")
            .navigationTitle(isEditing ? "Edit Template" : "New Template")
            .toolbarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.immediately)
            .simultaneousGesture(
                TapGesture().onEnded {
                    dismissKeyboard()
                }
            )
            .toolbar {
                if !isEditing {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel Template Creation", systemImage: "xmark", role: .cancel) {
                            Haptics.selection()
                            if template.exercises.isEmpty {
                                deleteTemplateAndDismiss()
                            } else {
                                showCancelTemplateConfirmation = true
                            }
                        }
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier("templateCancelButton")
                        .confirmationDialog("Cancel Template?", isPresented: $showCancelTemplateConfirmation) {
                            Button("Cancel Template", role: .destructive) {
                                deleteTemplateAndDismiss()
                            }
                            .accessibilityIdentifier("templateConfirmCancelButton")
                        } message: {
                            Text("Are you sure you want to cancel this template?")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Done" : "Save") {
                        Haptics.selection()
                        if !template.complete {
                            template.complete = true
                        }
                        saveContext(context: context)
                        SpotlightIndexer.index(template: template)
                        dismiss()
                    }
                    .disabled(template.name.isEmpty || template.exercises.isEmpty)
                    .accessibilityIdentifier("templateSaveButton")
                }
                ToolbarSpacer(.flexible, placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    Button("Add Exercise", systemImage: "plus") {
                        Haptics.selection()
                        showAddExerciseSheet = true
                    }
                    .accessibilityIdentifier("templateAddExerciseButton")
                    .accessibilityHint("Adds an exercise.")
                }
            }
            .sheet(isPresented: $showAddExerciseSheet) {
                AddExerciseView(template: template)
                    .interactiveDismissDisabled()
            }
        }
        .alert("Delete Template?", isPresented: $showDeleteTemplateConfirmation) {
            Button("Delete Template", role: .destructive) {
                deleteTemplateFromEdit()
            }
            .accessibilityIdentifier("templateConfirmDeleteButton")
        } message: {
            Text("This is the last exercise. Deleting it will delete the template.")
        }
    }
    
    private func deleteExercise(offsets: IndexSet) {
        guard !offsets.isEmpty else { return }
        if isEditing, template.exercises.count - offsets.count == 0 {
            showDeleteTemplateConfirmation = true
            return
        }
        deleteExercises(at: offsets)
    }

    private func deleteExercises(at offsets: IndexSet) {
        Haptics.selection()
        let exercisesToDelete = offsets.map { template.sortedExercises[$0] }
        
        for exercise in exercisesToDelete {
            template.removeExercise(exercise)
            context.delete(exercise)
        }
        saveContext(context: context)
    }
    
    private func moveExercise(from source: IndexSet, to destination: Int) {
        template.moveExercise(from: source, to: destination)
        saveContext(context: context)
    }

    private func deleteTemplateAndDismiss() {
        Haptics.selection()
        context.delete(template)
        saveContext(context: context)
        dismiss()
    }

    private func deleteTemplateFromEdit() {
        Haptics.selection()
        onDeleteFromEdit?()
    }
}

struct TemplateExerciseEditSection: View {
    @Environment(\.modelContext) private var context
    @Bindable var exercise: TemplateExercise
    @State private var showRepRangeEditorSheet = false
    @State private var showRestTimeEditorSheet = false

    private var identifierSuffix: String {
        "\(exercise.catalogID)-\(exercise.index)"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(exercise.name)
                .fontWeight(.semibold)
            
            Stepper("^[\(exercise.sets.count) Set](inflect: true)", value: Binding(
                get: { exercise.sets.count },
                set: { newValue in
                    adjustSetCount(for: exercise, to: newValue)
                }
            ), in: 1...20)
            .accessibilityIdentifier("templateExerciseSetStepper-\(identifierSuffix)")
            .accessibilityHint("Adjusts set count.")
            
            Button {
                Haptics.selection()
                showRepRangeEditorSheet = true
            } label: {
                HStack {
                    Text("Rep Range")
                    Spacer()
                    Text(exercise.repRange.activeMode.displayName)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.primary)
            .buttonStyle(.borderless)
            .accessibilityIdentifier("templateExerciseRepRangeButton-\(identifierSuffix)")
            .accessibilityHint("Edits rep range.")
            
            Button {
                Haptics.selection()
                showRestTimeEditorSheet = true
            } label: {
                HStack {
                    Text("Rest Time Policy")
                    Spacer()
                    Text(exercise.restTimePolicy.activeMode.displayName)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.primary)
            .buttonStyle(.borderless)
            .accessibilityIdentifier("templateExerciseRestTimeButton-\(identifierSuffix)")
            .accessibilityHint("Edits rest time policy.")
            
            TextField("Notes", text: $exercise.notes, axis: .vertical)
                .accessibilityIdentifier("templateExerciseNotes-\(identifierSuffix)")
        }
        .accessibilityIdentifier("templateExerciseSection-\(identifierSuffix)")
        .sheet(isPresented: $showRepRangeEditorSheet) {
            RepRangeEditorView(repRange: exercise.repRange)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showRestTimeEditorSheet) {
            RestTimeEditorView(exercise: exercise)
        }
        .onChange(of: exercise.notes) {
            scheduleSave(context: context)
        }
    }
    
    private func adjustSetCount(for exercise: TemplateExercise, to newCount: Int) {
        Haptics.selection()
        let currentCount = exercise.sets.count
        
        if newCount > currentCount {
            for _ in currentCount..<newCount {
                exercise.addSet()
            }
        } else if newCount < currentCount {
            let setsToRemove = exercise.sortedSets.suffix(currentCount - newCount)
            for set in setsToRemove {
                exercise.removeSet(set)
                context.delete(set)
            }
        }
        saveContext(context: context)
    }
}

#Preview("Creating") {
    TemplateView(template: WorkoutTemplate(name: "Push Day"))
        .sampleDataConainer()
}

#Preview("Editing") {
    TemplateView(template: sampleTemplate(), isEditing: true)
        .sampleDataConainer()
}
