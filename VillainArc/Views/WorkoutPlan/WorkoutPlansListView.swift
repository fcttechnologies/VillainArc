import SwiftUI
import SwiftData

struct WorkoutPlansListView: View {
    @Environment(\.modelContext) private var context
    @Query(WorkoutPlan.all) private var workoutPlans: [WorkoutPlan]
    
    @State private var showDeleteAllConfirmation = false
    @State private var isEditing = false
    @State private var favoritesOnly = false
    @State private var previousFavoritesState = false
    
    private var editModeBinding: Binding<EditMode> {
        Binding(
            get: { isEditing ? .active : .inactive },
            set: { newValue in
                isEditing = newValue == .active
            }
        )
    }
    
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
                    .accessibilityHint("Shows workout plan details.")
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button(plan.favorite ? "Undo" : "Favorite", systemImage: plan.favorite ? "star.slash.fill" : "star.fill") {
                            plan.favorite.toggle()
                            saveContext(context: context)
                        }
                        .tint(.yellow)
                    }
            }
            .onDelete(perform: deleteWorkoutPlan)
        }
        .accessibilityIdentifier("workoutPlansList")
        .environment(\.editMode, editModeBinding)
        .animation(.smooth, value: isEditing)
        .navigationTitle("Workout Plans")
        .toolbarTitleDisplayMode(.inline)
        .listStyle(.plain)
        .navigationBarBackButtonHidden(isEditing)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if isEditing {
                    Button("Delete All", systemImage: "trash", role: .destructive) {
                        showDeleteAllConfirmation = true
                    }
                    .tint(.red)
                    .labelStyle(.titleOnly)
                    .accessibilityIdentifier("workoutPlansDeleteAllButton")
                    .accessibilityHint("Deletes all workout plans.")
                    .confirmationDialog("Delete All Workout Plans?", isPresented: $showDeleteAllConfirmation) {
                        Button("Delete All", role: .destructive) {
                            deleteAllWorkoutPlans()
                        }
                    } message: {
                        Text("Are you sure you want to delete all workout plans?")
                    }
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
                        .accessibilityIdentifier("workoutPlansDoneEditingButton")
                        .accessibilityHint("Exits edit mode.")
                    } else {
                        Menu("Options", systemImage: "ellipsis") {
                            Toggle("Favorites", systemImage: "star", isOn: $favoritesOnly)
                            Button("Edit", systemImage: "pencil") {
                                previousFavoritesState = favoritesOnly
                                favoritesOnly = false
                                isEditing = true
                            }
                            .accessibilityIdentifier("workoutPlansEditButton")
                            .accessibilityHint("Enters edit mode.")
                        }
                        .accessibilityIdentifier("workoutPlansOptionsMenu")
                        .accessibilityHint("Workout Plans list options.")
                    }
                }
            }
        }
        .overlay(alignment: .center) {
            if workoutPlans.isEmpty {
                ContentUnavailableView("No Workout Plans", systemImage: "list.clipboard", description: Text("Your created workout plans will appear here."))
                    .accessibilityIdentifier("workoutPlansEmptyState")
            } else if favoritesOnly && workoutPlans.isEmpty {
                ContentUnavailableView("No Favorites", systemImage: "star.slash", description: Text("Mark workout plans as favorite to see them here."))
                    .accessibilityIdentifier("workoutPlansNoFavoritesState")
            }
        }
    }
    
    private func deleteWorkoutPlan(offsets: IndexSet) {
        guard !offsets.isEmpty else { return }
        Haptics.selection()
        let workoutPlansToDelete = offsets.map { filteredWorkoutPlans[$0] }
        SpotlightIndexer.deleteWorkoutPlans(ids: workoutPlansToDelete.map(\.id))
        for plan in workoutPlansToDelete {
            context.delete(plan)
        }
        saveContext(context: context)
        if workoutPlans.isEmpty {
            isEditing = false
            favoritesOnly = false
        }
    }

    private func deleteAllWorkoutPlans() {
        Haptics.selection()
        SpotlightIndexer.deleteWorkoutPlans(ids: workoutPlans.map(\.id))
        for plan in workoutPlans {
            context.delete(plan)
        }
        saveContext(context: context)
        isEditing = false
        favoritesOnly = false
    }
}

#Preview {
    NavigationStack {
        WorkoutPlansListView()
    }
    .sampleDataContainer()
}
