import SwiftUI
import SwiftData

struct WorkoutPlanPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(WorkoutPlan.all) private var workoutPlans: [WorkoutPlan]
    @Binding var selectedPlan: WorkoutPlan?
    let showsClearButton: Bool
    @State private var newWorkoutPlan: WorkoutPlan?
    @State private var newWorkoutPlanID: UUID?

    init(selectedPlan: Binding<WorkoutPlan?>, showsClearButton: Bool = true) {
        _selectedPlan = selectedPlan
        self.showsClearButton = showsClearButton
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(workoutPlans) { plan in
                    NavigationLink {
                        WorkoutPlanDetailView(plan: plan, onSelect: {
                            selectedPlan = plan
                            saveContext(context: context)
                            dismiss()
                        }, showSheetBackground: true)
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
            .scrollContentBackground(.hidden)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if showsClearButton {
                        Button("Clear") {
                            Haptics.selection()
                            selectedPlan = nil
                            saveContext(context: context)
                            dismiss()
                        }
                        .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanPickerClearButton)
                        .accessibilityHint(AccessibilityText.workoutPlanPickerClearHint)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create", systemImage: "plus") {
                        createWorkoutPlan()
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanPickerCreateButton)
                    .accessibilityHint(AccessibilityText.workoutPlanPickerCreateHint)
                }
            }
            .overlay {
                if workoutPlans.isEmpty {
                    ContentUnavailableView("No Workout Plans", systemImage: "list.clipboard", description: Text("Create a workout plan to assign it here."))
                }
            }
        }
        .fullScreenCover(item: $newWorkoutPlan, onDismiss: {
            defer {
                newWorkoutPlanID = nil
                newWorkoutPlan = nil
            }

            guard let id = newWorkoutPlanID else { return }
            let predicate = #Predicate<WorkoutPlan> { $0.id == id }
            var descriptor = FetchDescriptor(predicate: predicate)
            descriptor.fetchLimit = 1
            guard let storedPlan = try? context.fetch(descriptor).first, storedPlan.completed else { return }
            selectedPlan = storedPlan
            saveContext(context: context)
            dismiss()
        }) {
            WorkoutPlanView(plan: $0)
        }
    }

    private func createWorkoutPlan() {
        Haptics.selection()
        let plan = WorkoutPlan()
        context.insert(plan)
        saveContext(context: context)
        Task { await IntentDonations.donateCreateWorkoutPlan() }
        newWorkoutPlanID = plan.id
        newWorkoutPlan = plan
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        WorkoutPlanPickerView(selectedPlan: .constant(sampleCompletedPlan()))
    }
}
