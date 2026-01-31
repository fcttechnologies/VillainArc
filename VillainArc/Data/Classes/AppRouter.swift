import SwiftUI
import SwiftData

@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()
    var activeWorkoutSession: WorkoutSession?
    var activeWorkoutPlan: WorkoutPlan?
    
    enum Destination: Hashable {
        case workoutSessionsList
        case workoutSessionDetail(WorkoutSession)
        case workoutPlansList
        case workoutPlanDetail(WorkoutPlan)
        case splitList
        case splitDettail(WorkoutSplit)
    }
    
    var path = NavigationPath()
    
    private init() {}
    
    private var context: ModelContext {
        SharedModelContainer.container.mainContext
    }
    
    func navigate(to destination: Destination) {
        path.append(destination)
    }
    
    func popToRoot() {
        path = NavigationPath()
    }

    func startWorkoutSession() {
        Haptics.selection()
        let newWorkout = WorkoutSession()
        context.insert(newWorkout)
        saveContext(context: context)
        activeWorkoutSession = newWorkout
    }
    
    func createWorkoutPlan() {
        Haptics.selection()
        let newWorkoutPlan = WorkoutPlan()
        context.insert(newWorkoutPlan)
        saveContext(context: context)
        activeWorkoutPlan = newWorkoutPlan
    }
    
    func startWorkoutSession(from plan: WorkoutPlan) {
        Haptics.selection()
        let workoutSession = WorkoutSession(from: plan)
        context.insert(workoutSession)
        saveContext(context: context)
        activeWorkoutSession = workoutSession
    }

    func resumeWorkoutSession(_ workoutSession: WorkoutSession) {
        Haptics.selection()
        activeWorkoutSession = workoutSession
    }
    
    func resumeWorkoutPlanCreation(_ workoutPlan: WorkoutPlan) {
        Haptics.selection()
        activeWorkoutPlan = workoutPlan
    }
    
    func checkForUnfinishedData() {
        if let unfinishedWorkoutSession = try? context.fetch(WorkoutSession.incomplete).first {
            resumeWorkoutSession(unfinishedWorkoutSession)
        }
        if let unfinishedWorkoutPlan = try? context.fetch(WorkoutPlan.incomplete).first {
            resumeWorkoutPlanCreation(unfinishedWorkoutPlan)
        }
    }
}
