import SwiftUI
import SwiftData

struct WorkoutPlanRowView: View {
    @Environment(\.modelContext) private var context
    let workoutPlan: WorkoutPlan
    var showsUseOnly: Bool = false
    private let appRouter = AppRouter.shared
    
    var body: some View {
        Button {
            appRouter.navigate(to: .workoutPlanDetail(workoutPlan, showsUseOnly))
            Task { await IntentDonations.donateOpenWorkoutPlan(workoutPlan: workoutPlan) }
        } label: {
            WorkoutPlanCardView(workoutPlan: workoutPlan)
        }
        .buttonStyle(.borderless)
        .contextMenu {
            Button(workoutPlan.favorite ? "Undo Favorite" : "Favorite", systemImage: workoutPlan.favorite ? "star.slash.fill" : "star.fill") {
                toggleFavorite()
            }
            .tint(.yellow)

            Button("Delete Workout Plan", systemImage: "trash", role: .destructive) {
                deleteWorkoutPlan()
            }
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanRow(workoutPlan))
    }

    private func toggleFavorite() {
        Haptics.selection()
        workoutPlan.favorite.toggle()
        saveContext(context: context)
        Task { await IntentDonations.donateToggleWorkoutPlanFavorite(workoutPlan: workoutPlan) }
    }

    private func deleteWorkoutPlan() {
        Haptics.selection()
        let deletedPlan = workoutPlan
        let linkedSplits = SpotlightIndexer.linkedWorkoutSplits(for: workoutPlan)
        SpotlightIndexer.deleteWorkoutPlan(id: workoutPlan.id)
        workoutPlan.deleteWithSuggestionCleanup(context: context)
        saveContext(context: context)
        SpotlightIndexer.index(workoutSplits: linkedSplits)
        Task { await IntentDonations.donateDeleteWorkoutPlan(workoutPlan: deletedPlan) }
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        WorkoutPlanRowView(workoutPlan: sampleCompletedPlan())
    }
}
