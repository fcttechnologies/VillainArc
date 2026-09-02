import FCTBlobSync
import FCTBlobSyncTesting
import FCTServerSync
import FCTServerSyncTesting
import FCTSync
import Foundation
import SwiftData
import Testing

@testable import VillainArc

/// Villain Arc's adapter for the FCTServerSync adopter contract suite.
///
/// The write operations keep the derived defaults deliberately: VA's shipping write path IS
/// direct `ModelContext` writes (the app's long-standing direct-writes shape — there is no store
/// type between a view and a save), so the bare-context defaults are the real seam, not a
/// stand-in for one.
///
/// The joins are the app's real multi-parent rows, seeded through the models' own creation
/// initializers — the path a live workout takes — so an initializer that forgets to wire a link
/// fails here rather than in production.
@MainActor
struct VASyncContractAdapter: SyncContractAdapter {
    var schema: SyncSchema { VASyncSchema.schema }
    var primaryTable: String { WorkoutSession.syncTableName }
    var markerColumn: String { "notes" }

    func makeStore() throws -> SyncContractStore {
        let made = try TestStoreFactory.onDisk(VillainArcSchemaV1.self)
        return SyncContractStore(container: made.container, url: made.url)
    }

    var joins: [SyncJoinDescriptor] {
        [
            SyncJoinDescriptor(
                name: "split day → split + plan",
                childTable: WorkoutSplitDay.syncTableName,
                roles: [
                    .init(WorkoutSplitDay.splitRole, parentTable: WorkoutSplit.syncTableName, column: "split_id"),
                    .init(WorkoutSplitDay.planRole, parentTable: WorkoutPlan.syncTableName, column: "workout_plan_id"),
                ]
            ) { container in
                let context = container.mainContext
                let split = WorkoutSplit(title: "Contract Split", mode: .rotation)
                let plan = WorkoutPlan(title: "Contract Plan", completed: true)
                context.insert(split)
                context.insert(plan)
                let day = WorkoutSplitDay(index: 0, split: split)
                day.workoutPlan = plan
                split.days?.append(day)
                try context.save()
                return SyncJoinDescriptor.Seed(
                    child: day.id,
                    parents: [WorkoutSplitDay.splitRole: split.id, WorkoutSplitDay.planRole: plan.id]
                )
            },
            SyncJoinDescriptor(
                name: "performance → session + prescription",
                childTable: ExercisePerformance.syncTableName,
                roles: [
                    .init(ExercisePerformance.sessionRole, parentTable: WorkoutSession.syncTableName, column: "workout_session_id"),
                    .init(ExercisePerformance.prescriptionRole, parentTable: ExercisePrescription.syncTableName, column: "exercise_prescription_id"),
                ]
            ) { container in
                let seeded = try Self.seedPerformance(in: container)
                return SyncJoinDescriptor.Seed(
                    child: seeded.performance.id,
                    parents: [
                        ExercisePerformance.sessionRole: seeded.session.id,
                        ExercisePerformance.prescriptionRole: seeded.prescription.id,
                    ]
                )
            },
            SyncJoinDescriptor(
                name: "set → performance + set prescription",
                childTable: SetPerformance.syncTableName,
                roles: [
                    .init(SetPerformance.exerciseRole, parentTable: ExercisePerformance.syncTableName, column: "exercise_performance_id"),
                    .init(SetPerformance.prescriptionRole, parentTable: SetPrescription.syncTableName, column: "set_prescription_id"),
                ]
            ) { container in
                let seeded = try Self.seedPerformance(in: container)
                let context = container.mainContext
                let setPrescription = SetPrescription(exercisePrescription: seeded.prescription)
                let set = SetPerformance(exercise: seeded.performance, setPrescription: setPrescription, autoFillTargets: false)
                try context.save()
                return SyncJoinDescriptor.Seed(
                    child: set.id,
                    parents: [
                        SetPerformance.exerciseRole: seeded.performance.id,
                        SetPerformance.prescriptionRole: setPrescription.id,
                    ]
                )
            },
            SyncJoinDescriptor(
                name: "rep range → performance",
                childTable: RepRangePolicy.syncTableName,
                roles: [
                    .init(RepRangePolicy.performanceRole, parentTable: ExercisePerformance.syncTableName, column: "exercise_performance_id"),
                ]
            ) { container in
                let seeded = try Self.seedPerformance(in: container)
                let policy = try #require(seeded.performance.repRange)
                return SyncJoinDescriptor.Seed(
                    child: policy.id,
                    parents: [RepRangePolicy.performanceRole: seeded.performance.id]
                )
            },
            SyncJoinDescriptor(
                name: "rep range → prescription",
                childTable: RepRangePolicy.syncTableName,
                roles: [
                    .init(RepRangePolicy.prescriptionRole, parentTable: ExercisePrescription.syncTableName, column: "exercise_prescription_id"),
                ]
            ) { container in
                let seeded = try Self.seedPerformance(in: container)
                let policy = try #require(seeded.prescription.repRange)
                return SyncJoinDescriptor.Seed(
                    child: policy.id,
                    parents: [RepRangePolicy.prescriptionRole: seeded.prescription.id]
                )
            },
            SyncJoinDescriptor(
                name: "suggestion event → session + both targets + trigger",
                childTable: SuggestionEvent.syncTableName,
                roles: [
                    .init(SuggestionEvent.sessionRole, parentTable: WorkoutSession.syncTableName, column: "session_from_id"),
                    .init(SuggestionEvent.exercisePrescriptionRole, parentTable: ExercisePrescription.syncTableName, column: "target_exercise_prescription_id"),
                    .init(SuggestionEvent.setPrescriptionRole, parentTable: SetPrescription.syncTableName, column: "target_set_prescription_id"),
                    .init(SuggestionEvent.performanceRole, parentTable: ExercisePerformance.syncTableName, column: "trigger_performance_id"),
                ]
            ) { container in
                let seeded = try Self.seedPerformance(in: container)
                let context = container.mainContext
                let setPrescription = SetPrescription(exercisePrescription: seeded.prescription)
                let event = SuggestionEvent(
                    catalogID: seeded.prescription.catalogID,
                    sessionFrom: seeded.session,
                    targetExercisePrescription: seeded.prescription,
                    targetSetPrescription: setPrescription,
                    triggerPerformance: seeded.performance,
                    trainingStyle: .unknown
                )
                context.insert(event)
                try context.save()
                return SyncJoinDescriptor.Seed(
                    child: event.id,
                    parents: [
                        SuggestionEvent.sessionRole: seeded.session.id,
                        SuggestionEvent.exercisePrescriptionRole: seeded.prescription.id,
                        SuggestionEvent.setPrescriptionRole: setPrescription.id,
                        SuggestionEvent.performanceRole: seeded.performance.id,
                    ]
                )
            },
            SyncJoinDescriptor(
                name: "evaluation → event + performance",
                childTable: SuggestionEvaluation.syncTableName,
                roles: [
                    .init(SuggestionEvaluation.eventRole, parentTable: SuggestionEvent.syncTableName, column: "event_id"),
                    .init(SuggestionEvaluation.performanceRole, parentTable: ExercisePerformance.syncTableName, column: "performance_id"),
                ]
            ) { container in
                let seeded = try Self.seedPerformance(in: container)
                let context = container.mainContext
                let event = SuggestionEvent(
                    catalogID: seeded.prescription.catalogID,
                    sessionFrom: nil,
                    trainingStyle: .unknown
                )
                context.insert(event)
                let evaluation = SuggestionEvaluation(
                    event: event,
                    performance: seeded.performance,
                    sourceWorkoutSessionID: seeded.session.id,
                    partialOutcome: .pending,
                    confidence: 0.5,
                    reason: "contract"
                )
                context.insert(evaluation)
                try context.save()
                return SyncJoinDescriptor.Seed(
                    child: evaluation.id,
                    parents: [
                        SuggestionEvaluation.eventRole: event.id,
                        SuggestionEvaluation.performanceRole: seeded.performance.id,
                    ]
                )
            },
        ]
    }

