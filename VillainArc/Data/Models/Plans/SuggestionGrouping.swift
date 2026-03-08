import Foundation
import SwiftData

struct SuggestionGroup: Identifiable {
    let id = UUID()
    let changes: [PrescriptionChange]
    let setPrescription: SetPrescription?

    var label: String {
        if let set = setPrescription {
            return "Set \(set.index + 1)"
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


func groupSuggestions(_ changes: [PrescriptionChange]) -> [ExerciseSuggestionSection] {
    let byExercise = Dictionary(grouping: changes) { $0.targetExercisePrescription?.id }

    return byExercise.compactMap { (_, exerciseChanges) in
        guard let exercise = exerciseChanges.first?.targetExercisePrescription else { return nil }

        var groups: [SuggestionGroup] = []

        let setChanges = exerciseChanges.filter { $0.targetSetPrescription != nil }
        let exerciseLevelChanges = exerciseChanges.filter { $0.targetSetPrescription == nil }

        let bySet = Dictionary(grouping: setChanges) { $0.targetSetPrescription!.id }
        for (_, changes) in bySet {
            groups.append(SuggestionGroup(changes: sortedChanges(changes), setPrescription: changes.first?.targetSetPrescription))
        }

        if !exerciseLevelChanges.isEmpty {
            groups.append(SuggestionGroup(changes: sortedChanges(exerciseLevelChanges), setPrescription: nil))
        }

        groups.sort {
            let aOrder = $0.setPrescription?.index ?? Int.max
            let bOrder = $1.setPrescription?.index ?? Int.max
            return aOrder < bOrder
        }

        return ExerciseSuggestionSection(exercisePrescription: exercise, groups: groups)
    }.sorted { $0.exercisePrescription.index < $1.exercisePrescription.index }
}

private func sortedChanges(_ changes: [PrescriptionChange]) -> [PrescriptionChange] {
    changes.sorted { lhs, rhs in
        let lhsOrder = changeOrder(for: lhs.changeType)
        let rhsOrder = changeOrder(for: rhs.changeType)
        if lhsOrder != rhsOrder {
            return lhsOrder < rhsOrder
        }
        return lhs.createdAt < rhs.createdAt
    }
}

private func changeOrder(for changeType: ChangeType) -> Int {
    switch changeType {
    case .increaseWeight, .decreaseWeight:
        return 1
    case .increaseReps, .decreaseReps:
        return 2
    case .increaseRest, .decreaseRest:
        return 3
    case .changeSetType:
        return 4
    case .changeRepRangeMode,
         .increaseRepRangeLower, .decreaseRepRangeLower,
         .increaseRepRangeUpper, .decreaseRepRangeUpper,
         .increaseRepRangeTarget, .decreaseRepRangeTarget:
        return 10
    }
}


func pendingSuggestions(for plan: WorkoutPlan) -> [PrescriptionChange] {
    (plan.targetedChanges ?? []).filter { $0.decision == .pending || $0.decision == .deferred }
}
