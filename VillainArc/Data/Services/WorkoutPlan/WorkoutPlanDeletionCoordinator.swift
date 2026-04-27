import Foundation
import SwiftData

@MainActor
enum WorkoutPlanDeletionCoordinator {
    struct Assessment {
        enum Risk {
            case activeEditing
            case activeWorkout
        }

        let plans: [WorkoutPlan]
        let risk: Risk?

        var requiresWarning: Bool { risk != nil }

        var confirmationTitle: String {
            plans.count == 1 ? "Delete Workout Plan?" : "Delete All Workout Plans?"
        }

        var confirmationMessage: String {
            switch risk {
            case .activeEditing:
                if plans.count == 1 {
                    return "You're currently editing this workout plan. Deleting it will close the editor and discard the editing copy."
                }
                return "One of these workout plans is currently being edited. Deleting them will close the editor and discard its editing copy."
            case .activeWorkout:
                if plans.count == 1 {
                    return "An active workout was started from this workout plan. Deleting it will turn that live workout into a standalone workout and clear copied plan targets."
                }
                return "An active workout was started from one of these workout plans. Deleting them will turn that live workout into a standalone workout and clear copied plan targets."
            case nil:
                if plans.count == 1 {
                    return "Are you sure you want to delete this workout plan?"
                }
                return "Are you sure you want to delete all workout plans?"
            }
        }

        var destructiveButtonTitle: String {
            plans.count == 1 ? "Delete" : "Delete All"
        }

        var resultDialogText: String {
            if plans.count == 1 {
                return "Workout plan deleted."
            }
            let count = plans.count
            let label = count == 1 ? "1 workout plan" : "\(count) workout plans"
            return "Deleted \(label)."
        }
    }

    static func assess(plans: [WorkoutPlan], context: ModelContext, router: AppRouter = .shared) -> Assessment {
        let uniquePlans = unique(plans)
        let planIDs = Set(uniquePlans.map(\.id))

        if let originalPlan = router.activeWorkoutPlanOriginal, planIDs.contains(originalPlan.id) {
            return Assessment(plans: uniquePlans, risk: .activeEditing)
        }

        if let liveSession = try? context.fetch(WorkoutSession.incomplete).first,
           let livePlanID = liveSession.workoutPlan?.id,
           planIDs.contains(livePlanID) {
            return Assessment(plans: uniquePlans, risk: .activeWorkout)
        }

        return Assessment(plans: uniquePlans, risk: nil)
    }

    static func delete(_ assessment: Assessment, context: ModelContext, router: AppRouter = .shared) {
        let plans = unique(assessment.plans)
        guard !plans.isEmpty else { return }

        let planIDs = Set(plans.map(\.id))
        let linkedSplits = uniqueLinkedSplits(for: plans)

        if let liveSession = try? context.fetch(WorkoutSession.incomplete).first,
           let livePlanID = liveSession.workoutPlan?.id,
           planIDs.contains(livePlanID) {
            liveSession.detachFromDeletedWorkoutPlan()
            saveContext(context: context)
            if router.activeWorkoutSession?.id == liveSession.id, liveSession.statusValue == .active {
                router.activatePendingWorkoutSession(liveSession)
            }
        }

        if let originalPlan = router.activeWorkoutPlanOriginal,
           planIDs.contains(originalPlan.id),
           let editingCopy = router.activeWorkoutPlan,
           editingCopy.isEditing {
            let shouldDeferDeletionUntilEditorDismisses = router.isWorkoutPlanCoverPresented
            let existingCleanup = router.pendingWorkoutPlanDismissCleanup
            let deletePlansAndEditingCopy = {
                existingCleanup?()
                context.delete(editingCopy)
                deletePlans(plans, linkedSplits: linkedSplits, context: context)
            }

            if shouldDeferDeletionUntilEditorDismisses {
                router.pendingWorkoutPlanDismissCleanup = deletePlansAndEditingCopy
                router.activeWorkoutPlan = nil
                return
            }

            deletePlansAndEditingCopy()
            router.activeWorkoutPlan = nil
            return
        }

        deletePlans(plans, linkedSplits: linkedSplits, context: context)
    }

    private static func deletePlans(_ plans: [WorkoutPlan], linkedSplits: [WorkoutSplit], context: ModelContext) {
        SpotlightIndexer.deleteWorkoutPlans(ids: plans.map(\.id))
        for plan in plans {
            plan.deleteWithSuggestionCleanup(context: context)
        }
        saveContext(context: context)
        SpotlightIndexer.index(workoutSplits: linkedSplits)
    }

    private static func unique(_ plans: [WorkoutPlan]) -> [WorkoutPlan] {
        var seen = Set<UUID>()
        var result: [WorkoutPlan] = []
        for plan in plans where !seen.contains(plan.id) {
            seen.insert(plan.id)
            result.append(plan)
        }
        return result
    }

    private static func uniqueLinkedSplits(for plans: [WorkoutPlan]) -> [WorkoutSplit] {
        var seen = Set<UUID>()
        var result: [WorkoutSplit] = []
        for split in plans.flatMap(SpotlightIndexer.linkedWorkoutSplits(for:)) where !seen.contains(split.id) {
            seen.insert(split.id)
            result.append(split)
        }
        return result
    }
}
