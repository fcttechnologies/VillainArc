import SwiftUI
import SwiftData

struct WorkoutPlanRowView: View {
    @Environment(\.modelContext) private var context
    let workoutPlan: WorkoutPlan
    var showsUseOnly: Bool = false
    private let appRouter = AppRouter.shared
    @State private var deletionAssessment: WorkoutPlanDeletionCoordinator.Assessment?
    
    var body: some View {
        Button {
            appRouter.push(to: .workoutPlanDetail(workoutPlan, showsUseOnly))
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
        .alert(deletionAssessment?.confirmationTitle ?? "Delete Workout Plan?", isPresented: deletionAlertBinding) {
            Button(deletionAssessment?.destructiveButtonTitle ?? "Delete", role: .destructive) {
                guard let deletionAssessment else { return }
                performDelete(using: deletionAssessment)
            }
            Button("Cancel", role: .cancel) {
                deletionAssessment = nil
            }
        } message: {
            Text(deletionAssessment?.confirmationMessage ?? "")
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
        let assessment = WorkoutPlanDeletionCoordinator.assess(plans: [workoutPlan], context: context)
        if assessment.requiresWarning {
            deletionAssessment = assessment
            return
        }
        performDelete(using: assessment)
    }

    private func performDelete(using assessment: WorkoutPlanDeletionCoordinator.Assessment) {
        deletionAssessment = nil
        let deletedPlan = workoutPlan
        WorkoutPlanDeletionCoordinator.delete(assessment, context: context)
        Task { await IntentDonations.donateDeleteWorkoutPlan(workoutPlan: deletedPlan) }
    }

    private var deletionAlertBinding: Binding<Bool> {
        Binding(
            get: { deletionAssessment != nil },
            set: { isPresented in
                if !isPresented {
                    deletionAssessment = nil
                }
            }
        )
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        WorkoutPlanRowView(workoutPlan: sampleCompletedPlan())
    }
}
