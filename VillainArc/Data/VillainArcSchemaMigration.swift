import Foundation
import SwiftData
import HealthKit


// Build this file from the schema list top-to-bottom.
// Keep `models` entries and frozen declarations in the same order.
// When a new persisted model is introduced, append it to the end of the current schema list.

enum VillainArcSchemaV1: VersionedSchema {
    // Public App Store schema for Villain Arc 1.1.1.
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            WorkoutSession.self,
            HealthWorkout.self,
            WeightEntry.self,
            HealthStepsDistance.self,
            HealthEnergy.self,
            TrainingConditionPeriod.self,
            HealthSleepNight.self,
            HealthSleepBlock.self,
            HealthSyncState.self,
            WeightGoal.self,
            StepsGoal.self,
            PreWorkoutContext.self,
            ExercisePerformance.self,
            SetPerformance.self,
            Exercise.self,
            AppSettings.self,
            UserProfile.self,
            ExerciseHistory.self,
            ProgressionPoint.self,
            RepRangePolicy.self,
            RestTimeHistory.self,
            WorkoutPlan.self,
            ExercisePrescription.self,
            SetPrescription.self,
            WorkoutSplit.self,
            WorkoutSplitDay.self,
            SuggestionEvent.self,
            PrescriptionChange.self,
            SuggestionEvaluation.self
        ]
    }

    @Model final class WorkoutSession {
        #Index<WorkoutSession>([\.id], [\.status], [\.startedAt], [\.isHidden], [\.status, \.isHidden, \.startedAt])
        var id: UUID = UUID()
        var title: String = "New Workout"
        var notes: String = ""
        var isHidden: Bool = false
        var status: String = SessionStatus.active.rawValue
        var startedAt: Date = Date()
        var endedAt: Date?
        @Relationship(deleteRule: .cascade, inverse: \PreWorkoutContext.workoutSession) var preWorkoutContext: PreWorkoutContext? = PreWorkoutContext()
        var postEffort: Int = 0
        @Relationship(deleteRule: .nullify, inverse: \WorkoutPlan.workoutSessions) var workoutPlan: WorkoutPlan?
        @Relationship(deleteRule: .cascade, inverse: \ExercisePerformance.workoutSession) var exercises: [ExercisePerformance]? = [ExercisePerformance]()
        @Relationship(deleteRule: .nullify, inverse: \ExercisePerformance.activeInSession) var activeExercise: ExercisePerformance?
        @Relationship(deleteRule: .nullify, inverse: \SuggestionEvent.sessionFrom) var createdSuggestionEvents: [SuggestionEvent]? = [SuggestionEvent]()
        var hasBeenExportedToHealth: Bool = false
        var healthWorkout: HealthWorkout?

        init() {}
    }

    @Model final class HealthWorkout {
        #Index<HealthWorkout>([\.healthWorkoutUUID])
        var healthWorkoutUUID: UUID = UUID()
        var workoutSession: WorkoutSession?
        var startDate: Date = Date()
        var endDate: Date = Date()
        var duration: TimeInterval = 0
        var activityTypeRawValue: UInt = HKWorkoutActivityType.other.rawValue
        var isIndoorWorkout: Bool?
        var averageHeartRateBPM: Double?
        var maximumHeartRateBPM: Double?
        var activeEnergyBurned: Double?
        var restingEnergyBurned: Double?
        var totalDistance: Double?
        var isAvailableInHealthKit: Bool = true

        init() {}
    }

    @Model final class WeightEntry {
        #Index<WeightEntry>([\.date], [\.healthSampleUUID])
        var id: UUID = UUID()
        var date: Date = Date()
        var weight: Double = 0
        var hasBeenExportedToHealth: Bool = false
        var healthSampleUUID: UUID?
        var isAvailableInHealthKit: Bool = false

        init() {}
    }

    @Model final class HealthStepsDistance {
        #Index<HealthStepsDistance>([\.date])
        var date: Date = Date()
        var stepCount: Int = 0
        var distance: Double = 0
        var goalCompletedAt: Date?
        var goalTargetSteps: Int?

        init() {}
    }

    @Model final class HealthEnergy {
        #Index<HealthEnergy>([\.date])
        var date: Date = Date()
        var activeEnergyBurned: Double = 0
        var restingEnergyBurned: Double = 0

        init() {}
    }

    @Model final class TrainingConditionPeriod {
        #Index<TrainingConditionPeriod>([\.startDate], [\.endDate])
        var kind: TrainingConditionKind = TrainingConditionKind.recovering
        var trainingImpact: TrainingImpact = TrainingImpact.contextOnly
        var startDate: Date = Date()
        var endDate: Date?
        var affectedMuscles: [Muscle]?

        init() {}
    }

    @Model final class HealthSleepNight {
        #Index<HealthSleepNight>([\.wakeDay])
        var wakeDay: Date = Date()
        @Relationship(deleteRule: .cascade, inverse: \HealthSleepBlock.night) var blocks: [HealthSleepBlock]? = [HealthSleepBlock]()
        var sleepStart: Date?
        var sleepEnd: Date?
        var allSleepStart: Date?
        var allSleepEnd: Date?
        var timeAsleep: TimeInterval = 0
        var timeInBed: TimeInterval = 0
        var awakeDuration: TimeInterval = 0
        var remDuration: TimeInterval = 0
        var coreDuration: TimeInterval = 0
        var deepDuration: TimeInterval = 0
        var asleepUnspecifiedDuration: TimeInterval = 0
        var napDuration: TimeInterval = 0
        var isAvailableInHealthKit: Bool = true

        init() {}
    }

    @Model final class HealthSleepBlock {
        var startDate: Date = Date()
        var endDate: Date = Date()
        var isPrimary: Bool = false
        var timeAsleep: TimeInterval = 0
        var timeInBed: TimeInterval = 0
        var awakeDuration: TimeInterval = 0
        var remDuration: TimeInterval = 0
        var coreDuration: TimeInterval = 0
        var deepDuration: TimeInterval = 0
        var asleepUnspecifiedDuration: TimeInterval = 0
        var night: HealthSleepNight?

        init() {}
    }

    @Model final class HealthSyncState {
        var stepCountSyncedRangeStart: Date?
        var stepCountSyncedRangeEnd: Date?
        var walkingRunningDistanceSyncedRangeStart: Date?
        var walkingRunningDistanceSyncedRangeEnd: Date?
        var activeEnergyBurnedSyncedRangeStart: Date?
        var activeEnergyBurnedSyncedRangeEnd: Date?
        var restingEnergyBurnedSyncedRangeStart: Date?
        var restingEnergyBurnedSyncedRangeEnd: Date?
        var sleepWakeDaySyncedRangeStart: Date?
        var sleepWakeDaySyncedRangeEnd: Date?
        var doubleGoalLastTriggeredDay: Date?
        var tripleGoalLastTriggeredDay: Date?
        var bestDailyStepsKnown: Int?
        var newHighStepsLastTriggeredDay: Date?

        init() {}
    }

    @Model final class WeightGoal {
        #Index<WeightGoal>([\.startedAt], [\.endedAt])
        var id: UUID = UUID()
        var type: WeightGoalType = WeightGoalType.maintain
        var startedAt: Date = Date()
        var endedAt: Date?
        var endReason: WeightGoalEndReason?
        var startWeight: Double = 0
        var targetWeight: Double = 0
        var targetDate: Date?
        var targetRatePerWeek: Double?

        init() {}
    }

    @Model final class StepsGoal {
        #Index<StepsGoal>([\.startedOnDay])
        var startedOnDay: Date = Date()
        var endedOnDay: Date?
        var targetSteps: Int = 0

        init() {}
    }

    @Model final class PreWorkoutContext {
        var feeling: MoodLevel = MoodLevel.notSet
        var tookPreWorkout: Bool = false
        var workoutSession: WorkoutSession?

        init() {}
    }

    @Model final class ExercisePerformance {
        #Index<ExercisePerformance>([\.catalogID], [\.date], [\.catalogID, \.date])
        var id: UUID = UUID()
        var index: Int = 0
        var date: Date = Date()
        var catalogID: String = ""
        var name: String = ""
        var notes: String = ""
        var musclesTargeted: [Muscle] = []
        var equipmentType: EquipmentType = EquipmentType.bodyweight
        @Relationship(deleteRule: .cascade, inverse: \RepRangePolicy.exercisePerformance) var repRange: RepRangePolicy? = RepRangePolicy()
        var originalTargetSnapshot: ExerciseTargetSnapshot?
        var workoutSession: WorkoutSession?
        var activeInSession: WorkoutSession?
        @Relationship(deleteRule: .nullify, inverse: \ExercisePrescription.activePerformance) var prescription: ExercisePrescription?
        @Relationship(deleteRule: .nullify, inverse: \SuggestionEvent.triggerPerformance) var triggeredSuggestions: [SuggestionEvent]?
        @Relationship(deleteRule: .nullify, inverse: \SuggestionEvaluation.performance) var suggestionEvaluations: [SuggestionEvaluation]?
        @Relationship(deleteRule: .cascade, inverse: \SetPerformance.exercise) var sets: [SetPerformance]? = [SetPerformance]()

        init() {}
    }

    @Model final class SetPerformance {
        var id: UUID = UUID()
        var index: Int = 0
        var originalTargetSetID: UUID?
        var type: ExerciseSetType = ExerciseSetType.working
        var weight: Double = 0
        var reps: Int = 0
        var restSeconds: Int = 0
        var rpe: Int = 0
        var complete: Bool = false
        var completedAt: Date?
        var exercise: ExercisePerformance?
        @Relationship(deleteRule: .nullify, inverse: \SetPrescription.activePerformance) var prescription: SetPrescription?

        init() {}
    }

    @Model final class Exercise {
        #Index<Exercise>([\.catalogID], [\.lastAddedAt], [\.favorite])
        var catalogID: String = ""
        var name: String = ""
        var musclesTargeted: [Muscle] = []
        var aliases: [String] = []
        var lastAddedAt: Date?
        var favorite: Bool = false
        var isCustom: Bool = false
        var searchTokens: [String] = []
        var equipmentType: EquipmentType = EquipmentType.bodyweight
        var suggestionsEnabled: Bool = true
        var preferredWeightChange: Double?

        init() {}
    }

    @Model final class AppSettings {
        var autoStartRestTimer: Bool = true
        var autoCompleteSetAfterRPE: Bool = false
        var promptForPreWorkoutContext: Bool = true
        var promptForPostWorkoutEffort: Bool = true
        var retainPerformancesForLearning: Bool = true
        var keepRemovedHealthData: Bool = true
        var liveActivitiesEnabled: Bool = true
        var stepsNotificationMode: StepsEventNotificationMode = StepsEventNotificationMode.coaching
        var weightUnit: WeightUnit = WeightUnit.systemDefault
        var heightUnit: HeightUnit = HeightUnit.systemDefault
        var distanceUnit: DistanceUnit = DistanceUnit.systemDefault
        var energyUnit: EnergyUnit = EnergyUnit.systemDefault

        init() {}
    }

    @Model final class UserProfile {
        var name: String = ""
        var birthday: Date?
        var gender: UserGender = UserGender.notSet
        var dateJoined: Date = Date()
        var heightCm: Double?

        init() {}
    }

    @Model final class ExerciseHistory {
        #Index<ExerciseHistory>([\.catalogID], [\.lastCompletedAt])
        var catalogID: String = ""
        var lastCompletedAt: Date?
        var totalSessions: Int = 0
        var totalCompletedSets: Int = 0
        var totalCompletedReps: Int = 0
        var cumulativeVolume: Double = 0
        var latestEstimated1RM: Double = 0
        var bestEstimated1RM: Double = 0
        var bestWeight: Double = 0
        var bestVolume: Double = 0
        var bestReps: Int = 0
        @Relationship(deleteRule: .cascade, inverse: \ProgressionPoint.exerciseHistory) var progressionPoints: [ProgressionPoint]? = [ProgressionPoint]()

        init() {}
    }

    @Model final class ProgressionPoint {
        var date: Date = Date()
        var weight: Double = 0
        var totalReps: Int = 0
        var volume: Double = 0
        var estimated1RM: Double = 0
        var exerciseHistory: ExerciseHistory?

        init() {}
    }

    @Model final class RepRangePolicy {
        var activeMode: RepRangeMode = RepRangeMode.notSet
        var lowerRange: Int = 8
        var upperRange: Int = 12
        var targetReps: Int = 8
        var exercisePerformance: ExercisePerformance?
        var exercisePrescription: ExercisePrescription?

        init() {}
    }

    @Model final class RestTimeHistory {
        #Index<RestTimeHistory>([\.seconds], [\.lastUsed])
        var seconds: Int = 0
        var lastUsed: Date = Date()

        init() {}
    }

    @Model final class WorkoutPlan {
        #Index<WorkoutPlan>([\.id], [\.completed], [\.isEditing], [\.lastUsed], [\.completed, \.isEditing, \.lastUsed])
        var id: UUID = UUID()
        var title: String = "New Workout Plan"
        var notes: String = ""
        var favorite: Bool = false
        var completed: Bool = false
        var isEditing: Bool = false
        var lastUsed: Date?
        @Relationship(deleteRule: .cascade, inverse: \ExercisePrescription.workoutPlan) var exercises: [ExercisePrescription]? = [ExercisePrescription]()
        @Relationship(deleteRule: .nullify, inverse: \WorkoutSplitDay.workoutPlan) var splitDays: [WorkoutSplitDay]? = [WorkoutSplitDay]()
        var workoutSessions: [WorkoutSession]? = [WorkoutSession]()

        init() {}
    }

    @Model final class ExercisePrescription {
        #Index<ExercisePrescription>([\.catalogID])
        var id: UUID = UUID()
        var index: Int = 0
        var catalogID: String = ""
        var name: String = ""
        var notes: String = ""
        var musclesTargeted: [Muscle] = []
        var equipmentType: EquipmentType = EquipmentType.bodyweight
        @Relationship(deleteRule: .cascade, inverse: \RepRangePolicy.exercisePrescription) var repRange: RepRangePolicy? = RepRangePolicy()
        var workoutPlan: WorkoutPlan?
        @Relationship(deleteRule: .nullify) var activePerformance: ExercisePerformance?
        @Relationship(deleteRule: .cascade, inverse: \SetPrescription.exercise) var sets: [SetPrescription]? = [SetPrescription]()
        @Relationship(deleteRule: .nullify) var suggestionEvents: [SuggestionEvent]? = [SuggestionEvent]()

        init() {}
    }

    @Model final class SetPrescription {
        var id: UUID = UUID()
        var index: Int = 0
        var type: ExerciseSetType = ExerciseSetType.working
        var targetWeight: Double = 0
        var targetReps: Int = 0
        var targetRest: Int = 0
        var targetRPE: Int = 0
        var exercise: ExercisePrescription?
        @Relationship(deleteRule: .nullify) var activePerformance: SetPerformance?
        @Relationship(deleteRule: .nullify) var suggestionEvents: [SuggestionEvent]? = [SuggestionEvent]()

        init() {}
    }

    @Model final class WorkoutSplit {
        #Index<WorkoutSplit>([\.id], [\.isActive])
        var id: UUID = UUID()
        var title: String = ""
        var mode: SplitMode = SplitMode.weekly
        var isActive: Bool = false
        var weeklySplitOffset: Int = 0
        var rotationCurrentIndex: Int = 0
        var rotationLastUpdatedDate: Date?
        @Relationship(deleteRule: .cascade, inverse: \WorkoutSplitDay.split) var days: [WorkoutSplitDay]? = [WorkoutSplitDay]()

        init() {}
    }

    @Model final class WorkoutSplitDay {
        var name: String = ""
        var index: Int = 0
        var weekday: Int = 1
        var isRestDay: Bool = false
        var targetMuscles: [Muscle] = []
        var split: WorkoutSplit?
        var workoutPlan: WorkoutPlan?

        init() {}
    }

    @Model final class SuggestionEvent {
        #Index<SuggestionEvent>([\.createdAt])
        var id: UUID = UUID()
        var source: SuggestionSource = SuggestionSource.rules
        var category: SuggestionCategory = SuggestionCategory.performance
        var catalogID: String = ""
        @Relationship(deleteRule: .nullify) var sessionFrom: WorkoutSession?
        @Relationship(deleteRule: .nullify, inverse: \ExercisePrescription.suggestionEvents) var targetExercisePrescription: ExercisePrescription?
        @Relationship(deleteRule: .nullify, inverse: \SetPrescription.suggestionEvents) var targetSetPrescription: SetPrescription?
        @Relationship(deleteRule: .nullify) var triggerPerformance: ExercisePerformance?
        var triggerTargetSetID: UUID?
        var decision: Decision = Decision.pending
        var outcome: Outcome = Outcome.pending
        var ruleID: SuggestionRule?
        var decisionReason: DecisionReason?
        var userFeedback: UserFeedback?
        var trainingStyle: TrainingStyle = TrainingStyle.unknown
        var requiredEvaluationCount: Int = 1
        var weightStepUsed: Double?
        @Relationship(deleteRule: .cascade, inverse: \SuggestionEvaluation.event) var evaluations: [SuggestionEvaluation]? = [SuggestionEvaluation]()
        var suggestionConfidence: Double = SuggestionConfidenceTier.moderate.defaultScore
        var createdAt: Date = Date()
        var evaluatedAt: Date?
        var changeReasoning: String?
        var outcomeReason: String?
        @Relationship(deleteRule: .cascade, inverse: \PrescriptionChange.event) var changes: [PrescriptionChange]? = [PrescriptionChange]()

        init() {}
    }

    @Model final class PrescriptionChange {
        var id: UUID = UUID()
        @Relationship(deleteRule: .nullify) var event: SuggestionEvent?
        var changeType: ChangeType = ChangeType.increaseWeight
        var previousValue: Double = 0
        var newValue: Double = 0

        init() {}
    }

    @Model final class SuggestionEvaluation {
        var id: UUID = UUID()
        @Relationship(deleteRule: .nullify) var event: SuggestionEvent?
        @Relationship(deleteRule: .nullify) var performance: ExercisePerformance?
        var sourceWorkoutSessionID: UUID = UUID()
        var partialOutcome: Outcome = Outcome.pending
        var confidence: Double = 0
        var reason: String = ""
        var evaluatedAt: Date = Date()

        init() {}
    }
}

