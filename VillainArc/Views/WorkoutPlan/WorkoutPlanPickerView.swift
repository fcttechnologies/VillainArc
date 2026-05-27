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

    private var availableWorkoutPlans: [WorkoutPlan] {
        guard let selectedPlan else { return workoutPlans }
        return workoutPlans.filter { $0.id != selectedPlan.id }
    }

    @State private var showPlanBuilder = false

    init(selectedPlan: Binding<WorkoutPlan?>, showsClearButton: Bool = true) {
        _selectedPlan = selectedPlan
        self.showsClearButton = showsClearButton
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(availableWorkoutPlans) { plan in
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
                        Haptics.selection()
                        showPlanBuilder = true
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanPickerCreateButton)
                    .accessibilityHint(AccessibilityText.workoutPlanPickerCreateHint)
                }
            }
            .overlay {
                if availableWorkoutPlans.isEmpty {
                    if selectedPlan != nil {
                        ContentUnavailableView("No Other Workout Plans", systemImage: "list.clipboard", description: Text("Create another workout plan to assign a different one here."))
                    } else {
                        ContentUnavailableView("No Workout Plans", systemImage: "list.clipboard", description: Text("Create a workout plan to assign it here."))
                    }
                }
            }
        }
        .sheet(isPresented: $showPlanBuilder) {
            PlanBuilderSheet(
                onScratchSelected: {
                    createWorkoutPlan()
                },
                onTemplateDaySelected: { template, day in
                    let plan = PlanTemplateMaterializer.makeIncompletePlan(template: template, day: day, context: context)
                    saveContext(context: context)
                    newWorkoutPlanID = plan.id
                    newWorkoutPlan = plan
                },
                onProgramSelected: { template in
                    let split = PlanTemplateMaterializer.materializeProgram(template: template, activate: true, context: context)
                    saveContext(context: context)
                    if let firstPlan = split.sortedDays.compactMap(\.workoutPlan).first {
                        selectedPlan = firstPlan
                    }
                    ToastManager.shared.show(
                        ToastManager.Toast(
                            title: String(localized: "Program ready"),
                            message: String(localized: "Created \(split.sortedDays.filter { !$0.isRestDay }.count) plans and activated the \(template.name) split."),
                            systemImage: "calendar.badge.checkmark",
                            tint: .blue,
                            haptic: .success
                        )
                    )
                    dismiss()
                },
                onAIGenerated: { result in
                    if result.days.count <= 1, let onlyDay = result.days.first {
                        let plan = PlanTemplateMaterializer.makeIncompletePlan(aiDay: onlyDay, planTitle: result.name, planSummary: result.summary, context: context)
                        saveContext(context: context)
                        newWorkoutPlanID = plan.id
                        newWorkoutPlan = plan
                    } else {
                        let split = PlanTemplateMaterializer.materializeProgram(aiResult: result, activate: true, context: context)
                        saveContext(context: context)
                        if let firstPlan = split.sortedDays.compactMap(\.workoutPlan).first {
                            selectedPlan = firstPlan
                        }
                        ToastManager.shared.show(
                            ToastManager.Toast(
                                title: String(localized: "AI plan ready"),
                                message: String(localized: "Created \(split.sortedDays.count) plans and activated the \(result.name) split."),
                                systemImage: "sparkles",
                                tint: .purple,
                                haptic: .success
                            )
                        )
                        dismiss()
                    }
                }
            )
            .presentationBackground(Color.sheetBg)
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
        Task { await IntentDonations.donateCreateWorkoutPlan() }
        let plan = WorkoutPlan()
        context.insert(plan)
        saveContext(context: context)
        newWorkoutPlanID = plan.id
        newWorkoutPlan = plan
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        WorkoutPlanPickerView(selectedPlan: .constant(sampleCompletedPlan()))
    }
}
