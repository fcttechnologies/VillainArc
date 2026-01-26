import CoreSpotlight
import UniformTypeIdentifiers
import AppIntents

@MainActor
enum SpotlightIndexer {
    static let workoutIdentifierPrefix = "workout:"
    static let templateIdentifierPrefix = "template:"
    static let exerciseIdentifierPrefix = "exercise:"
    private static let workoutDomainIdentifier = "com.villainarc.workout"
    private static let templateDomainIdentifier = "com.villainarc.template"
    private static let exerciseDomainIdentifier = "com.villainarc.exercise"

    static func index(workout: Workout) {
        guard workout.completed else { return }
        let attributes = CSSearchableItemAttributeSet(contentType: .item)
        let displayTitle = "\(workout.title) (Workout)"
        attributes.title = displayTitle
        attributes.displayName = displayTitle
        attributes.contentDescription = workout.spotlightSummary
        attributes.keywords = workout.sortedExercises.map(\.name) + ["Workout"]
        let item = CSSearchableItem(
            uniqueIdentifier: workoutIdentifierPrefix + workout.id.uuidString,
            domainIdentifier: workoutDomainIdentifier,
            attributeSet: attributes
        )
        CSSearchableIndex.default().indexSearchableItems([item], completionHandler: nil)
    }

    static func index(template: WorkoutTemplate) {
        guard template.complete else { return }
        let attributes = CSSearchableItemAttributeSet(contentType: .item)
        attributes.title = template.name
        attributes.displayName = template.name
        attributes.contentDescription = template.spotlightSummary
        attributes.keywords = [template.name] + template.sortedExercises.map(\.name) + ["Template"]
        let item = CSSearchableItem(
            uniqueIdentifier: templateIdentifierPrefix + template.id.uuidString,
            domainIdentifier: templateDomainIdentifier,
            attributeSet: attributes
        )
        item.associateAppEntity(WorkoutTemplateEntity(template: template), priority: 1)
        CSSearchableIndex.default().indexSearchableItems([item], completionHandler: nil)
    }

    static func index(exercise: Exercise) {
        let attributes = CSSearchableItemAttributeSet(contentType: .item)
        attributes.title = exercise.name
        attributes.displayName = exercise.name
        attributes.alternateNames = exercise.aliases
        attributes.contentDescription = exercise.displayMuscles
        attributes.keywords = [exercise.name] + exercise.aliases + ["Exercise"]
        let item = CSSearchableItem(
            uniqueIdentifier: exerciseIdentifierPrefix + exercise.catalogID,
            domainIdentifier: exerciseDomainIdentifier,
            attributeSet: attributes
        )
        item.associateAppEntity(ExerciseEntity(exercise: exercise), priority: 1)
        CSSearchableIndex.default().indexSearchableItems([item], completionHandler: nil)
    }

    static func deleteWorkout(id: UUID) {
        delete(identifiers: [workoutIdentifierPrefix + id.uuidString])
    }

    static func deleteWorkouts(ids: [UUID]) {
        delete(identifiers: ids.map { workoutIdentifierPrefix + $0.uuidString })
    }

    static func deleteTemplate(id: UUID) {
        delete(identifiers: [templateIdentifierPrefix + id.uuidString])
    }

    static func deleteTemplates(ids: [UUID]) {
        delete(identifiers: ids.map { templateIdentifierPrefix + $0.uuidString })
    }

    static func deleteExercise(catalogID: String) {
        delete(identifiers: [exerciseIdentifierPrefix + catalogID])
    }

    private static func delete(identifiers: [String]) {
        guard !identifiers.isEmpty else { return }
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: identifiers, completionHandler: nil)
    }
}
