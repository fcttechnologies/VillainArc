import SwiftData
import Foundation
import Testing
@testable import VillainArc

struct VillainArcTests {

    @Test @MainActor
    // Editing a set creates a user change while only matching rule suggestions are overridden.
    func userEditsCreatePendingUserChangeAndOverrideRuleSuggestions() throws {
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
        editCopy.finishEditing(context: context)

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
        let userChange = allChanges.first {
            $0.source == .user &&
            $0.targetSetPrescription?.id == data.benchSet1.id &&
            ($0.changeType == .increaseWeight || $0.changeType == .decreaseWeight)
        }

        #expect(userChange != nil)
        #expect(userChange?.decision == .accepted)
        #expect(userChange?.outcome == .pending)
    }

    @Test @MainActor
    // Deleting a set marks its pending rule suggestions as user overrides.
    func deletingSetMarksRuleSuggestionsAsUserOverride() throws {
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
        editCopy.finishEditing(context: context)

        #expect((data.bench.sets ?? []).contains { $0.id == data.benchSet2.id } == false)

        let ruleChangeForSet2 = data.changes.first {
            $0.changeType == .increaseWeight &&
            $0.previousValue == 155 &&
            $0.targetExercisePrescription?.id == data.bench.id
        }
        #expect(ruleChangeForSet2 != nil)
        #expect(ruleChangeForSet2?.decision == .userOverride)
        #expect(ruleChangeForSet2?.outcome == .userModified)
    }

    @Test @MainActor
    // A deferred weight suggestion is overridden when the user edits the same set weight.
    func userEditOverridesDeferredWeightSuggestionAndAddsUserChange() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        let data = makePlanWithRuleSuggestions(in: context)

        let deferredDecrease = PrescriptionChange(source: .rules, catalogID: data.bench.catalogID, targetExercisePrescription: data.bench, targetSetPrescription: data.benchSet1, changeType: .decreaseWeight, previousValue: 135, newValue: 125, decision: .deferred)
        context.insert(deferredDecrease)

        let editCopy = data.plan.createEditingCopy(context: context)
        let copyBench = (editCopy.exercises ?? []).first { $0.id == data.bench.id }
        #expect(copyBench != nil)
        guard let copyBench else { return }

        let copySet1 = (copyBench.sets ?? []).first { $0.id == data.benchSet1.id }
        #expect(copySet1 != nil)
        guard let copySet1 else { return }

        copySet1.targetWeight = 140
        editCopy.finishEditing(context: context)

        #expect(deferredDecrease.decision == .userOverride)
        #expect(deferredDecrease.outcome == .userModified)

        let descriptor = FetchDescriptor<PrescriptionChange>()
        let allChanges = (try? context.fetch(descriptor)) ?? []
        let userChange = allChanges.first {
            $0.source == .user &&
            $0.targetSetPrescription?.id == data.benchSet1.id &&
            ($0.changeType == .increaseWeight || $0.changeType == .decreaseWeight)
        }

        #expect(userChange != nil)
        #expect(userChange?.decision == .accepted)
        #expect(userChange?.outcome == .pending)
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

        let setChange = PrescriptionChange(source: .rules, catalogID: data.incline.catalogID, targetExercisePrescription: data.incline, targetSetPrescription: inclineSet, changeType: .increaseReps, previousValue: Double(inclineSet.targetReps), newValue: Double(inclineSet.targetReps + 2), decision: .accepted)
        context.insert(setChange)

        let editCopy = data.plan.createEditingCopy(context: context)
        let copyIncline = (editCopy.exercises ?? []).first { $0.id == data.incline.id }
        #expect(copyIncline != nil)
        guard let copyIncline else { return }

        if let repRange = copyIncline.repRange {
            repRange.targetReps = repRange.targetReps + 2
        }
        editCopy.finishEditing(context: context)

