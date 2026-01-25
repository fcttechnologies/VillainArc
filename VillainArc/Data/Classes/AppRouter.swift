import SwiftUI
import SwiftData

@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()
    var activeWorkout: Workout?
    var activeTemplate: WorkoutTemplate?
    
    enum Destination: Hashable {
        case workoutsList
        case workoutDetail(Workout)
        case templateList
        case templateDetail(WorkoutTemplate)
    }
    
    var path = NavigationPath()
    
    private init() {}
    
    func navigate(to destination: Destination) {
        path.append(destination)
    }
    
    func popToRoot() {
        path = NavigationPath()
    }

    func startWorkout(from workout: Workout? = nil, context: ModelContext) {
        let context = ModelContext(SharedModelContainer.container)
        Haptics.selection()
        let newWorkout = workout.map { Workout(previous: $0) } ?? Workout()
        context.insert(newWorkout)
        saveContext(context: context)
        activeWorkout = newWorkout
    }
    
    func createTemplate(context: ModelContext) {
        Haptics.selection()
        let newTemplate = WorkoutTemplate()
        context.insert(newTemplate)
        saveContext(context: context)
        activeTemplate = newTemplate
    }
    
    func startWorkout(from template: WorkoutTemplate, context: ModelContext) {
        Haptics.selection()
        let workout = Workout(from: template)
        context.insert(workout)
        saveContext(context: context)
        activeWorkout = workout
    }

    func resumeWorkout(_ workout: Workout) {
        Haptics.selection()
        activeWorkout = workout
    }
    
    func resumeTemplate(_ template: WorkoutTemplate) {
        Haptics.selection()
        activeTemplate = template
    }
    
    func checkForUnfinishedData(context: ModelContext) {
        do {
            if let unfinishedWorkout = try context.fetch(Workout.incomplete).first {
                resumeWorkout(unfinishedWorkout)
            }
            if let unfinishedTemplate = try context.fetch(WorkoutTemplate.incomplete).first {
                resumeTemplate(unfinishedTemplate)
            }
        } catch {
            
        }
    }
}
