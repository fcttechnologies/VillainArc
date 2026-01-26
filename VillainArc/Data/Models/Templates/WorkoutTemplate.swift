import SwiftUI
import SwiftData

@Model
class WorkoutTemplate {
    var id: UUID = UUID()
    var name: String = ""
    var notes: String = ""
    var isFavorite: Bool = false
    var lastUsed: Date?
    var complete: Bool = false
    @Relationship(deleteRule: .cascade, inverse: \TemplateExercise.template)
    var exercises: [TemplateExercise] = []
    
    var sortedExercises: [TemplateExercise] {
        exercises.sorted { $0.index < $1.index }
    }
    
    func musclesTargeted() -> String {
        var seen = Set<Muscle>()
        var result: [Muscle] = []
        for exercise in sortedExercises {
            if let major = exercise.musclesTargeted.first(where: \.isMajor), !seen.contains(major) {
                seen.insert(major)
                result.append(major)
            }
        }
        return ListFormatter.localizedString(byJoining: result.map(\.rawValue))
    }
    
    init(name: String = "New Template") {
        self.name = name
    }

    init(from workout: Workout) {
        name = workout.title
        notes = workout.notes
        complete = true
        exercises = workout.sortedExercises.map { TemplateExercise(from: $0, template: self) }
    }
    
    func addExercise(_ exercise: Exercise) {
        let templateExercise = TemplateExercise(from: exercise, template: self)
        exercises.append(templateExercise)
    }
    
    func removeExercise(_ exercise: TemplateExercise) {
        exercises.removeAll { $0 == exercise }
        
        for (index, templateExercise) in sortedExercises.enumerated() {
            templateExercise.index = index
        }
    }
    
    func moveExercise(from source: IndexSet, to destination: Int) {
        var sortedEx = sortedExercises
        sortedEx.move(fromOffsets: source, toOffset: destination)
        
        for (index, templateExercise) in sortedEx.enumerated() {
            templateExercise.index = index
        }
    }
    
    func updateLastUsed(_ date: Date = .now) {
        lastUsed = date
    }
}

extension WorkoutTemplate {

    var spotlightSummary: String {
        let exerciseSummaries = sortedExercises.map { exercise in
            "\(exercise.sets.count)x \(exercise.name)"
        }
        return exerciseSummaries.joined(separator: ", ")
    }
    
    static var completedPredicate: Predicate<WorkoutTemplate> {
        #Predicate<WorkoutTemplate> { $0.complete }
    }

    static var recentsSort: [SortDescriptor<WorkoutTemplate>] {
        [
            SortDescriptor(\WorkoutTemplate.lastUsed, order: .reverse),
            SortDescriptor(\WorkoutTemplate.name)
        ]
    }

    static var all: FetchDescriptor<WorkoutTemplate> {
        return FetchDescriptor(predicate: completedPredicate, sortBy: recentsSort)
    }
    
    static var recents: FetchDescriptor<WorkoutTemplate> {
        var descriptor = FetchDescriptor(predicate: completedPredicate, sortBy: recentsSort)
        descriptor.fetchLimit = 3
        return descriptor
    }
    
    static var incomplete: FetchDescriptor<WorkoutTemplate> {
        let predicate = #Predicate<WorkoutTemplate> { !$0.complete }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        return descriptor
    }
}
