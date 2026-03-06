import CoreSpotlight
import UniformTypeIdentifiers
import AppIntents
import SwiftData

@MainActor
enum SpotlightIndexer {
    static let workoutSessionIdentifierPrefix = "workoutSession:"
    static let workoutPlanIdentifierPrefix = "workoutPlan:"
    static let exerciseIdentifierPrefix = "exercise:"
    private static let workoutSessionDomainIdentifier = "com.villainarc.workoutSession"
    private static let workoutPlanDomainIdentifier = "com.villainarc.workoutPlan"
    private static let exerciseDomainIdentifier = "com.villainarc.exercise"

    static func index(workoutSession: WorkoutSession) {
        CSSearchableIndex.default().indexSearchableItems([makeSearchableItem(for: workoutSession)], completionHandler: nil)
    }

    static func index(workoutPlan: WorkoutPlan) {
        CSSearchableIndex.default().indexSearchableItems([makeSearchableItem(for: workoutPlan)], completionHandler: nil)
    }

    static func index(exercise: Exercise) {
        CSSearchableIndex.default().indexSearchableItems([makeSearchableItem(for: exercise)], completionHandler: nil)
    }

    static func reindexAll(context: ModelContext) {
        let completedWorkouts = (try? context.fetch(WorkoutSession.completedSession)) ?? []
        let completedPlans = (try? context.fetch(WorkoutPlan.all)) ?? []
        let exercisesToIndex = (try? context.fetch(Exercise.spotlightEligible)) ?? []

        let allItems = completedWorkouts.map(makeSearchableItem(for:))
            + completedPlans.map(makeSearchableItem(for:))
            + exercisesToIndex.map(makeSearchableItem(for:))

        guard !allItems.isEmpty else {
            print("ℹ️ Spotlight rebuild skipped indexing (no items found)")
            return
        }

        CSSearchableIndex.default().indexSearchableItems(allItems, completionHandler: nil)
        print("✅ Spotlight rebuild queued: \(completedWorkouts.count) workouts, \(completedPlans.count) plans, \(exercisesToIndex.count) exercises")
    }

    static func deleteWorkoutSession(id: UUID) {
        delete(identifiers: [workoutSessionIdentifierPrefix + id.uuidString])
    }

    static func deleteWorkoutSessions(ids: [UUID]) {
        delete(identifiers: ids.map { workoutSessionIdentifierPrefix + $0.uuidString })
    }

    static func deleteWorkoutPlan(id: UUID) {
        delete(identifiers: [workoutPlanIdentifierPrefix + id.uuidString])
    }

    static func deleteWorkoutPlans(ids: [UUID]) {
        delete(identifiers: ids.map { workoutPlanIdentifierPrefix + $0.uuidString })
    }

    static func deleteExercise(catalogID: String) {
        delete(identifiers: [exerciseIdentifierPrefix + catalogID])
    }

    private static func makeSearchableItem(for workoutSession: WorkoutSession) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .item)
        let displayTitle = "\(workoutSession.title) (Workout)"
        attributes.title = displayTitle
        attributes.displayName = displayTitle
        attributes.contentDescription = workoutSession.spotlightSummary
        attributes.keywords = workoutSession.sortedExercises.map(\.name) + ["Workout"]
        let item = CSSearchableItem(uniqueIdentifier: workoutSessionIdentifierPrefix + workoutSession.id.uuidString, domainIdentifier: workoutSessionDomainIdentifier, attributeSet: attributes)
        item.associateAppEntity(WorkoutSessionEntity(workoutSession: workoutSession), priority: 1)
        return item
    }

    private static func makeSearchableItem(for workoutPlan: WorkoutPlan) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .item)
        attributes.title = workoutPlan.title
        attributes.displayName = workoutPlan.title
        attributes.contentDescription = workoutPlan.spotlightSummary
        attributes.keywords = workoutPlan.sortedExercises.map(\.name) + ["Workout Plan"]
        let item = CSSearchableItem(uniqueIdentifier: workoutPlanIdentifierPrefix + workoutPlan.id.uuidString, domainIdentifier: workoutPlanDomainIdentifier, attributeSet: attributes)
        item.associateAppEntity(WorkoutPlanEntity(workoutPlan: workoutPlan), priority: 1)
        return item
    }

    private static func makeSearchableItem(for exercise: Exercise) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .item)
        attributes.title = exercise.name
        attributes.displayName = exercise.name
        attributes.alternateNames = exercise.aliases
        attributes.contentDescription = exercise.equipmentType.rawValue
        attributes.keywords = [exercise.name] + exercise.aliases + ["Exercise"]
        let item = CSSearchableItem(uniqueIdentifier: exerciseIdentifierPrefix + exercise.catalogID, domainIdentifier: exerciseDomainIdentifier, attributeSet: attributes)
        item.associateAppEntity(ExerciseEntity(exercise: exercise), priority: 1)
        return item
    }

    private static func delete(identifiers: [String]) {
        guard !identifiers.isEmpty else { return }
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: identifiers, completionHandler: nil)
    }
}
