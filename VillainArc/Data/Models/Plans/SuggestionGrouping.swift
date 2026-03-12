import Foundation
import SwiftData

struct SuggestionGroup: Identifiable {
    let event: SuggestionEvent

    var id: UUID { event.id }
    var changes: [PrescriptionChange] { event.sortedChanges }

    private var targetSetPrescription: SetPrescription? {
        changes.compactMap(\.targetSetPrescription).first
    }

    private var targetSetIndex: Int? {
        changes.compactMap(\.targetSetIndex).first
            ?? changes.compactMap(\.targetSetPrescription?.index).first
    }

    var label: String {
        if let set = targetSetPrescription {
            return "Set \(set.index + 1)"
        }
        if let index = targetSetIndex {
            return "Set \(index + 1)"
        }
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
    let byExercise = Dictionary(grouping: events) { event in
        event.changes?.compactMap(\.targetExercisePrescription).first?.id
    }

    return byExercise.compactMap { (_, exerciseEvents) in
        guard let exercise = exerciseEvents.first?.changes?.compactMap(\.targetExercisePrescription).first else { return nil }

        let groups = exerciseEvents
            .map { SuggestionGroup(event: $0) }
            .sorted { lhs, rhs in
                let lhsOrder = lhs.changes.compactMap(\.targetSetIndex).first
                    ?? lhs.changes.compactMap(\.targetSetPrescription?.index).first
                    ?? Int.max
                let rhsOrder = rhs.changes.compactMap(\.targetSetIndex).first
                    ?? rhs.changes.compactMap(\.targetSetPrescription?.index).first
                    ?? Int.max
                if lhsOrder != rhsOrder {
                    return lhsOrder < rhsOrder
                }
                return lhs.event.createdAt > rhs.event.createdAt
            }

        return ExerciseSuggestionSection(exercisePrescription: exercise, groups: groups)
    }
    .sorted { $0.exercisePrescription.index < $1.exercisePrescription.index }
}

func pendingSuggestionEvents(for plan: WorkoutPlan, in _: ModelContext) -> [SuggestionEvent] {
    var seenEventIDs = Set<UUID>()
    let exerciseChanges = plan.sortedExercises.flatMap { Array($0.changes ?? []) }
    let setChanges = plan.sortedExercises.flatMap { $0.sortedSets.flatMap { Array($0.changes ?? []) } }
    let allChanges = exerciseChanges + setChanges

    let events = allChanges.compactMap(\.event).filter { event in
        event.decision == .pending || event.decision == .deferred
    }

    return events.filter { event in
        seenEventIDs.insert(event.id).inserted
    }
}
