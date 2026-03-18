import SwiftData
import Testing
import Foundation
@testable import VillainArc

struct WorkoutDeletionCoordinatorTests {
    @Test @MainActor
    func deleteCompletedWorkouts_retainsSnapshotsByHidingSession() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)

        let settings = AppSettings()
        settings.retainPerformancesForLearning = true
        context.insert(settings)

        let session = WorkoutSession(title: "Bench", status: .done)
        context.insert(session)

        let exercise = Exercise(from: ExerciseCatalog.byID["barbell_bench_press"]!)
        let performance = ExercisePerformance(exercise: exercise, workoutSession: session)
        context.insert(performance)
        session.exercises?.append(performance)

        let event = SuggestionEvent(
            catalogID: performance.catalogID,
            sessionFrom: session,
            triggerPerformance: performance,
            trainingStyle: .straightSets
        )
        context.insert(event)

        WorkoutDeletionCoordinator.deleteCompletedWorkouts([session], context: context, save: false)

        let remainingSessions = try context.fetch(WorkoutSession.byID(session.id))
        let remainingEvents = try context.fetch(FetchDescriptor<SuggestionEvent>())

        #expect(remainingSessions.count == 1)
        #expect(remainingSessions.first?.isHidden == true)
        #expect(remainingEvents.contains(where: { $0.id == event.id }))
    }

    @Test @MainActor
    func deleteCompletedWorkouts_hardDeletesSessionAndLearningArtifacts() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)

        let settings = AppSettings()
        settings.retainPerformancesForLearning = false
        context.insert(settings)

        let priorEvent = SuggestionEvent(catalogID: "barbell_bench_press", sessionFrom: nil, trainingStyle: .straightSets)
        context.insert(priorEvent)
        let finalizedExternalEvent = SuggestionEvent(catalogID: "barbell_bench_press", sessionFrom: nil, decision: .accepted, outcome: .good, trainingStyle: .straightSets, evaluatedAt: .now)
        context.insert(finalizedExternalEvent)

        let session = WorkoutSession(title: "Bench", status: .done)
        context.insert(session)

        let exercise = Exercise(from: ExerciseCatalog.byID["barbell_bench_press"]!)
        let performance = ExercisePerformance(exercise: exercise, workoutSession: session)
        context.insert(performance)
        session.exercises?.append(performance)

        let linkedChange = PrescriptionChange(changeType: .increaseWeight, previousValue: 100, newValue: 105)
        context.insert(linkedChange)
        let linkedEvent = SuggestionEvent(
            catalogID: performance.catalogID,
            sessionFrom: session,
            triggerPerformance: performance,
            trainingStyle: .straightSets,
            changes: [linkedChange]
        )
        context.insert(linkedEvent)

        let performanceLinkedEvent = SuggestionEvent(
            catalogID: performance.catalogID,
            sessionFrom: nil,
            triggerPerformance: performance,
            trainingStyle: .straightSets
        )
        context.insert(performanceLinkedEvent)

        let sourcedEvaluation = SuggestionEvaluation(
            event: priorEvent,
            performance: performance,
            sourceWorkoutSessionID: session.id,
            partialOutcome: .good,
            confidence: 0.8,
            reason: "Strong session"
        )
        context.insert(sourcedEvaluation)

        let finalizedSourcedEvaluation = SuggestionEvaluation(
            event: finalizedExternalEvent,
            performance: performance,
            sourceWorkoutSessionID: session.id,
            partialOutcome: .good,
            confidence: 0.9,
            reason: "Locked in"
        )
        context.insert(finalizedSourcedEvaluation)

        WorkoutDeletionCoordinator.deleteCompletedWorkouts([session], context: context, save: false)

        let remainingSessions = try context.fetch(WorkoutSession.byID(session.id))
        let remainingEvents = try context.fetch(FetchDescriptor<SuggestionEvent>())
        let remainingEvaluations = try context.fetch(SuggestionEvaluation.forSourceWorkoutSession(session.id))
        let remainingChanges = try context.fetch(FetchDescriptor<PrescriptionChange>())

        #expect(remainingSessions.isEmpty)
        #expect(remainingEvents.contains(where: { $0.id == linkedEvent.id }) == false)
        #expect(remainingEvents.contains(where: { $0.id == performanceLinkedEvent.id }) == false)
        #expect(remainingEvents.contains(where: { $0.id == priorEvent.id }))
        #expect(remainingEvents.contains(where: { $0.id == finalizedExternalEvent.id }) == false)
        #expect(remainingEvaluations.isEmpty)
        #expect(remainingChanges.contains(where: { $0.id == linkedChange.id }) == false)
    }

    @Test @MainActor
    func applyRetentionSetting_deletesAlreadyHiddenWorkoutsWhenDisabled() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)

        let settings = AppSettings()
        settings.retainPerformancesForLearning = false
        context.insert(settings)

        let session = WorkoutSession(title: "Bench", status: .done)
        session.isHidden = true
        context.insert(session)

        let exercise = Exercise(from: ExerciseCatalog.byID["barbell_bench_press"]!)
        let performance = ExercisePerformance(exercise: exercise, workoutSession: session)
        context.insert(performance)
        session.exercises?.append(performance)

        let hiddenEvent = SuggestionEvent(
            catalogID: performance.catalogID,
            sessionFrom: session,
            triggerPerformance: performance,
            trainingStyle: .straightSets
        )
        context.insert(hiddenEvent)

        WorkoutDeletionCoordinator.applyRetentionSetting(context: context, settings: settings)

        let remainingSessions = try context.fetch(WorkoutSession.byID(session.id))
        let remainingEvents = try context.fetch(FetchDescriptor<SuggestionEvent>())

        #expect(remainingSessions.isEmpty)
        #expect(remainingEvents.contains(where: { $0.id == hiddenEvent.id }) == false)
    }
}