        #expect(setChange.decision == .accepted)
        #expect(setChange.outcome == .pending)
    }

    @Test @MainActor
    // Deleting an exercise overrides pending changes without creating a new user change.
    func deletingExerciseOverridesPendingChangesWithoutNewUserChange() throws {
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
        let acceptedChange = PrescriptionChange(source: .rules, catalogID: data.flys.catalogID, targetExercisePrescription: data.flys, targetSetPrescription: flysSet, changeType: .increaseRest, previousValue: Double(flysSet.targetRest), newValue: Double(flysSet.targetRest + 15), decision: .accepted)
        context.insert(acceptedChange)

        let editCopy = data.plan.createEditingCopy(context: context)
        let copyFlys = (editCopy.exercises ?? []).first { $0.id == data.flys.id }
        #expect(copyFlys != nil)
        guard let copyFlys else { return }

        editCopy.deleteExercise(copyFlys)
        editCopy.finishEditing(context: context)

        #expect(flysRuleChange.decision == .userOverride)
        #expect(flysRuleChange.outcome == .userModified)
        #expect(acceptedChange.decision == .accepted)
        #expect(acceptedChange.outcome == .userModified)

        let descriptor = FetchDescriptor<PrescriptionChange>()
        let allChanges = (try? context.fetch(descriptor)) ?? []
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
        editCopy.finishEditing(context: context)

        #expect((data.plan.exercises ?? []).contains { $0.catalogID == newExercise.catalogID })

        let allChanges = (try? context.fetch(FetchDescriptor<PrescriptionChange>())) ?? []
        #expect(allChanges.count == initialChanges.count)
        let userChanges = allChanges.filter { $0.source == .user }
        #expect(userChanges.isEmpty)
    }

    @Test @MainActor
    // Removing an exercise updates the original plan without creating change records.
    func removingExerciseAppliesToOriginalWithoutCreatingChanges() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        let data = makePlanWithRuleSuggestions(in: context)

        let initialChanges = (try? context.fetch(FetchDescriptor<PrescriptionChange>())) ?? []

        let editCopy = data.plan.createEditingCopy(context: context)
        let copyFlys = (editCopy.exercises ?? []).first { $0.id == data.flys.id }
        #expect(copyFlys != nil)
        guard let copyFlys else { return }

        editCopy.deleteExercise(copyFlys)
        editCopy.finishEditing(context: context)

        #expect((data.plan.exercises ?? []).contains { $0.id == data.flys.id } == false)

        let allChanges = (try? context.fetch(FetchDescriptor<PrescriptionChange>())) ?? []
        #expect(allChanges.count == initialChanges.count)
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

        editCopy.finishEditing(context: context)

        let newOrder = data.plan.sortedExercises.map(\.id)
        #expect(newOrder == expectedOrder)

        let allChanges = (try? context.fetch(FetchDescriptor<PrescriptionChange>())) ?? []
        #expect(allChanges.count == initialChanges.count)
        let userChanges = allChanges.filter { $0.source == .user }
        #expect(userChanges.isEmpty)
    }

    @Test @MainActor
    // Deleting a plan marks unresolved linked suggestions as overridden instead of leaving them pending.
    func deletingPlanMarksPendingAndDeferredLinkedChangesAsUserModified() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        let data = makePlanWithRuleSuggestions(in: context)

        let pendingSetChange = data.changes.first {
            $0.changeType == .increaseWeight &&
            $0.targetSetPrescription?.id == data.benchSet1.id
        }
        let deferredExerciseChange = data.changes.first {
            $0.changeType == .changeRepRangeMode &&
            $0.targetExercisePrescription?.id == data.incline.id
        }
        let acceptedChange = data.changes.first {
            $0.changeType == .increaseRest &&
            $0.targetSetPrescription?.id == data.flys.sortedSets.first?.id
        }

        #expect(pendingSetChange != nil)
        #expect(deferredExerciseChange != nil)
        #expect(acceptedChange != nil)
        guard let pendingSetChange, let deferredExerciseChange, let acceptedChange else { return }

        deferredExerciseChange.decision = .deferred
        acceptedChange.decision = .accepted

        data.plan.deleteWithSuggestionCleanup(context: context)

        #expect(pendingSetChange.decision == .userOverride)
        #expect(pendingSetChange.outcome == .userModified)
        #expect(deferredExerciseChange.decision == .userOverride)
        #expect(deferredExerciseChange.outcome == .userModified)
        #expect(acceptedChange.decision == .accepted)
        #expect(acceptedChange.outcome == .userModified)
    }

    @Test @MainActor
    // Plan-level targeted changes should also be invalidated when the plan is deleted.
    func deletingPlanMarksTargetPlanOnlyChangesAsUserModified() throws {
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

        data.plan.deleteWithSuggestionCleanup(context: context)

        #expect(planLevelChange.decision == .userOverride)
        #expect(planLevelChange.outcome == .userModified)
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
