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
    
    @MainActor
    @discardableResult
    private func insertSuggestionEvent(for exercise: ExercisePrescription, changes: [PrescriptionChange], in context: ModelContext, decision: Decision = .pending, outcome: Outcome = .pending, evaluatedAt: Date? = nil, targetSet: SetPrescription? = nil, category: SuggestionCategory = .performance) -> SuggestionEvent {
        let event = SuggestionEvent(category: category, catalogID: exercise.catalogID, sessionFrom: nil, targetExercisePrescription: exercise, targetSetPrescription: targetSet, targetSetIndex: targetSet?.index, decision: decision, outcome: outcome, triggerPerformanceSnapshot: ExercisePerformanceSnapshot(notes: "", repRange: RepRangeSnapshot(policy: exercise.repRange), sets: []), triggerTargetSnapshot: ExerciseTargetSnapshot(prescription: exercise), trainingStyle: .straightSets, evaluatedAt: evaluatedAt, changes: changes)
        context.insert(event)
        for change in changes {
            change.event = event
        }
        return event
    }
    
    @Test @MainActor
    // Editing a set updates the plan and deletes the unresolved grouped suggestion it conflicts with.
    func userEditsDeleteMatchingUnresolvedSuggestionEvent() throws {
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

        let weightRuleChangeID = data.changes.first {
            $0.changeType == .increaseWeight &&
            $0.event?.targetSetPrescription?.id == data.benchSet1.id
        }?.id
        let repsRuleChangeID = data.changes.first {
            $0.changeType == .decreaseReps &&
            $0.event?.targetSetPrescription?.id == data.benchSet1.id
        }?.id

        finishEditing(editCopy, originalPlan: data.plan, context: context)
        
        #expect(data.benchSet1.targetWeight == 140)
        #expect(weightRuleChangeID != nil)
        #expect(repsRuleChangeID != nil)
        
        let descriptor = FetchDescriptor<PrescriptionChange>()
        let allChanges = (try? context.fetch(descriptor)) ?? []
        #expect(allChanges.contains { $0.id == weightRuleChangeID } == false)
        #expect(allChanges.contains { $0.id == repsRuleChangeID } == false)
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
        
        let ruleChangeForSet2ID = data.changes.first {
            $0.changeType == .increaseWeight &&
            $0.previousValue == 155 &&
            $0.event?.targetExercisePrescription?.id == data.bench.id
        }?.id

        copyBench.deleteSet(copySet2)
        finishEditing(editCopy, originalPlan: data.plan, context: context)
        
        #expect((data.bench.sets ?? []).contains { $0.id == data.benchSet2.id } == false)
        #expect(ruleChangeForSet2ID != nil)
        
        let remainingChanges = (try? context.fetch(FetchDescriptor<PrescriptionChange>())) ?? []
        #expect(remainingChanges.contains { $0.id == ruleChangeForSet2ID } == false)
    }
    
    @Test @MainActor
    // Deleting a set should keep resolved history, but the deleted set link should nullify.
    func deletingSetPreservesResolvedHistoryForRemovedSet() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        let data = makePlanWithRuleSuggestions(in: context)
        
        let resolvedChange = PrescriptionChange(changeType: .increaseWeight, previousValue: 155, newValue: 160)
        context.insert(resolvedChange)
        let resolvedEvent = insertSuggestionEvent(for: data.bench, changes: [resolvedChange], in: context, decision: .accepted, outcome: .good, evaluatedAt: Date(), targetSet: data.benchSet2)
        
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
        #expect(resolvedEvent.targetSetPrescription == nil)
        #expect(resolvedEvent.targetExercisePrescription?.id == data.bench.id)
    }
    
    @Test @MainActor
    // A deferred weight suggestion is deleted when the user edits the same set weight.
    func userEditDeletesDeferredWeightSuggestion() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        let data = makePlanWithRuleSuggestions(in: context)
        
        let deferredDecrease = PrescriptionChange(changeType: .decreaseWeight, previousValue: 135, newValue: 125)
        context.insert(deferredDecrease)
        _ = insertSuggestionEvent(for: data.bench, changes: [deferredDecrease], in: context, decision: .deferred, targetSet: data.benchSet1)
        
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
        
        let descriptor = FetchDescriptor<PrescriptionChange>()
        let allChanges = (try? context.fetch(descriptor)) ?? []
        #expect(allChanges.contains { $0.id == deferredDecrease.id } == false)
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
        
        let setChange = PrescriptionChange(changeType: .increaseReps, previousValue: Double(inclineSet.targetReps), newValue: Double(inclineSet.targetReps + 2))
        context.insert(setChange)
        let setEvent = insertSuggestionEvent(for: data.incline, changes: [setChange], in: context, decision: .accepted, targetSet: inclineSet)
        
        let editCopy = data.plan.createEditingCopy(context: context)
        let copyIncline = (editCopy.exercises ?? []).first { $0.id == data.incline.id }
        #expect(copyIncline != nil)
        guard let copyIncline else { return }
        
        if let repRange = copyIncline.repRange {
            repRange.targetReps = repRange.targetReps + 2
        }
        finishEditing(editCopy, originalPlan: data.plan, context: context)
        
        #expect(setEvent.decision == .accepted)
        #expect(setEvent.outcome == .pending)
    }
    
    @Test @MainActor
    // Replacing an exercise deletes unresolved old-exercise changes but preserves resolved outcomes for learning.
    func replacingExerciseDeletesPendingOutcomeChangesForOriginalExercise() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        let data = makePlanWithRuleSuggestions(in: context)
        
        let resolvedChange = PrescriptionChange(changeType: .increaseRepRangeTarget, previousValue: 8, newValue: 10)
        context.insert(resolvedChange)
        _ = insertSuggestionEvent(for: data.incline, changes: [resolvedChange], in: context, decision: .accepted, outcome: .good, evaluatedAt: Date(), category: .repRangeConfiguration)
        
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
                .filter { $0.event?.targetExercisePrescription?.id == data.incline.id && $0.event?.outcome == .pending }
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
        
        let flysRuleChange = data.changes.first { $0.event?.targetExercisePrescription?.id == data.flys.id }
        #expect(flysRuleChange != nil)
        guard let flysRuleChange else { return }
        flysRuleChange.event?.decision = .deferred
        
        let flysSet = data.flys.sortedSets.first
        #expect(flysSet != nil)
        guard let flysSet else { return }
        let pendingAcceptedChange = PrescriptionChange(changeType: .increaseRest, previousValue: Double(flysSet.targetRest), newValue: Double(flysSet.targetRest + 15))
        context.insert(pendingAcceptedChange)
        _ = insertSuggestionEvent(for: data.flys, changes: [pendingAcceptedChange], in: context, decision: .accepted, targetSet: flysSet, category: .recovery)
        
        let resolvedChange = PrescriptionChange(changeType: .increaseWeight, previousValue: 40, newValue: 45)
        context.insert(resolvedChange)
        _ = insertSuggestionEvent(for: data.flys, changes: [resolvedChange], in: context, decision: .accepted, outcome: .good, evaluatedAt: Date(), targetSet: flysSet)
        
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
    }
    
    @Test @MainActor
    // Removing an exercise updates the original plan and deletes that exercise's unresolved changes.
    func removingExerciseAppliesToOriginalWithoutCreatingChanges() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        let data = makePlanWithRuleSuggestions(in: context)
        
        let initialChanges = (try? context.fetch(FetchDescriptor<PrescriptionChange>())) ?? []
        let pendingFlysChangeCount = initialChanges.filter { $0.event?.targetExercisePrescription?.id == data.flys.id && $0.event?.outcome == .pending }.count
        
        let editCopy = data.plan.createEditingCopy(context: context)
        let copyFlys = (editCopy.exercises ?? []).first { $0.id == data.flys.id }
        #expect(copyFlys != nil)
        guard let copyFlys else { return }
        
        editCopy.deleteExercise(copyFlys)
        finishEditing(editCopy, originalPlan: data.plan, context: context)
        
        #expect((data.plan.exercises ?? []).contains { $0.id == data.flys.id } == false)
        
        let allChanges = (try? context.fetch(FetchDescriptor<PrescriptionChange>())) ?? []
        #expect(allChanges.count == initialChanges.count - pendingFlysChangeCount)
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
    }
    
    @Test @MainActor
    // Deleting a plan removes unresolved changes but preserves resolved history.
    func deletingPlanDeletesOnlyPendingLinkedChanges() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        let data = makePlanWithRuleSuggestions(in: context)
        
        let resolvedChange = PrescriptionChange(changeType: .increaseWeight, previousValue: 135, newValue: 140)
        context.insert(resolvedChange)
        _ = insertSuggestionEvent(for: data.bench, changes: [resolvedChange], in: context, decision: .accepted, outcome: .good, evaluatedAt: Date(), targetSet: data.benchSet1)
        
        data.plan.deleteWithSuggestionCleanup(context: context)
        try context.save()
        
        let remainingChanges = try context.fetch(FetchDescriptor<PrescriptionChange>())
        #expect(remainingChanges.count == 1)
        #expect(remainingChanges.first?.id == resolvedChange.id)
    }
    
}
