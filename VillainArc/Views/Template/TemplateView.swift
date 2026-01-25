import SwiftUI
import SwiftData

struct TemplateView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var template: WorkoutTemplate
    let isEditing: Bool
    
    @State private var showAddExerciseSheet = false
    
    init(template: WorkoutTemplate, isEditing: Bool = false) {
        self.template = template
        self.isEditing = isEditing
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
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            Haptics.selection()
                            context.delete(template)
                            saveContext(context: context)
                            dismiss()
                        }
                        .accessibilityIdentifier("templateCancelButton")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Done" : "Save") {
                        Haptics.selection()
                        saveContext(context: context)
                        if template.complete {
                            dismiss()
                        } else {
                            template.complete = true
                            dismiss()
                        }
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
                }
            }
            .sheet(isPresented: $showAddExerciseSheet) {
                AddExerciseView(template: template)
                    .interactiveDismissDisabled()
            }
        }
    }
    
    private func deleteExercise(offsets: IndexSet) {
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
}

struct TemplateExerciseEditSection: View {
    @Environment(\.modelContext) private var context
    @Bindable var exercise: TemplateExercise
    @State private var showRepRangeEditorSheet = false
    @State private var showRestTimeEditorSheet = false
    
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
            .accessibilityIdentifier("templateExerciseSetStepper-\(exercise.catalogID)")
            
            Button {
                Haptics.selection()
                showRepRangeEditorSheet = true
            } label: {
                HStack {
                    Text("Rep Range")
                    Spacer()
                    Text(exercise.repRange.displayText)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.primary)
            .buttonStyle(.borderless)
            .accessibilityIdentifier("templateExerciseRepRangeButton-\(exercise.catalogID)")
            
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
            .accessibilityIdentifier("templateExerciseRestTimeButton-\(exercise.catalogID)")
            
            TextField("Notes", text: $exercise.notes, axis: .vertical)
                .accessibilityIdentifier("templateExerciseNotes-\(exercise.catalogID)")
        }
        .accessibilityIdentifier("templateExerciseSection-\(exercise.catalogID)")
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
