import CoreSpotlight
import UniformTypeIdentifiers
import AppIntents

@MainActor
enum SpotlightIndexer {
    static let workoutSessionIdentifierPrefix = "workoutSession:"
    static let workoutPlanIdentifierPrefix = "workoutPlan:"
    static let exerciseIdentifierPrefix = "exercise:"
    private static let workoutSessionDomainIdentifier = "com.villainarc.workoutSession"
    private static let workoutPlanDomainIdentifier = "com.villainarc.workoutPlan"
    private static let exerciseDomainIdentifier = "com.villainarc.exercise"

    static func index(workoutSession: WorkoutSession) {
        let attributes = CSSearchableItemAttributeSet(contentType: .item)
        let displayTitle = "\(workoutSession.title) (Workout)"
        attributes.title = displayTitle
        attributes.displayName = displayTitle
        attributes.contentDescription = workoutSession.spotlightSummary
        attributes.keywords = workoutSession.sortedExercises.map(\.name) + ["Workout"]
        let item = CSSearchableItem(uniqueIdentifier: workoutSessionIdentifierPrefix + workoutSession.id.uuidString, domainIdentifier: workoutSessionDomainIdentifier, attributeSet: attributes)
        item.associateAppEntity(WorkoutSessionEntity(workoutSession: workoutSession), priority: 1)
        CSSearchableIndex.default().indexSearchableItems([item], completionHandler: nil)
    }

    static func index(workoutPlan: WorkoutPlan) {
        let attributes = CSSearchableItemAttributeSet(contentType: .item)
        attributes.title = workoutPlan.title
        attributes.displayName = workoutPlan.title
        attributes.contentDescription = workoutPlan.spotlightSummary
        attributes.keywords = workoutPlan.sortedExercises.map(\.name) + ["Workout Plan"]
        let item = CSSearchableItem(uniqueIdentifier: workoutPlanIdentifierPrefix + workoutPlan.id.uuidString, domainIdentifier: workoutPlanDomainIdentifier, attributeSet: attributes)
        item.associateAppEntity(WorkoutPlanEntity(workoutPlan: workoutPlan), priority: 1)
        CSSearchableIndex.default().indexSearchableItems([item], completionHandler: nil)
    }

    static func index(exercise: Exercise) {
        let attributes = CSSearchableItemAttributeSet(contentType: .item)
        attributes.title = exercise.name
        attributes.displayName = exercise.name
        attributes.alternateNames = exercise.aliases
        attributes.contentDescription = exercise.displayMuscles
        attributes.keywords = [exercise.name] + exercise.aliases + ["Exercise"]
        let item = CSSearchableItem(uniqueIdentifier: exerciseIdentifierPrefix + exercise.catalogID, domainIdentifier: exerciseDomainIdentifier, attributeSet: attributes)
        item.associateAppEntity(ExerciseEntity(exercise: exercise), priority: 1)
        CSSearchableIndex.default().indexSearchableItems([item], completionHandler: nil)
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

    private static func delete(identifiers: [String]) {
        guard !identifiers.isEmpty else { return }
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: identifiers, completionHandler: nil)
    }
}
