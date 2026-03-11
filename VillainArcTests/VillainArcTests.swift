import SwiftData
import Foundation
import Testing
@testable import VillainArc

struct VillainArcTests {

    @MainActor
    private func finishEditing(_ editCopy: WorkoutPlan, originalPlan: WorkoutPlan, context: ModelContext) {
        originalPlan.applyEditingCopy(editCopy, context: context)
        context.delete(editCopy)
        try? context.save()
    }

    @Test @MainActor
    // Editing a set updates the plan and only matching rule suggestions are overridden.
    func userEditsOverrideMatchingRuleSuggestions() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        let data = makePlanWithRuleSuggestions(in: context)

        let editCopy = data.plan.createEditingCopy(context: context)
        let copyBench = (editCopy.exercises ?? []).first { $0.id == data.bench.id }
        #expect(copyBench != nil)
        guard let copyBench else { return }

        let copySet1 = (copyBench.sets ?? []).first { $0.id == data.benchSet1.id }
        #expect(copySet1 != nil)
        guard let copySet1 else { return }

        copySet1.targetWeight = 140
        finishEditing(editCopy, originalPlan: data.plan, context: context)

        #expect(data.benchSet1.targetWeight == 140)

        let weightRuleChange = data.changes.first {
            $0.changeType == .increaseWeight &&
            $0.targetSetPrescription?.id == data.benchSet1.id
        }
        #expect(weightRuleChange != nil)
        #expect(weightRuleChange?.decision == .userOverride)
        #expect(weightRuleChange?.outcome == .userModified)

        let repsRuleChange = data.changes.first {
            $0.changeType == .decreaseReps &&
            $0.targetSetPrescription?.id == data.benchSet1.id
        }
        #expect(repsRuleChange != nil)
        #expect(repsRuleChange?.decision == .pending)
        #expect(repsRuleChange?.outcome == .pending)

