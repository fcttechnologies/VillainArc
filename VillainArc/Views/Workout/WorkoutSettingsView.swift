import SwiftUI
import SwiftData

struct WorkoutSettingsView: View {
    @Bindable var workout: Workout
    var onFinish: () -> Void
    var onDelete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @State private var showDeleteConfirmation: Bool = false
    @State private var showSaveConfirmation: Bool = false
        
    var body: some View {
        NavigationStack {
            Form {
                Section("Time") {
                    DatePicker("Start Time", selection: $workout.startTime, in: ...Date.now, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section("Exercises") {
                    ForEach(workout.sortedExercises) { exercise in
                            HStack {
                                Text(exercise.name)
                                    .fontWeight(.semibold)
                                Spacer()
                                Text("^[\(exercise.sortedSets.count) set](inflect: true)")
                                    .foregroundStyle(.secondary)
                                    .font(.subheadline)
                            }
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
                        Button("Finish", role: .confirm) {
                            onFinish()
                        }
                    } message: {
                        Text("Save and finish this workout?")
                    }
                }
            }
            .onChange(of: workout.startTime) {
                saveContext(context: context)
            }
        }
    }
}

#Preview {
    WorkoutSettingsView(workout: sampleWorkout()) {
        // no-op
    } onDelete: {
        // no-op
    }
    .sampleDataConainer()
}
