import AppIntents
import SwiftData

struct StartTodaysWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Today's Workout"
    static let description = IntentDescription("Starts today's workout from your active split.")
    static let supportedModes: IntentModes = .foreground(.dynamic)

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        let context = SharedModelContainer.container.mainContext
        
        // Check for active split
        guard let split = try? context.fetch(WorkoutSplit.active).first else {
            throw StartTodaysWorkoutError.noActiveSplit
        }
        
        // Check split has days
        guard !split.days.isEmpty else {
            throw StartTodaysWorkoutError.noDaysInSplit
        }
        
        // Sync rotation index if needed
        split.refreshRotationIfNeeded()
        saveContext(context: context)
        
        // Check no template being edited
        if let _ = try? context.fetch(WorkoutTemplate.incomplete).first {
            throw StartWorkoutError.templateIsActive
        }
        
        // Check no workout in progress
        if let _ = try? context.fetch(Workout.incomplete).first {
            throw StartWorkoutError.workoutIsActive
        }
        
        // Get today's split day
        guard let todaysDay = split.todaysSplitDay else {
            throw StartTodaysWorkoutError.noDayForToday
        }
        
        // Check if rest day
        guard !todaysDay.isRestDay else {
            throw StartTodaysWorkoutError.todayIsRestDay
        }
        
        // Check template exists for today
        guard let template = todaysDay.template else {
            throw StartTodaysWorkoutError.noTemplateForToday
        }
        
        await IntentDonations.donateStartWorkoutWithTemplate(template: template)
        AppRouter.shared.startWorkout(from: template)
        return .result(opensIntent: OpenAppIntent())
    }
}

enum StartTodaysWorkoutError: Error, CustomLocalizedStringResourceConvertible {
    case noActiveSplit
    case noDaysInSplit
    case noDayForToday
    case todayIsRestDay
    case noTemplateForToday

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noActiveSplit:
            return "You don't have an active workout split."
        case .noDaysInSplit:
            return "Your split doesn't have any days set up yet."
        case .noDayForToday:
            return "Couldn't determine today's workout."
        case .todayIsRestDay:
            return "Today is a rest day! Enjoy your recovery."
        case .noTemplateForToday:
            return "No template assigned for today's workout."
        }
    }
}
