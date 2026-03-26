import Foundation
import SwiftData

struct SuggestionGroup: Identifiable {
    let event: SuggestionEvent

    var id: UUID { event.id }
    var changes: [PrescriptionChange] { event.sortedChanges }

    var label: String {
        if let set = event.targetSetPrescription { return "Set \(set.index + 1)" }
        if let index = event.triggerTargetSetIndex { return "Set \(index + 1)" }
        return "Rep Range"
    }
}

struct ExerciseSuggestionSection: Identifiable {
    let exercisePrescription: ExercisePrescription
    let groups: [SuggestionGroup]

    var id: UUID { exercisePrescription.id }
    var exerciseName: String { exercisePrescription.name }
}

func groupSuggestions(_ events: [SuggestionEvent]) -> [ExerciseSuggestionSection] {
    let byExercise = Dictionary(grouping: events) { event in event.targetExercisePrescription?.id }

    return byExercise.compactMap { (_, exerciseEvents) in
            guard let exercise = exerciseEvents.first?.targetExercisePrescription else { return nil }

            let groups = exerciseEvents.map { SuggestionGroup(event: $0) }
                .sorted { lhs, rhs in
                    let lhsOrder = lhs.event.currentTargetSetIndex ?? lhs.event.triggerTargetSetIndex ?? Int.max
                    let rhsOrder = rhs.event.currentTargetSetIndex ?? rhs.event.triggerTargetSetIndex ?? Int.max
                    if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
                    return lhs.event.createdAt > rhs.event.createdAt
                }

                return ExerciseSuggestionSection(exercisePrescription: exercise, groups: groups)
            }
            .sorted { $0.exercisePrescription.index < $1.exercisePrescription.index }
}

func pendingSuggestionEvents(for plan: WorkoutPlan, in _: ModelContext) -> [SuggestionEvent] {
    suggestionEvents(for: plan) { event in event.decision == .pending || event.decision == .deferred }
}

func pendingOutcomeSuggestionEvents(for plan: WorkoutPlan, in _: ModelContext) -> [SuggestionEvent] {
    suggestionEvents(for: plan) {
        event in event.outcome == .pending && (event.decision == .accepted || event.decision == .rejected)
    }
}

private func suggestionEvents(for plan: WorkoutPlan, matching predicate: (SuggestionEvent) -> Bool) -> [SuggestionEvent] {
    var seenEventIDs = Set<UUID>()
    let exerciseEvents = plan.sortedExercises.flatMap { Array($0.suggestionEvents ?? []) }
    let setEvents = plan.sortedExercises.flatMap { $0.sortedSets.flatMap { Array($0.suggestionEvents ?? []) } }
    let events = (exerciseEvents + setEvents).filter(predicate)

    return events.filter { event in seenEventIDs.insert(event.id).inserted }
}