    /// The shared spine most joins hang off: a plan-backed session with one prescription and its
    /// live performance, built through the models' own initializers.
    private static func seedPerformance(
        in container: ModelContainer
    ) throws -> (session: WorkoutSession, prescription: ExercisePrescription, performance: ExercisePerformance) {
        let context = container.mainContext
        let catalogItem = ExerciseCatalog.all[0]
        let exercise = Exercise(from: catalogItem)
        context.insert(exercise)
        let plan = WorkoutPlan(title: "Contract Plan", completed: true)
        context.insert(plan)
        let prescription = ExercisePrescription(exercise: exercise, workoutPlan: plan)
        let session = WorkoutSession()
        context.insert(session)
        let performance = ExercisePerformance(
            workoutSession: session,
            exercisePrescription: prescription,
            autoFillTargets: false
        )
        try context.save()
        return (session, prescription, performance)
    }
}

/// The whole instantiation: one adapter, one parameterized test. The same scenarios every adopting
/// app runs, through Villain Arc's own models, joins, and write paths.
///
/// **There is no blob adapter beside it, because Villain Arc authors no bytes.** The one picture is
/// the account's avatar, which is not this app's record to carry: it lives on `account.profile`'s
/// `avatar_blob` row as a blob uuid rather than as an `AssetSource`, and the shape this suite's
/// blob half asserts — an asset column on an app's own synced table — is one no Villain Arc row
/// has. What the app does own there is the wiring it gives `AccountBlobStore`, and that is pinned
/// against the real bootstrap in `AccountBlobWiringTests`.
@Suite("FCTServerSync adopter contract — Villain Arc instantiation")
struct VASyncContractTests {
    @Test(arguments: SyncContractScenario.all)
    @MainActor
    func contract(_ scenario: SyncContractScenario) async throws {
        try await scenario.run(with: VASyncContractAdapter())
    }
}
