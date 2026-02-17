import Foundation
import SwiftData

struct SuggestionGroup: Identifiable {
    let id = UUID()
    let changes: [PrescriptionChange]
    let setPrescription: SetPrescription?
    let policy: ChangePolicy?
    
    var label: String {
        if let set = setPrescription {
            return "Set \(set.index + 1)"
        }
        switch policy {
        case .repRange: return "Rep Range"
        case .restTime: return "Rest Time"
        case .structure: return "Volume"
        case nil: return "Settings"
        }
    }
}

struct ExerciseSuggestionSection: Identifiable {
    let id = UUID()
    let exercisePrescription: ExercisePrescription
    let groups: [SuggestionGroup]
    
    var exerciseName: String { exercisePrescription.name }
}


func groupSuggestions(_ changes: [PrescriptionChange]) -> [ExerciseSuggestionSection] {
    // Group by exercise -> set/policy, then sort with a stable ordering.
    let byExercise = Dictionary(grouping: changes) { $0.targetExercisePrescription?.id }
    
    return byExercise.compactMap { (_, exerciseChanges) in
        guard let exercise = exerciseChanges.first?.targetExercisePrescription else { return nil }
        
        var groups: [SuggestionGroup] = []
        
        // Separate set-level vs exercise-level changes.
        let setChanges = exerciseChanges.filter { $0.targetSetPrescription != nil }
        let exerciseLevelChanges = exerciseChanges.filter { $0.targetSetPrescription == nil }
        
        // Group set changes by setID (one group per set).
        let bySet = Dictionary(grouping: setChanges) { $0.targetSetPrescription!.id }
        for (_, changes) in bySet {
            groups.append(SuggestionGroup(changes: sortedChanges(changes, policy: nil), setPrescription: changes.first?.targetSetPrescription, policy: nil))
        }
        
        // Group exercise-level changes by policy (rep range vs rest time).
        let byPolicy = Dictionary(grouping: exerciseLevelChanges) { $0.changeType.policy }
        for (policy, changes) in byPolicy {
            groups.append(SuggestionGroup(changes: sortedChanges(changes, policy: policy), setPrescription: nil, policy: policy))
        }
        
        // Sort: set groups by index, then exercise-level policies.
        groups.sort {
            let aOrder = $0.setPrescription?.index ?? (1000 + ($0.policy == .repRange ? 0 : 1))
            let bOrder = $1.setPrescription?.index ?? (1000 + ($1.policy == .repRange ? 0 : 1))
            return aOrder < bOrder
        }
        
        return ExerciseSuggestionSection(exercisePrescription: exercise, groups: groups)
    }.sorted { $0.exercisePrescription.index < $1.exercisePrescription.index }
}

private func sortedChanges(_ changes: [PrescriptionChange], policy: ChangePolicy?) -> [PrescriptionChange] {
    // Stable ordering inside each group.
    changes.sorted { lhs, rhs in
        let lhsOrder = changeOrder(for: lhs.changeType, policy: policy)
        let rhsOrder = changeOrder(for: rhs.changeType, policy: policy)
        if lhsOrder != rhsOrder {
            return lhsOrder < rhsOrder
        }
        // Tie-breaker by creation time so the UI order is deterministic.
        return lhs.createdAt < rhs.createdAt
    }
}

private func changeOrder(for changeType: ChangeType, policy: ChangePolicy?) -> Int {
    // Policy-specific ordering keeps the UI consistent and predictable.
    if policy == .repRange {
        switch changeType {
        case .changeRepRangeMode:
            return 1
        case .increaseRepRangeLower, .decreaseRepRangeLower:
            return 2
        case .increaseRepRangeUpper, .decreaseRepRangeUpper:
            return 3
        case .increaseRepRangeTarget, .decreaseRepRangeTarget:
            return 4
        default:
            return 10
        }
    }

    if policy == .restTime {
        switch changeType {
        case .changeRestTimeMode:
            return 1
        case .increaseRestTimeSeconds, .decreaseRestTimeSeconds:
            return 2
        default:
            return 10
        }
    }

    switch changeType {
    case .increaseWeight, .decreaseWeight:
        return 1
    case .increaseReps, .decreaseReps:
        return 2
    case .increaseRest, .decreaseRest:
        return 3
    case .changeSetType:
        return 4
    case .removeSet:
        return 5
    case .changeRepRangeMode,
         .increaseRepRangeLower, .decreaseRepRangeLower,
         .increaseRepRangeUpper, .decreaseRepRangeUpper,
         .increaseRepRangeTarget, .decreaseRepRangeTarget,
         .changeRestTimeMode,
         .increaseRestTimeSeconds, .decreaseRestTimeSeconds:
        return 10
    }
}


func pendingSuggestions(for plan: WorkoutPlan, in context: ModelContext) -> [PrescriptionChange] {
    var exerciseIDs: Set<UUID> = []
    for exercise in plan.exercises ?? [] {
        exerciseIDs.insert(exercise.id)
    }
    var setIDs: Set<UUID> = []
    for exercise in plan.exercises ?? []{
        for set in exercise.sets ?? [] {
            setIDs.insert(set.id)
        }
    }
    
    let descriptor = FetchDescriptor<PrescriptionChange>()
    guard let allChanges = try? context.fetch(descriptor) else { return [] }
    
    return allChanges.filter { change in
        (change.decision == .deferred || change.decision == .pending) &&
        (exerciseIDs.contains(change.targetExercisePrescription?.id ?? UUID()) ||
         setIDs.contains(change.targetSetPrescription?.id ?? UUID()))
    }
}
