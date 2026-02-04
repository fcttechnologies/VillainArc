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
    let byExercise = Dictionary(grouping: changes) { $0.targetExercisePrescription?.id }
    
    return byExercise.compactMap { (_, exerciseChanges) in
        guard let exercise = exerciseChanges.first?.targetExercisePrescription else { return nil }
        
        var groups: [SuggestionGroup] = []
        
        // Separate set-level vs exercise-level
        let setChanges = exerciseChanges.filter { $0.targetSetPrescription != nil }
        let exerciseLevelChanges = exerciseChanges.filter { $0.targetSetPrescription == nil }
        
        // Group set changes by setID
        let bySet = Dictionary(grouping: setChanges) { $0.targetSetPrescription!.id }
        for (_, changes) in bySet {
            groups.append(SuggestionGroup(
                changes: changes,
                setPrescription: changes.first?.targetSetPrescription,
                policy: nil
            ))
        }
        
        // Group exercise-level changes by policy
        let byPolicy = Dictionary(grouping: exerciseLevelChanges) { $0.changeType.policy }
        for (policy, changes) in byPolicy {
            groups.append(SuggestionGroup(
                changes: changes,
                setPrescription: nil,
                policy: policy
            ))
        }
        
        // Sort: sets by index, then exercise-level policies
        groups.sort {
            let aOrder = $0.setPrescription?.index ?? (1000 + ($0.policy == .repRange ? 0 : 1))
            let bOrder = $1.setPrescription?.index ?? (1000 + ($1.policy == .repRange ? 0 : 1))
            return aOrder < bOrder
        }
        
        return ExerciseSuggestionSection(exercisePrescription: exercise, groups: groups)
    }.sorted { $0.exercisePrescription.index < $1.exercisePrescription.index }
}


func pendingSuggestions(for plan: WorkoutPlan, in context: ModelContext) -> [PrescriptionChange] {
    let exerciseIDs = Set(plan.exercises.map { $0.id })
    let setIDs = Set(plan.exercises.flatMap { $0.sets.map { $0.id } })
    
    let descriptor = FetchDescriptor<PrescriptionChange>()
    guard let allChanges = try? context.fetch(descriptor) else { return [] }
    
    return allChanges.filter { change in
        (change.decision == .deferred || change.decision == .pending) &&
        (exerciseIDs.contains(change.targetExercisePrescription?.id ?? UUID()) ||
         setIDs.contains(change.targetSetPrescription?.id ?? UUID()))
    }
}