enum VillainArcSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            WorkoutSession.self,
            HealthWorkout.self,
            WeightEntry.self,
            HealthStepsDistance.self,
            HealthEnergy.self,
            TrainingConditionPeriod.self,
            HealthSleepNight.self,
            HealthSleepBlock.self,
            HealthSyncState.self,
            WeightGoal.self,
            StepsGoal.self,
            PreWorkoutContext.self,
            ExercisePerformance.self,
            SetPerformance.self,
            Exercise.self,
            AppSettings.self,
            UserProfile.self,
            ExerciseHistory.self,
            ProgressionPoint.self,
            RepRangePolicy.self,
            RestTimeHistory.self,
            WorkoutPlan.self,
            ExercisePrescription.self,
            SetPrescription.self,
            WorkoutSplit.self,
            WorkoutSplitDay.self,
            SuggestionEvent.self,
            PrescriptionChange.self,
            SuggestionEvaluation.self,
            TrainingGoal.self,
            SleepGoal.self
        ]
    }

    @Model final class WorkoutSession {
        #Index<WorkoutSession>([\.id], [\.status], [\.startedAt], [\.isHidden], [\.status, \.isHidden, \.startedAt])
        var id: UUID = UUID()
        var title: String = "New Workout"
        var notes: String = ""
        var isHidden: Bool = false
        var status: String = SessionStatus.active.rawValue
        var startedAt: Date = Date()
        var endedAt: Date?
        @Relationship(deleteRule: .cascade, inverse: \PreWorkoutContext.workoutSession) var preWorkoutContext: PreWorkoutContext? = PreWorkoutContext()
        var postEffort: Int = 0
        @Relationship(deleteRule: .nullify, inverse: \WorkoutPlan.workoutSessions) var workoutPlan: WorkoutPlan?
        @Relationship(deleteRule: .cascade, inverse: \ExercisePerformance.workoutSession) var exercises: [ExercisePerformance]? = [ExercisePerformance]()
        @Relationship(deleteRule: .nullify, inverse: \ExercisePerformance.activeInSession) var activeExercise: ExercisePerformance?
        @Relationship(deleteRule: .nullify, inverse: \SuggestionEvent.sessionFrom) var createdSuggestionEvents: [SuggestionEvent]? = [SuggestionEvent]()
        var hasBeenExportedToHealth: Bool = false
        var healthWorkout: HealthWorkout?

        init() {}
    }

    @Model final class HealthWorkout {
        #Index<HealthWorkout>([\.healthWorkoutUUID])
        var healthWorkoutUUID: UUID = UUID()
        var workoutSession: WorkoutSession?
        var startDate: Date = Date()
        var endDate: Date = Date()
        var duration: TimeInterval = 0
        var activityTypeRawValue: UInt = HKWorkoutActivityType.other.rawValue
        var isIndoorWorkout: Bool?
        var averageHeartRateBPM: Double?
        var maximumHeartRateBPM: Double?
        var activeEnergyBurned: Double?
        var restingEnergyBurned: Double?
        var totalDistance: Double?
        var isAvailableInHealthKit: Bool = true

        init() {}
    }

    @Model final class WeightEntry {
        #Index<WeightEntry>([\.date], [\.healthSampleUUID])
        var id: UUID = UUID()
        var date: Date = Date()
        var weight: Double = 0
        var hasBeenExportedToHealth: Bool = false
        var healthSampleUUID: UUID?
        var isAvailableInHealthKit: Bool = false

        init() {}
    }

    @Model final class HealthStepsDistance {
        #Index<HealthStepsDistance>([\.date])
        var date: Date = Date()
        var stepCount: Int = 0
        var distance: Double = 0
        var goalCompletedAt: Date?
        var goalTargetSteps: Int?

        init() {}
    }

    @Model final class HealthEnergy {
        #Index<HealthEnergy>([\.date])
        var date: Date = Date()
        var activeEnergyBurned: Double = 0
        var restingEnergyBurned: Double = 0

        init() {}
    }

    @Model final class TrainingConditionPeriod {
        #Index<TrainingConditionPeriod>([\.startDate], [\.endDate])
        var kind: TrainingConditionKind = TrainingConditionKind.recovering
        var trainingImpact: TrainingImpact = TrainingImpact.contextOnly
        var startDate: Date = Date()
        var endDate: Date?
        var affectedMuscles: [Muscle]?

        init() {}
    }

    @Model final class HealthSleepNight {
        #Index<HealthSleepNight>([\.wakeDay])
        var wakeDay: Date = Date()
        @Relationship(deleteRule: .cascade, inverse: \HealthSleepBlock.night) var blocks: [HealthSleepBlock]? = [HealthSleepBlock]()
        var sleepStart: Date?
        var sleepEnd: Date?
        var allSleepStart: Date?
        var allSleepEnd: Date?
        var timeAsleep: TimeInterval = 0
        var timeInBed: TimeInterval = 0
        var awakeDuration: TimeInterval = 0
        var remDuration: TimeInterval = 0
        var coreDuration: TimeInterval = 0
        var deepDuration: TimeInterval = 0
        var asleepUnspecifiedDuration: TimeInterval = 0
        var napDuration: TimeInterval = 0
        var isAvailableInHealthKit: Bool = true
        var calendar = Calendar(identifier: .gregorian)

        init() {}
    }

    @Model final class HealthSleepBlock {
        var startDate: Date = Date()
        var endDate: Date = Date()
        var isPrimary: Bool = false
        var timeAsleep: TimeInterval = 0
        var timeInBed: TimeInterval = 0
        var awakeDuration: TimeInterval = 0
        var remDuration: TimeInterval = 0
        var coreDuration: TimeInterval = 0
        var deepDuration: TimeInterval = 0
        var asleepUnspecifiedDuration: TimeInterval = 0
        var night: HealthSleepNight?

        init() {}
    }

    @Model final class HealthSyncState {
        var stepCountSyncedRangeStart: Date?
        var stepCountSyncedRangeEnd: Date?
        var walkingRunningDistanceSyncedRangeStart: Date?
        var walkingRunningDistanceSyncedRangeEnd: Date?
        var activeEnergyBurnedSyncedRangeStart: Date?
        var activeEnergyBurnedSyncedRangeEnd: Date?
        var restingEnergyBurnedSyncedRangeStart: Date?
        var restingEnergyBurnedSyncedRangeEnd: Date?
        var sleepWakeDaySyncedRangeStart: Date?
        var sleepWakeDaySyncedRangeEnd: Date?
        var doubleGoalLastTriggeredDay: Date?
        var tripleGoalLastTriggeredDay: Date?
        var bestDailyStepsKnown: Int?
        var newHighStepsLastTriggeredDay: Date?
        var sleepGoalLastNotifiedWakeDay: Date?

        init() {}
    }

    @Model final class WeightGoal {
        #Index<WeightGoal>([\.startedAt], [\.endedAt])
        var id: UUID = UUID()
        var type: WeightGoalType = WeightGoalType.maintain
        var startedAt: Date = Date()
        var endedAt: Date?
        var endReason: WeightGoalEndReason?
        var startWeight: Double = 0
        var targetWeight: Double = 0
        var targetDate: Date?
        var targetRatePerWeek: Double?

        init() {}
    }

    @Model final class StepsGoal {
        #Index<StepsGoal>([\.startedOnDay])
        var startedOnDay: Date = Date()
        var endedOnDay: Date?
        var targetSteps: Int = 0

        init() {}
    }

    @Model final class PreWorkoutContext {
        var feeling: MoodLevel = MoodLevel.notSet
        var tookPreWorkout: Bool = false
        var workoutSession: WorkoutSession?

        init() {}
    }

    @Model final class ExercisePerformance {
        #Index<ExercisePerformance>([\.catalogID], [\.date], [\.catalogID, \.date])
        var id: UUID = UUID()
        var index: Int = 0
        var date: Date = Date()
        var catalogID: String = ""
        var name: String = ""
        var notes: String = ""
        var musclesTargeted: [Muscle] = []
        var equipmentType: EquipmentType = EquipmentType.bodyweight
        @Relationship(deleteRule: .cascade, inverse: \RepRangePolicy.exercisePerformance) var repRange: RepRangePolicy? = RepRangePolicy()
        var originalTargetSnapshot: ExerciseTargetSnapshot?
        var workoutSession: WorkoutSession?
        var activeInSession: WorkoutSession?
        @Relationship(inverse: \ExercisePrescription.activePerformance) var prescription: ExercisePrescription?
        @Relationship(inverse: \SuggestionEvent.triggerPerformance) var triggeredSuggestions: [SuggestionEvent]?
        @Relationship(inverse: \SuggestionEvaluation.performance) var suggestionEvaluations: [SuggestionEvaluation]?
        @Relationship(deleteRule: .cascade, inverse: \SetPerformance.exercise) var sets: [SetPerformance]? = [SetPerformance]()

        init() {}
    }

    @Model final class SetPerformance {
        var id: UUID = UUID()
        var index: Int = 0
        var originalTargetSetID: UUID?
        var type: ExerciseSetType = ExerciseSetType.working
        var weight: Double = 0
        var reps: Int = 0
        var restSeconds: Int = 0
        var rpe: Int = 0
        var complete: Bool = false
        var completedAt: Date?
        var exercise: ExercisePerformance?
        @Relationship(inverse: \SetPrescription.activePerformance) var prescription: SetPrescription?

        init() {}
    }

    @Model final class Exercise {
        #Index<Exercise>([\.catalogID], [\.lastAddedAt], [\.favorite])
        var catalogID: String = ""
        var name: String = ""
        var musclesTargeted: [Muscle] = []
        var aliases: [String] = []
        var lastAddedAt: Date? = nil
        var favorite: Bool = false
        var isCustom: Bool = false
        var searchTokens: [String] = []
        var equipmentType: EquipmentType = EquipmentType.bodyweight
        var suggestionsEnabled: Bool = true
        var preferredWeightChange: Double?

        init() {}
    }

    @Model final class AppSettings {
        var autoStartRestTimer: Bool = true
        var autoCompleteSetAfterRPE: Bool = false
        var promptForPreWorkoutContext: Bool = false
        var promptForPostWorkoutEffort: Bool = true
        var retainPerformancesForLearning: Bool = true
        var keepRemovedHealthData: Bool = true
        var liveActivitiesEnabled: Bool = true
        var stepsNotificationMode: StepsEventNotificationMode = StepsEventNotificationMode.coaching
        var sleepNotificationMode: SleepNotificationMode = SleepNotificationMode.goalOnly
        var appearanceMode: AppAppearanceMode = AppAppearanceMode.system
        var weightUnit: WeightUnit = WeightUnit.systemDefault
        var heightUnit: HeightUnit = HeightUnit.systemDefault
        var distanceUnit: DistanceUnit = DistanceUnit.systemDefault
        var energyUnit: EnergyUnit = EnergyUnit.systemDefault

        init() {}
    }

    @Model final class UserProfile {
        var name: String = ""
        var birthday: Date?
        var gender: UserGender = UserGender.notSet
        var dateJoined: Date = Date()
        var heightCm: Double?
        var fitnessLevel: FitnessLevel?
        var fitnessLevelSetAt: Date?

        init() {}
    }

    @Model final class ExerciseHistory {
        #Index<ExerciseHistory>([\.catalogID], [\.lastCompletedAt])
        var catalogID: String = ""
        var lastCompletedAt: Date? = nil
        var totalSessions: Int = 0
        var totalCompletedSets: Int = 0
        var totalCompletedReps: Int = 0
        var cumulativeVolume: Double = 0
        var latestEstimated1RM: Double = 0
        var bestEstimated1RM: Double = 0
        var bestWeight: Double = 0
        var bestVolume: Double = 0
        var bestReps: Int = 0
        @Relationship(deleteRule: .cascade, inverse: \ProgressionPoint.exerciseHistory) var progressionPoints: [ProgressionPoint]? = [ProgressionPoint]()

        init() {}
    }

    @Model final class ProgressionPoint {
        var date: Date = Date()
        var weight: Double = 0
        var totalReps: Int = 0
        var volume: Double = 0
        var estimated1RM: Double = 0
        var exerciseHistory: ExerciseHistory?

        init() {}
    }

    @Model final class RepRangePolicy {
        var activeMode: RepRangeMode = RepRangeMode.notSet
        var lowerRange: Int = 8
        var upperRange: Int = 12
        var targetReps: Int = 8
        var exercisePerformance: ExercisePerformance?
        var exercisePrescription: ExercisePrescription?

        init() {}
    }

    @Model final class RestTimeHistory {
        #Index<RestTimeHistory>([\.seconds], [\.lastUsed])
        var seconds: Int = 0
        var lastUsed: Date = Date()

        init() {}
    }

    @Model final class WorkoutPlan {
        #Index<WorkoutPlan>([\.id], [\.completed], [\.isEditing], [\.lastUsed], [\.completed, \.isEditing, \.lastUsed])
        var id: UUID = UUID()
        var title: String = "New Workout Plan"
        var notes: String = ""
        var favorite: Bool = false
        var completed: Bool = false
        var isEditing: Bool = false
        var lastUsed: Date?
        @Relationship(deleteRule: .cascade, inverse: \ExercisePrescription.workoutPlan) var exercises: [ExercisePrescription]? = [ExercisePrescription]()
        var splitDays: [WorkoutSplitDay]? = [WorkoutSplitDay]()
        var workoutSessions: [WorkoutSession]? = [WorkoutSession]()

        init() {}
    }

    @Model final class ExercisePrescription {
        #Index<ExercisePrescription>([\.catalogID])
        var id: UUID = UUID()
        var index: Int = 0
        var catalogID: String = ""
        var name: String = ""
        var notes: String = ""
        var musclesTargeted: [Muscle] = []
        var equipmentType: EquipmentType = EquipmentType.bodyweight
        @Relationship(deleteRule: .cascade, inverse: \RepRangePolicy.exercisePrescription) var repRange: RepRangePolicy? = RepRangePolicy()
        var workoutPlan: WorkoutPlan?
        var activePerformance: ExercisePerformance?
        @Relationship(deleteRule: .cascade, inverse: \SetPrescription.exercise) var sets: [SetPrescription]? = [SetPrescription]()
        var suggestionEvents: [SuggestionEvent]? = [SuggestionEvent]()

        init() {}
    }

    @Model final class SetPrescription {
        var id: UUID = UUID()
        var index: Int = 0
        var type: ExerciseSetType = ExerciseSetType.working
        var targetWeight: Double = 0
        var targetReps: Int = 0
        var targetRest: Int = 0
        var targetRPE: Int = 0
        var exercise: ExercisePrescription?
        var activePerformance: SetPerformance?
        var suggestionEvents: [SuggestionEvent]? = [SuggestionEvent]()

        init() {}
    }

    @Model final class WorkoutSplit {
        #Index<WorkoutSplit>([\.id], [\.isActive])
        var id: UUID = UUID()
        var title: String = ""
        var mode: SplitMode = SplitMode.weekly
        var isActive: Bool = false
        var weeklySplitOffset: Int = 0
        var rotationCurrentIndex: Int = 0
        var rotationLastUpdatedDate: Date? = nil
        @Relationship(deleteRule: .cascade, inverse: \WorkoutSplitDay.split) var days: [WorkoutSplitDay]? = [WorkoutSplitDay]()

        init() {}
    }

    @Model final class WorkoutSplitDay {
        var name: String = ""
        var index: Int = 0
        var weekday: Int = 1
        var isRestDay: Bool = false
        var targetMuscles: [Muscle] = []
        var split: WorkoutSplit?
        var workoutPlan: WorkoutPlan?

        init() {}
    }

    @Model final class SuggestionEvent {
        #Index<SuggestionEvent>([\.createdAt])
        var id: UUID = UUID()
        var source: SuggestionSource = SuggestionSource.rules
        var category: SuggestionCategory = SuggestionCategory.performance
        var catalogID: String = ""
        var sessionFrom: WorkoutSession?
        @Relationship(inverse: \ExercisePrescription.suggestionEvents) var targetExercisePrescription: ExercisePrescription?
        @Relationship(inverse: \SetPrescription.suggestionEvents) var targetSetPrescription: SetPrescription?
        var triggerPerformance: ExercisePerformance?
        var triggerTargetSetID: UUID?
        var decision: Decision = Decision.pending
        var outcome: Outcome = Outcome.pending
        var ruleID: SuggestionRule?
        var decisionReason: DecisionReason?
        var userFeedback: UserFeedback?
        var trainingStyle: TrainingStyle = TrainingStyle.unknown
        var requiredEvaluationCount: Int = 1
        var weightStepUsed: Double?
        @Relationship(deleteRule: .cascade, inverse: \SuggestionEvaluation.event) var evaluations: [SuggestionEvaluation]? = [SuggestionEvaluation]()
        var suggestionConfidence: Double = SuggestionConfidenceTier.moderate.defaultScore
        var createdAt: Date = Date()
        var evaluatedAt: Date?
        var changeReasoning: String?
        var outcomeReason: String?
        @Relationship(deleteRule: .cascade, inverse: \PrescriptionChange.event) var changes: [PrescriptionChange]? = [PrescriptionChange]()

        init() {}
    }

    @Model final class PrescriptionChange {
        var id: UUID = UUID()
        var event: SuggestionEvent?
        var changeType: ChangeType = ChangeType.increaseWeight
        var previousValue: Double = 0
        var newValue: Double = 0

        init() {}
    }

    @Model final class SuggestionEvaluation {
        var id: UUID = UUID()
        var event: SuggestionEvent?
        var performance: ExercisePerformance?
        var sourceWorkoutSessionID: UUID = UUID()
        var partialOutcome: Outcome = Outcome.pending
        var confidence: Double = 0
        var reason: String = ""
        var evaluatedAt: Date = Date()

        init() {}
    }

    @Model final class TrainingGoal {
        #Index<TrainingGoal>([\.startedOnDay])
        var startedOnDay: Date = Date()
        var endedOnDay: Date?
        var kind: TrainingGoalKind = TrainingGoalKind.generalTraining

        init() {}
    }

    @Model final class SleepGoal {
        #Index<SleepGoal>([\.startedOnDay])
        var startedOnDay: Date = Date()
        var endedOnDay: Date?
        var targetSleepDuration: TimeInterval = 0

        init() {}
    }
}

