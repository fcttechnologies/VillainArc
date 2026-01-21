import SwiftUI
import SwiftData

enum WorkoutFinishAction {
    case markAllComplete
    case deleteIncomplete
}

struct WorkoutSettingsView: View {
    @Bindable var workout: Workout
    let isEditing: Bool
    var onFinish: (WorkoutFinishAction) -> Void
    var onDelete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @State private var showDeleteConfirmation: Bool = false
    @State private var showSaveConfirmation: Bool = false
    @FocusState private var isTitleFocused: Bool
    
    private var incompleteSetCount: Int {
        workout.exercises.reduce(0) { count, exercise in
            count + exercise.sets.filter { !$0.complete }.count
        }
    }

    private var endTimeBinding: Binding<Date> {
        Binding(
            get: {
                if let endTime = workout.endTime, endTime >= workout.startTime {
                    return endTime
                }
                return workout.startTime
            },
            set: { workout.endTime = $0 }
        )
    }
        
    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Workout Title", text: $workout.title)
                        .focused($isTitleFocused)
                        .onSubmit {
                            normalizeTitleIfNeeded()
                        }
                }
                
                Section("Workout Notes") {
                    TextField("Workout Notes", text: $workout.notes, axis: .vertical)
                }
                
                Section("Time") {
                    DatePicker("Start Time", selection: $workout.startTime, in: ...Date.now, displayedComponents: [.date, .hourAndMinute])
                    if isEditing {
                        DatePicker("End Time", selection: endTimeBinding, in: workout.startTime...Date.now, displayedComponents: [.date, .hourAndMinute])
                    }
                }
                
                Section {
                    ForEach(workout.sortedExercises) { exercise in
                        HStack {
                            Text(exercise.name)
                                .fontWeight(.semibold)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Text("^[\(exercise.sortedSets.count) set](inflect: true)")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }
                    }
                } header: {
                    Text("Exercises")
                } footer: {
                    if incompleteSetCount > 0 {
                        Text("Some exercises have incomplete sets.")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) {
                        Haptics.success()
                        dismiss()
                    }
                }
                if !isEditing {
                    ToolbarItem(placement: .bottomBar) {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete Workout", systemImage: "trash")
                                .fontWeight(.semibold)
                        }
                        .tint(.red)
                        .buttonStyle(.glassProminent)
                        .confirmationDialog("Delete Workout", isPresented: $showDeleteConfirmation) {
                            Button("Delete", role: .destructive) {
                                onDelete()
                            }
                        } message: {
                            Text("Are you sure you want to delete this workout? This cannot be undone.")
                        }
                    }
                    ToolbarSpacer(.flexible, placement: .bottomBar)
                    ToolbarItem(placement: .bottomBar) {
                        Button {
                            showSaveConfirmation = true
                        } label: {
                            Label("Finish Workout", systemImage: "checkmark")
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.green)
                        .confirmationDialog("Finish Workout", isPresented: $showSaveConfirmation) {
                            if incompleteSetCount > 0 {
                                Button("Mark All Sets Complete and Finish") {
                                    onFinish(.markAllComplete)
                                }
                                Button("Delete Incomplete Sets and Finish", role: .destructive) {
                                    onFinish(.deleteIncomplete)
                                }
                            } else {
                                Button("Finish", role: .confirm) {
                                    onFinish(.markAllComplete)
                                }
                            }
                        } message: {
                            if incompleteSetCount > 0 {
                                Text("Choose how to handle incomplete sets.")
                            } else {
                                Text("Finish and save this workout?")
                            }
                        }
                    }
                }
            }
            .onChange(of: workout.startTime) {
                if isEditing, let endTime = workout.endTime, endTime < workout.startTime {
                    workout.endTime = workout.startTime
                }
                saveContext(context: context)
            }
            .onChange(of: workout.endTime) {
                saveContext(context: context)
            }
            .onChange(of: workout.title) {
                saveContext(context: context)
            }
            .onChange(of: workout.notes) {
                saveContext(context: context)
            }
            .onChange(of: isTitleFocused) {
                if !isTitleFocused {
                    normalizeTitleIfNeeded()
                }
            }
            .onDisappear {
                normalizeTitleIfNeeded()
            }
            .scrollDismissesKeyboard(.immediately)
            .simultaneousGesture(
                TapGesture().onEnded {
                    dismissKeyboard()
                }
            )
        }
    }

    private func normalizeTitleIfNeeded() {
        if workout.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            workout.title = "New Workout"
            saveContext(context: context)
        }
    }
}

#Preview {
    WorkoutSettingsView(workout: sampleWorkout(), isEditing: false) { _ in
        // no-op
    } onDelete: {
        // no-op
    }
    .sampleDataConainer()
}
