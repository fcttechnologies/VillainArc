import AppIntents
import Foundation

enum IntentDonations {
    static func donateStartWorkout() async {
        _ = try? await StartWorkoutIntent().donate()
    }
    
    static func donateViewLastWorkout() async {
        _ = try? await ViewLastWorkoutIntent().donate()
    }
    
    static func donateShowWorkoutHistory() async {
        _ = try? await ShowWorkoutHistoryIntent().donate()
    }

    static func donateShowTemplatesList() async {
        _ = try? await ShowTemplatesListIntent().donate()
    }
    
    static func donateLastWorkoutSummary() async {
        _ = try? await LastWorkoutSummaryIntent().donate()
    }
    
    static func donateCreateTemplate() async {
        _ = try? await CreateTemplateIntent().donate()
    }

    static func donateStartLastWorkoutAgain() async {
        _ = try? await StartLastWorkoutAgainIntent().donate()
    }

    static func donateStartWorkoutWithTemplate(template: WorkoutTemplate) async {
        let intent = StartWorkoutWithTemplateIntent()
        intent.template = WorkoutTemplateEntity(template: template)
        _ = try? await intent.donate()
    }

    static func donateStartRestTimer(seconds: Int) async {
        guard seconds > 0 else { return }
        let intent = StartRestTimerIntent()
        intent.duration = Measurement(value: Double(seconds), unit: .seconds)
        _ = try? await intent.donate()
    }

    static func donatePauseRestTimer() async {
        _ = try? await PauseRestTimerIntent().donate()
    }

    static func donateResumeRestTimer() async {
        _ = try? await ResumeRestTimerIntent().donate()
    }

    static func donateStopRestTimer() async {
        _ = try? await StopRestTimerIntent().donate()
    }

    static func donateFinishWorkout() async {
        _ = try? await FinishWorkoutIntent().donate()
    }

    static func donateAddExercises(exercises: [Exercise]) async {
        guard !exercises.isEmpty else { return }
        let intent = AddExercisesIntent()
        intent.exercises = exercises.map(ExerciseEntity.init)
        _ = try? await intent.donate()
    }

    static func donateCancelWorkout() async {
        _ = try? await CancelWorkoutIntent().donate()
    }
}