        let descriptor = FetchDescriptor<PrescriptionChange>()
        let allChanges = (try? context.fetch(descriptor)) ?? []
        #expect(allChanges.contains { $0.source == .user } == false)
    }

    @Test @MainActor
    // Deleting a set removes unresolved changes tied to that set.
    func deletingSetDeletesPendingChangesForRemovedSet() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        let data = makePlanWithRuleSuggestions(in: context)

        let editCopy = data.plan.createEditingCopy(context: context)
        let copyBench = (editCopy.exercises ?? []).first { $0.id == data.bench.id }
        #expect(copyBench != nil)
        guard let copyBench else { return }

        let copySet2 = (copyBench.sets ?? []).first { $0.id == data.benchSet2.id }
        #expect(copySet2 != nil)
        guard let copySet2 else { return }

        copyBench.deleteSet(copySet2)
        finishEditing(editCopy, originalPlan: data.plan, context: context)

        #expect((data.bench.sets ?? []).contains { $0.id == data.benchSet2.id } == false)

        let ruleChangeForSet2 = data.changes.first {
            $0.changeType == .increaseWeight &&
            $0.previousValue == 155 &&
            $0.targetExercisePrescription?.id == data.bench.id
        }
        #expect(ruleChangeForSet2 != nil)

        let remainingChanges = (try? context.fetch(FetchDescriptor<PrescriptionChange>())) ?? []
        #expect(remainingChanges.contains { $0.id == ruleChangeForSet2?.id } == false)
    }

    @Test @MainActor
    // Deleting a set should keep resolved history, but the deleted set link should nullify.
    func deletingSetPreservesResolvedHistoryForRemovedSet() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        let data = makePlanWithRuleSuggestions(in: context)

        let resolvedChange = PrescriptionChange(
            source: .rules,
            catalogID: data.bench.catalogID,
            targetExercisePrescription: data.bench,
            targetSetPrescription: data.benchSet2,
            targetPlan: data.plan,
            changeType: .increaseWeight,
            previousValue: 155,
            newValue: 160,
            decision: .accepted,
            outcome: .good,
            evaluatedAt: Date()
        )
        context.insert(resolvedChange)

        let editCopy = data.plan.createEditingCopy(context: context)
        let copyBench = (editCopy.exercises ?? []).first { $0.id == data.bench.id }
        #expect(copyBench != nil)
        guard let copyBench else { return }

        let copySet2 = (copyBench.sets ?? []).first { $0.id == data.benchSet2.id }
        #expect(copySet2 != nil)
        guard let copySet2 else { return }

        copyBench.deleteSet(copySet2)
        finishEditing(editCopy, originalPlan: data.plan, context: context)

        let remainingChanges = (try? context.fetch(FetchDescriptor<PrescriptionChange>())) ?? []
        let survivingResolvedChange = remainingChanges.first { $0.id == resolvedChange.id }
        #expect(survivingResolvedChange != nil)
        #expect(survivingResolvedChange?.targetSetPrescription == nil)
        #expect(survivingResolvedChange?.targetExercisePrescription?.id == data.bench.id)
    }

    @Test @MainActor
    // A deferred weight suggestion is overridden when the user edits the same set weight.
    func userEditOverridesDeferredWeightSuggestion() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        let data = makePlanWithRuleSuggestions(in: context)

        let deferredDecrease = PrescriptionChange(source: .rules, catalogID: data.bench.catalogID, targetExercisePrescription: data.bench, targetSetPrescription: data.benchSet1, targetPlan: data.plan, changeType: .decreaseWeight, previousValue: 135, newValue: 125, decision: .deferred)
        context.insert(deferredDecrease)

        let editCopy = data.plan.createEditingCopy(context: context)
        let copyBench = (editCopy.exercises ?? []).first { $0.id == data.bench.id }
        #expect(copyBench != nil)
        guard let copyBench else { return }

        let copySet1 = (copyBench.sets ?? []).first { $0.id == data.benchSet1.id }
        #expect(copySet1 != nil)
        guard let copySet1 else { return }

        copySet1.targetWeight = 140
        finishEditing(editCopy, originalPlan: data.plan, context: context)

        #expect(data.benchSet1.targetWeight == 140)
        #expect(deferredDecrease.decision == .userOverride)
        #expect(deferredDecrease.outcome == .userModified)

        let descriptor = FetchDescriptor<PrescriptionChange>()
        let allChanges = (try? context.fetch(descriptor)) ?? []
        #expect(allChanges.contains { $0.source == .user } == false)
    }

    @Test @MainActor
    // Editing rep range should not touch pending set-change outcomes on the same exercise.
    func repRangeEditDoesNotOverridePendingSetChangeOutcome() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        let data = makePlanWithRuleSuggestions(in: context)

        let inclineSet = data.incline.sortedSets.first
        #expect(inclineSet != nil)
        guard let inclineSet else { return }

        let setChange = PrescriptionChange(source: .rules, catalogID: data.incline.catalogID, targetExercisePrescription: data.incline, targetSetPrescription: inclineSet, targetPlan: data.plan, changeType: .increaseReps, previousValue: Double(inclineSet.targetReps), newValue: Double(inclineSet.targetReps + 2), decision: .accepted)
        context.insert(setChange)

        let editCopy = data.plan.createEditingCopy(context: context)
        let copyIncline = (editCopy.exercises ?? []).first { $0.id == data.incline.id }
        #expect(copyIncline != nil)
        guard let copyIncline else { return }

        if let repRange = copyIncline.repRange {
            repRange.targetReps = repRange.targetReps + 2
        }
        finishEditing(editCopy, originalPlan: data.plan, context: context)

        #expect(setChange.decision == .accepted)
        #expect(setChange.outcome == .pending)
    }

    @Test @MainActor
    // Replacing an exercise deletes unresolved old-exercise changes but preserves resolved outcomes for learning.
    func replacingExerciseDeletesPendingOutcomeChangesForOriginalExercise() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        let data = makePlanWithRuleSuggestions(in: context)

        let resolvedChange = PrescriptionChange(
            source: .rules,
            catalogID: data.incline.catalogID,
            targetExercisePrescription: data.incline,
            targetPlan: data.plan,
            changeType: .increaseRepRangeTarget,
            previousValue: 8,
            newValue: 10,
            decision: .accepted,
            outcome: .good,
            evaluatedAt: Date()
        )
        context.insert(resolvedChange)

        let editCopy = data.plan.createEditingCopy(context: context)
        let copyIncline = (editCopy.exercises ?? []).first { $0.id == data.incline.id }
        #expect(copyIncline != nil)
        guard let copyIncline else { return }

        let replacement = Exercise(from: ExerciseCatalog.byID["barbell_shoulder_press"]!)
        copyIncline.replaceWith(replacement, keepSets: true)
        finishEditing(editCopy, originalPlan: data.plan, context: context)

        #expect(data.incline.catalogID == replacement.catalogID)

        let allChanges = (try? context.fetch(FetchDescriptor<PrescriptionChange>())) ?? []
        let remainingChangeIDs = Set(allChanges.map(\.id))

        let originalPendingChangeIDs = Set(
            data.changes
                .filter { $0.targetExercisePrescription?.id == data.incline.id && $0.outcome == .pending }
                .map(\.id)
        )

        for changeID in originalPendingChangeIDs {
            #expect(remainingChangeIDs.contains(changeID) == false)
        }

        #expect(remainingChangeIDs.contains(resolvedChange.id))
    }

    @Test @MainActor
    // Deleting an exercise removes unresolved changes but preserves resolved history.
    func deletingExerciseDeletesPendingChangesWithoutNewUserChange() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        let data = makePlanWithRuleSuggestions(in: context)

        let flysRuleChange = data.changes.first { $0.targetExercisePrescription?.id == data.flys.id }
        #expect(flysRuleChange != nil)
        guard let flysRuleChange else { return }
        flysRuleChange.decision = .deferred

        let flysSet = data.flys.sortedSets.first
        #expect(flysSet != nil)
        guard let flysSet else { return }
        let pendingAcceptedChange = PrescriptionChange(source: .rules, catalogID: data.flys.catalogID, targetExercisePrescription: data.flys, targetSetPrescription: flysSet, targetPlan: data.plan, changeType: .increaseRest, previousValue: Double(flysSet.targetRest), newValue: Double(flysSet.targetRest + 15), decision: .accepted)
        context.insert(pendingAcceptedChange)

        let resolvedChange = PrescriptionChange(source: .rules, catalogID: data.flys.catalogID, targetExercisePrescription: data.flys, targetSetPrescription: flysSet, targetPlan: data.plan, changeType: .increaseWeight, previousValue: 40, newValue: 45, decision: .accepted, outcome: .good, evaluatedAt: Date())
        context.insert(resolvedChange)

        let editCopy = data.plan.createEditingCopy(context: context)
        let copyFlys = (editCopy.exercises ?? []).first { $0.id == data.flys.id }
        #expect(copyFlys != nil)
        guard let copyFlys else { return }

        editCopy.deleteExercise(copyFlys)
        finishEditing(editCopy, originalPlan: data.plan, context: context)

        let descriptor = FetchDescriptor<PrescriptionChange>()
        let allChanges = (try? context.fetch(descriptor)) ?? []
        #expect(allChanges.contains { $0.id == flysRuleChange.id } == false)
        #expect(allChanges.contains { $0.id == pendingAcceptedChange.id } == false)
        #expect(allChanges.contains { $0.id == resolvedChange.id })
        let userChanges = allChanges.filter { $0.source == .user }
        #expect(userChanges.isEmpty)
    }

    @Test @MainActor
    // Adding an exercise updates the original plan without creating change records.
    func addingExerciseAppliesToOriginalWithoutCreatingChanges() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        let data = makePlanWithRuleSuggestions(in: context)

        let initialChanges = (try? context.fetch(FetchDescriptor<PrescriptionChange>())) ?? []

        let editCopy = data.plan.createEditingCopy(context: context)
        let newExercise = Exercise(from: ExerciseCatalog.byID["barbell_squat"]!)
        editCopy.addExercise(newExercise)
        finishEditing(editCopy, originalPlan: data.plan, context: context)

        #expect((data.plan.exercises ?? []).contains { $0.catalogID == newExercise.catalogID })

        let allChanges = (try? context.fetch(FetchDescriptor<PrescriptionChange>())) ?? []
        #expect(allChanges.count == initialChanges.count)
        let userChanges = allChanges.filter { $0.source == .user }
        #expect(userChanges.isEmpty)
    }

    @Test @MainActor
    // Removing an exercise updates the original plan and deletes that exercise's unresolved changes.
    func removingExerciseAppliesToOriginalWithoutCreatingChanges() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        let data = makePlanWithRuleSuggestions(in: context)

        let initialChanges = (try? context.fetch(FetchDescriptor<PrescriptionChange>())) ?? []
        let pendingFlysChangeCount = initialChanges.filter { $0.targetExercisePrescription?.id == data.flys.id && $0.outcome == .pending }.count

        let editCopy = data.plan.createEditingCopy(context: context)
        let copyFlys = (editCopy.exercises ?? []).first { $0.id == data.flys.id }
        #expect(copyFlys != nil)
        guard let copyFlys else { return }

        editCopy.deleteExercise(copyFlys)
        finishEditing(editCopy, originalPlan: data.plan, context: context)

        #expect((data.plan.exercises ?? []).contains { $0.id == data.flys.id } == false)

        let allChanges = (try? context.fetch(FetchDescriptor<PrescriptionChange>())) ?? []
        #expect(allChanges.count == initialChanges.count - pendingFlysChangeCount)
        let userChanges = allChanges.filter { $0.source == .user }
        #expect(userChanges.isEmpty)
    }

    @Test @MainActor
    // Moving exercises updates indices/order without creating change records.
    func movingExercisesUpdatesOrderWithoutCreatingChanges() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        let data = makePlanWithRuleSuggestions(in: context)

        let initialChanges = (try? context.fetch(FetchDescriptor<PrescriptionChange>())) ?? []

        let editCopy = data.plan.createEditingCopy(context: context)
        let count = (editCopy.exercises ?? []).count
        #expect(count >= 3)
        if count < 3 { return }

        editCopy.moveExercise(from: IndexSet(integer: 0), to: count)
        let expectedOrder = editCopy.sortedExercises.map(\.id)

        finishEditing(editCopy, originalPlan: data.plan, context: context)

        let newOrder = data.plan.sortedExercises.map(\.id)
        #expect(newOrder == expectedOrder)

        let allChanges = (try? context.fetch(FetchDescriptor<PrescriptionChange>())) ?? []
        #expect(allChanges.count == initialChanges.count)
        let userChanges = allChanges.filter { $0.source == .user }
        #expect(userChanges.isEmpty)
    }

    @Test @MainActor
    // Deleting a plan removes unresolved changes but preserves resolved history.
    func deletingPlanDeletesOnlyPendingLinkedChanges() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        let data = makePlanWithRuleSuggestions(in: context)

        let resolvedChange = PrescriptionChange(
            source: .rules,
            catalogID: data.bench.catalogID,
            targetExercisePrescription: data.bench,
            targetSetPrescription: data.benchSet1,
            targetPlan: data.plan,
            changeType: .increaseWeight,
            previousValue: 135,
            newValue: 140,
            decision: .accepted,
            outcome: .good,
            evaluatedAt: Date()
        )
        context.insert(resolvedChange)

        data.plan.deleteWithSuggestionCleanup(context: context)
        try context.save()

        let remainingChanges = try context.fetch(FetchDescriptor<PrescriptionChange>())
        #expect(remainingChanges.count == 1)
        #expect(remainingChanges.first?.id == resolvedChange.id)
    }

    @Test @MainActor
    // Plan-level unresolved changes are deleted while resolved plan-level history remains.
    func deletingPlanDeletesOnlyPendingTargetPlanChanges() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        let data = makePlanWithRuleSuggestions(in: context)

        let planLevelChange = PrescriptionChange(
            source: .rules,
            catalogID: data.bench.catalogID,
            targetPlan: data.plan,
            changeType: .increaseWeight,
            previousValue: 135,
            newValue: 140,
            decision: .deferred
        )
        context.insert(planLevelChange)

        let resolvedPlanLevelChange = PrescriptionChange(
            source: .rules,
            catalogID: data.bench.catalogID,
            targetPlan: data.plan,
            changeType: .increaseRest,
            previousValue: 90,
            newValue: 105,
            decision: .accepted,
            outcome: .good,
            evaluatedAt: Date()
        )
        context.insert(resolvedPlanLevelChange)

        data.plan.deleteWithSuggestionCleanup(context: context)
        try context.save()

        let remainingChanges = try context.fetch(FetchDescriptor<PrescriptionChange>())
        #expect(remainingChanges.contains { $0.id == planLevelChange.id } == false)
        #expect(remainingChanges.contains { $0.id == resolvedPlanLevelChange.id })
    }

    @Test @MainActor
    // Deleting a source performance preserves prescription changes and nullifies the source link.
    func deletingExercisePerformancePreservesSourceChanges() throws {
        let context = try TestDataFactory.makeContext()
        let (_, prescription) = TestDataFactory.makePrescription(context: context)
        let session = TestDataFactory.makeSession(context: context)
        let performance = TestDataFactory.makePerformance(context: context, session: session, prescription: prescription, sets: [
            (weight: 135, reps: 8, rest: 90, type: .working)
        ])

        let setPerformance = performance.sortedSets.first
        let setPrescription = prescription.sortedSets.first
        #expect(setPerformance != nil)
        #expect(setPrescription != nil)
        guard let setPerformance, let setPrescription else { return }

        let change = PrescriptionChange(
            source: .rules,
            catalogID: prescription.catalogID,
            sourceExercisePerformance: performance,
            sourceSetPerformance: setPerformance,
            targetExercisePrescription: prescription,
            targetSetPrescription: setPrescription,
            changeType: .increaseWeight,
            previousValue: 135,
            newValue: 140
        )
        context.insert(change)

        context.delete(performance)
        saveContext(context: context)

        let remainingChanges = (try? context.fetch(FetchDescriptor<PrescriptionChange>())) ?? []
        let survivingChange = remainingChanges.first { $0.id == change.id }
        #expect(survivingChange != nil)
        #expect(survivingChange?.sourceExercisePerformance == nil)
        #expect(survivingChange?.sourceSetPerformance == nil)
    }
}
