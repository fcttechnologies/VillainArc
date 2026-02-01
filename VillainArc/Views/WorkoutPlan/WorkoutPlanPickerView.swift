import SwiftUI
import SwiftData

struct WorkoutPlanPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(WorkoutPlan.all) private var workoutPlans: [WorkoutPlan]
    @Binding var selectedPlan: WorkoutPlan?

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
                    Button("Clear", role: .destructive) {
                        Haptics.selection()
                        selectedPlan = nil
                        saveContext(context: context)
                        dismiss()
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanPickerClearButton)
                    .accessibilityHint("Removes the selected workout plan.")
                }
            }
            .overlay {
                if workoutPlans.isEmpty {
                    ContentUnavailableView("No Workout Plans", systemImage: "list.clipboard", description: Text("Create a workout plan to assign it here."))
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        WorkoutPlanPickerView(selectedPlan: .constant(sampleCompletedPlan()))
    }
    .sampleDataContainer()
}
