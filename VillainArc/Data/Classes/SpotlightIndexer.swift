import CoreSpotlight
import UniformTypeIdentifiers

@MainActor
enum SpotlightIndexer {
    static let workoutIdentifierPrefix = "workout:"
    static let templateIdentifierPrefix = "template:"
    private static let workoutDomainIdentifier = "com.villainarc.workout"
    private static let templateDomainIdentifier = "com.villainarc.template"

    static func index(workout: Workout) {
        guard workout.completed else { return }
        let attributes = CSSearchableItemAttributeSet(contentType: .item)
        attributes.title = workout.title
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
        attributes.contentDescription = template.spotlightSummary
        attributes.keywords = template.sortedExercises.map(\.name) + ["Template"]
        let item = CSSearchableItem(
            uniqueIdentifier: templateIdentifierPrefix + template.id.uuidString,
            domainIdentifier: templateDomainIdentifier,
            attributeSet: attributes
        )
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

    private static func delete(identifiers: [String]) {
        guard !identifiers.isEmpty else { return }
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: identifiers, completionHandler: nil)
    }
}
