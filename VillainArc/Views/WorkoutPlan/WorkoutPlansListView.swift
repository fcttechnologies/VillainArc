import SwiftUI
import SwiftData

struct WorkoutPlansListView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(WorkoutPlan.all) private var workoutPlans: [WorkoutPlan]
    
    @State private var showDeleteAllConfirmation = false
    @State private var deleteAllAssessment: WorkoutPlanDeletionCoordinator.Assessment?
    @State private var deleteSelectionAssessment: WorkoutPlanDeletionCoordinator.Assessment?
    @State private var isEditing = false
    @State private var favoritesOnly = false
    @State private var previousFavoritesState = false

    var filteredWorkoutPlans: [WorkoutPlan] {
        if favoritesOnly {
            return workoutPlans.filter { $0.favorite }
        }
        return workoutPlans
    }
    
    var body: some View {
        List {
            ForEach(filteredWorkoutPlans) { plan in
                WorkoutPlanRowView(workoutPlan: plan)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .accessibilityHint(AccessibilityText.workoutPlanRowHint)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button(plan.favorite ? "Undo" : "Favorite", systemImage: plan.favorite ? "star.slash.fill" : "star.fill") {
                            plan.favorite.toggle()
                            saveContext(context: context)
                            Task { await IntentDonations.donateToggleWorkoutPlanFavorite(workoutPlan: plan) }
                        }
                        .tint(.yellow)
                    }
            }
            .onDelete(perform: deleteWorkoutPlan)
        }
        .quickActionContentBottomInset()
        .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlansList)
        .environment(\.editMode, Binding(get: { isEditing ? .active : .inactive }, set: { isEditing = $0 == .active }))
        .animation(reduceMotion ? nil : .smooth, value: isEditing)
        .navigationTitle("Workout Plans")
        .toolbarTitleDisplayMode(.inline)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationBarBackButtonHidden(isEditing)
        .alert("Delete All Workout Plans?", isPresented: $showDeleteAllConfirmation) {
            Button("Delete All", role: .destructive) {
                confirmDeleteAllWorkoutPlans()
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlansDeleteAllConfirmButton)
        } message: {
            Text("Are you sure you want to delete all workout plans?")
        }
        .alert(deleteAllAssessment?.confirmationTitle ?? "Delete All Workout Plans?", isPresented: deleteAllAlertBinding) {
            Button(deleteAllAssessment?.destructiveButtonTitle ?? "Delete All", role: .destructive) {
                guard let deleteAllAssessment else { return }
                performDeleteAll(using: deleteAllAssessment)
            }
            Button("Cancel", role: .cancel) {
                deleteAllAssessment = nil
            }
        } message: {
            Text(deleteAllAssessment?.confirmationMessage ?? "")
        }
        .alert(deleteSelectionAssessment?.confirmationTitle ?? "Delete Workout Plan?", isPresented: deleteSelectionAlertBinding) {
            Button(deleteSelectionAssessment?.destructiveButtonTitle ?? "Delete", role: .destructive) {
                guard let deleteSelectionAssessment else { return }
                performDeleteSelection(using: deleteSelectionAssessment)
            }
            Button("Cancel", role: .cancel) {
                deleteSelectionAssessment = nil
            }
        } message: {
            Text(deleteSelectionAssessment?.confirmationMessage ?? "")
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if isEditing {
                    Button("Delete All", systemImage: "trash", role: .destructive) {
                        showDeleteAllConfirmation = true
                    }
                    .tint(.red)
                    .labelStyle(.titleOnly)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlansDeleteAllButton)
                    .accessibilityHint(AccessibilityText.workoutPlansDeleteAllHint)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if !workoutPlans.isEmpty {
                    if isEditing {
                        Button("Done Editing", systemImage: "checkmark") {
                            isEditing = false
                            favoritesOnly = previousFavoritesState
                        }
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlansDoneEditingButton)
                        .accessibilityHint(AccessibilityText.workoutPlansDoneEditingHint)
                    } else {
                        Menu("Options", systemImage: "ellipsis") {
                            Toggle("Favorites", systemImage: "star", isOn: $favoritesOnly)
                                .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlansFavoritesToggle)
                                .accessibilityHint(AccessibilityText.workoutPlansFavoritesToggleHint)
                            Button("Edit", systemImage: "pencil") {
                                previousFavoritesState = favoritesOnly
                                favoritesOnly = false
                                isEditing = true
                            }
                            .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlansEditButton)
                            .accessibilityHint(AccessibilityText.workoutPlansEditHint)
                        }
                        .accessibilityLabel(AccessibilityText.workoutPlansOptionsMenuLabel)
                        .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlansOptionsMenu)
                        .accessibilityHint(AccessibilityText.workoutPlansOptionsMenuHint)
                    }
                }
            }
        }
        .overlay(alignment: .center) {
            if workoutPlans.isEmpty {
                ContentUnavailableView("No Workout Plans", systemImage: "list.clipboard", description: Text("Your created workout plans will appear here."))
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlansEmptyState)
            } else if favoritesOnly && filteredWorkoutPlans.isEmpty {
                ContentUnavailableView("No Favorites", systemImage: "star.slash", description: Text("Mark workout plans as favorite to see them here."))
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlansNoFavoritesState)
            }
        }
    }
    
    private func deleteWorkoutPlan(offsets: IndexSet) {
        guard !offsets.isEmpty else { return }
        Haptics.selection()
        let workoutPlansToDelete = offsets.map { filteredWorkoutPlans[$0] }
        let assessment = WorkoutPlanDeletionCoordinator.assess(plans: workoutPlansToDelete, context: context)
        if assessment.requiresWarning {
            deleteSelectionAssessment = assessment
            return
        }
        performDeleteSelection(using: assessment)
    }

    private func confirmDeleteAllWorkoutPlans() {
        Haptics.selection()
        let assessment = WorkoutPlanDeletionCoordinator.assess(plans: workoutPlans, context: context)
        if assessment.requiresWarning {
            deleteAllAssessment = assessment
            return
        }
        performDeleteAll(using: assessment)
    }

    private func performDeleteSelection(using assessment: WorkoutPlanDeletionCoordinator.Assessment) {
        let deletedPlanToDonate = assessment.plans.count == 1 ? assessment.plans.first.map(WorkoutPlanEntity.init(workoutPlan:)) : nil
        deleteSelectionAssessment = nil
        WorkoutPlanDeletionCoordinator.delete(assessment, context: context)
        if let deletedPlanToDonate {
            Task { await IntentDonations.donateDeleteWorkoutPlan(workoutPlan: deletedPlanToDonate) }
        }
        if workoutPlans.isEmpty {
            isEditing = false
            favoritesOnly = false
        }
    }

    private func performDeleteAll(using assessment: WorkoutPlanDeletionCoordinator.Assessment) {
        deleteAllAssessment = nil
        WorkoutPlanDeletionCoordinator.delete(assessment, context: context)
        Task { await IntentDonations.donateDeleteAllWorkoutPlans() }
        isEditing = false
        favoritesOnly = false
    }

    private var deleteAllAlertBinding: Binding<Bool> {
        Binding(
            get: { deleteAllAssessment != nil },
            set: { isPresented in
                if !isPresented {
                    deleteAllAssessment = nil
                }
            }
        )
    }

    private var deleteSelectionAlertBinding: Binding<Bool> {
        Binding(
            get: { deleteSelectionAssessment != nil },
            set: { isPresented in
                if !isPresented {
                    deleteSelectionAssessment = nil
                }
            }
        )
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        WorkoutPlansListView()
    }
}
