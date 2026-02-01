import SwiftUI
import SwiftData

struct WorkoutPlanPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(WorkoutPlan.all) private var workoutPlans: [WorkoutPlan]
    @Binding var selectedPlan: WorkoutPlan?
    @State private var newWorkoutPlan: WorkoutPlan?
    @State private var newWorkoutPlanID: UUID?

    var body: some View {
        NavigationStack {
            List {
                ForEach(workoutPlans) { plan in
                    NavigationLink {
                        WorkoutPlanDetailView(plan: plan) {
                            selectedPlan = plan
                            saveContext(context: context)
                            dismiss()
                        }
                    } label: {
                        WorkoutPlanCardView(workoutPlan: plan)
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .navigationLinkIndicatorVisibility(.hidden)
                }
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanPickerList)
            .navigationTitle("Select Plan")
            .toolbarTitleDisplayMode(.inline)
            .listStyle(.plain)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear") {
                        Haptics.selection()
                        selectedPlan = nil
                        saveContext(context: context)
                        dismiss()
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanPickerClearButton)
                    .accessibilityHint("Removes the selected workout plan.")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create", systemImage: "plus") {
                        createWorkoutPlan()
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanPickerCreateButton)
                    .accessibilityHint("Creates a new workout plan to select.")
                }
            }
            .overlay {
                if workoutPlans.isEmpty {
                    ContentUnavailableView("No Workout Plans", systemImage: "list.clipboard", description: Text("Create a workout plan to assign it here."))
                }
            }
        }
        .fullScreenCover(item: $newWorkoutPlan, onDismiss: handleNewWorkoutPlanDismissal) {
            WorkoutPlanView(plan: $0)
        }
    }

    private func createWorkoutPlan() {
        Haptics.selection()
        let plan = WorkoutPlan()
        context.insert(plan)
        saveContext(context: context)
        newWorkoutPlanID = plan.id
        newWorkoutPlan = plan
    }

    private func handleNewWorkoutPlanDismissal() {
        defer {
            newWorkoutPlanID = nil
            newWorkoutPlan = nil
        }

        guard let id = newWorkoutPlanID else { return }
        let predicate = #Predicate<WorkoutPlan> { $0.id == id }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        guard let storedPlan = try? context.fetch(descriptor).first else { return }
        guard storedPlan.completed else { return }
        selectedPlan = storedPlan
        saveContext(context: context)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        WorkoutPlanPickerView(selectedPlan: .constant(sampleCompletedPlan()))
    }
    .sampleDataContainer()
}