enum VillainArcSchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            WorkoutSession.self,
            HealthWorkout.self,
            WeightEntry.self,
            HealthStepsDistance.self,
            HealthEnergy.self,
            TrainingConditionPeriod.self,
            HealthSleepNight.self,
            HealthSleepBlock.self,
            HealthSyncState.self,
            WeightGoal.self,
            StepsGoal.self,
            PreWorkoutContext.self,
            ExercisePerformance.self,
            SetPerformance.self,
            Exercise.self,
            AppSettings.self,
            UserProfile.self,
            ExerciseHistory.self,
            ProgressionPoint.self,
            RepRangePolicy.self,
            RestTimeHistory.self,
            WorkoutPlan.self,
            ExercisePrescription.self,
            SetPrescription.self,
            WorkoutSplit.self,
            WorkoutSplitDay.self,
            SuggestionEvent.self,
            PrescriptionChange.self,
            SuggestionEvaluation.self,
            TrainingGoal.self,
            SleepGoal.self
        ]
    }
}

enum VillainArcSchemaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [
            VillainArcSchemaV1.self,
            VillainArcSchemaV2.self,
            VillainArcSchemaV3.self
        ]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2toV3]
    }

    static let migrateV1toV2 = MigrationStage.custom(fromVersion: VillainArcSchemaV1.self, toVersion: VillainArcSchemaV2.self, willMigrate: nil) { context in
        let settings = try context.fetch(FetchDescriptor<VillainArcSchemaV2.AppSettings>())
        for setting in settings {
            setting.appearanceMode = .system
            setting.sleepNotificationMode = .goalOnly
        }
        try context.save()
    }

    static let migrateV2toV3 = MigrationStage.custom(fromVersion: VillainArcSchemaV2.self, toVersion: VillainArcSchemaV3.self, willMigrate: nil) { context in
        let settings = try context.fetch(FetchDescriptor<AppSettings>())
        for setting in settings {
            setting.autoFillPlanTargets = true
        }

        let syncStates = try context.fetch(FetchDescriptor<HealthSyncState>())
        for syncState in syncStates {
            syncState.weeklyCoachingLastDeliveredWeekStart = nil
        }

        try context.save()
    }
}
