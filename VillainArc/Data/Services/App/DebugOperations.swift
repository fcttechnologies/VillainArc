#if DEBUG
import SwiftData
import Foundation
import HealthKit

enum DebugOperations {
    enum HealthSampleScenario: String, CaseIterable, Identifiable {
        case rareFastCut
        case everyOtherWeek
        case everyCoupleDays
        case daily

        var id: String { rawValue }

        var title: String {
            switch self {
            case .rareFastCut:
                return "Rare Logs, Fast Cut"
            case .everyOtherWeek:
                return "Every Other Week"
            case .everyCoupleDays:
                return "Every Couple Days"
            case .daily:
                return "Daily Trend"
            }
        }
    }

    /// Everything a capture needs, in one action: the singletons a ready app holds, workout
    /// history, and 35 days of Health data. Each stage rebuilds the rows it owns, so the result is
    /// the same whatever the demo store was already holding.
    static func seedDemoData(in context: ModelContext) throws {
        AppLog.info("Debug demo data seed started.")
        try seedBaseline(in: context)
        try seedWorkoutData(in: context)
        try seedHealthSamples(scenario: .daily, in: context)
        AppLog.info("Debug demo data seed completed.")
    }

    static func resyncExerciseCatalog() async throws {
        AppLog.info("Debug exercise catalog resync started.")
        SharedModelContainer.sharedDefaults.removeObject(forKey: DataManager.exerciseCatalogVersionKey)
        _ = try await DataManager.seedExercisesForOnboarding()
        AppLog.info("Debug exercise catalog resync completed.")
    }

    static func resyncHealthData() async {
        guard HealthAuthorizationManager.isHealthDataAvailable else {
            AppLog.info("Debug Health resync skipped because HealthKit is unavailable.")
            return
        }

        AppLog.info("Debug Health resync started.")
        HealthStoreUpdateCoordinator.shared.installObserversIfNeeded()
        await HealthStoreUpdateCoordinator.shared.refreshBackgroundDeliveryRegistration()
        await HealthStoreUpdateCoordinator.shared.syncNow()
        HealthMetricWidgetReloader.reloadAllHealthMetrics()
        await WeeklyHealthCoachingCoordinator.shared.refreshSchedule()
        AppLog.info("Debug Health resync completed.")
    }

    static func reindexSpotlight() {
        SpotlightIndexer.reindexAll(context: SharedModelContainer.container.mainContext)
        AppLog.info("Debug Spotlight reindex queued.")
    }

    /// Pick a scenario, get exactly that scenario's 35 days: the window is rebuilt every time, so
    /// switching scenarios switches the data rather than layering onto it.
    static func seedHealthSamples(scenario: HealthSampleScenario, in context: ModelContext) throws {
        AppLog.info("Debug health sample seed started: \(scenario.rawValue)")

        try deleteHealthSampleModels(in: context)
        try seedBaseline(in: context)

        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: .now)
        let startDay = calendar.date(byAdding: .day, value: -34, to: today) ?? today
        let startWeight = startingWeight(for: scenario)

        seedWeightGoal(for: scenario, startDay: startDay, startWeight: startWeight, context: context)

        for offset in 0..<35 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDay) else { continue }
            let progress = Double(offset) / 34.0
            seedDailyHealthRows(on: day, offset: offset, progress: progress, scenario: scenario, context: context)

            if shouldLogWeight(onOffset: offset, scenario: scenario) {
                let weight = sampleWeight(startWeight: startWeight, progress: progress, offset: offset, scenario: scenario)
                context.insert(WeightEntry(date: day.addingTimeInterval(8 * 3600), weight: weight, hasBeenExportedToHealth: true, healthSampleUUID: UUID(), isAvailableInHealthKit: true))
            }
        }

        try context.save()
        HealthMetricWidgetReloader.reloadAllHealthMetrics()
        AppLog.info("Debug health sample seed completed: \(scenario.rawValue)")
    }

    /// A plan and three completed sessions. Rebuilds what it owns, so the button is pressed
    /// repeatedly without stacking a fourth, fifth and sixth copy of the same week.
    static func seedWorkoutData(in context: ModelContext) throws {
        AppLog.info("Debug workout data seed started.")

        try seedBaseline(in: context)
        try deleteWorkoutModels(in: context)

        let catalogIDs = ["barbell_bench_press", "barbell_squat", "deadlift", "barbell_overhead_press", "pull_ups"]
        var planExercises: [Exercise] = []
        for id in catalogIDs {
            let existing = try context.fetch(Exercise.withCatalogID(id))
            if let ex = existing.first {
                planExercises.append(ex)
            } else if let item = ExerciseCatalog.all.first(where: { $0.id == id }) {
                let ex = Exercise(from: item)
                context.insert(ex)
                planExercises.append(ex)
            }
        }

        let plan = WorkoutPlan()
        plan.title = "Push Pull Legs"
        plan.completed = true
        context.insert(plan)
        for exercise in planExercises {
            plan.addExercise(exercise)
        }

        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: .now)
        let sessionOffsets = [-21, -14, -7]
        let baseWeights: [String: Double] = [
            "barbell_bench_press": 80,
            "barbell_squat": 100,
            "deadlift": 120,
            "barbell_overhead_press": 55,
            "pull_ups": 0
        ]

        for (sessionIndex, dayOffset) in sessionOffsets.enumerated() {
            guard let sessionDay = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            let sessionStart = sessionDay.addingTimeInterval(18 * 3600)
            let sessionEnd = sessionStart.addingTimeInterval(4500)

            let session = WorkoutSession(from: plan)
            session.startedAt = sessionStart
            session.endedAt = sessionEnd
            session.status = SessionStatus.done.rawValue
            context.insert(session)

            for performance in session.sortedExercises {
                let catalogID = performance.catalogID
                let base = baseWeights[catalogID] ?? 60.0
                let progressionBonus = Double(sessionIndex) * 2.5
                performance.sets = []
                for setIndex in 0..<3 {
                    let weight = base + progressionBonus + Double(setIndex) * 2.5
                    let reps = max(5, 8 - setIndex)
                    let completedAt = sessionStart.addingTimeInterval(Double((sessionIndex * 3 + setIndex)) * 180 + 60)
                    let set = SetPerformance(
                        exercise: performance,
                        setType: .working,
                        weight: weight,
                        reps: reps,
                        restSeconds: 120,
                        index: setIndex,
                        complete: true,
                        completedAt: completedAt
                    )
                    performance.sets?.append(set)
                }
                performance.syncDateToLatestCompletedSet()
            }

            ExerciseHistoryUpdater.updateHistoriesForCompletedWorkout(session, context: context)
        }

        for exercise in planExercises {
            exercise.updateLastAddedAt()
        }

        try context.save()
        AppLog.info("Debug workout data seed completed.")
    }

    static func seedExerciseHistory(for exercise: Exercise, in context: ModelContext) throws {
        AppLog.info("Debug exercise history seed started: \(exercise.catalogID)")

        let existing = try context.fetch(ExercisePerformance.matching(catalogID: exercise.catalogID, includingHidden: true))
        for performance in existing where performance.workoutSession == nil {
            context.delete(performance)
        }

        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: .now)
        for index in 0..<12 {
            guard let day = calendar.date(byAdding: .day, value: -(33 - index * 3), to: today) else { continue }
            let performance = ExercisePerformance(exercise: exercise, date: day.addingTimeInterval(18 * 3600), notes: "Debug standalone import")
            performance.sets = []
            let baseWeight = 60.0 + Double(index) * 1.75
            let reps = max(5, 10 - index / 4)
            for setIndex in 0..<3 {
                let completedAt = performance.date.addingTimeInterval(Double(setIndex) * 180)
                let set = SetPerformance(exercise: performance, setType: .working, weight: baseWeight + Double(setIndex) * 2.5, reps: reps, restSeconds: 120, index: setIndex, complete: true, completedAt: completedAt)
                set.rpe = min(9, 6 + index / 4)
                performance.sets?.append(set)
            }
            performance.syncDateToLatestCompletedSet()
            context.insert(performance)
        }

        ExerciseHistoryUpdater.updateHistory(for: exercise.catalogID, context: context, save: false)
        try context.save()
        AppLog.info("Debug exercise history seed completed: \(exercise.catalogID)")
    }

    /// The singletons a demo store needs before anything else can be written into it: the settings
    /// and health-sync rows every screen reads, and the profile and training goal the app treats
    /// as always present.
    static func seedBaseline(in context: ModelContext) throws {
        _ = try SystemState.ensureAppSettings(context: context)
        _ = try SystemState.ensureHealthSyncState(context: context)

        let profile = try SystemState.ensureUserProfile(context: context)
        profile.gender = .other
        profile.heightCm = 175
        profile.fitnessLevel = .intermediate
        profile.fitnessLevelSetAt = .now

        if try context.fetch(TrainingGoal.active).first == nil {
            context.insert(TrainingGoal(kind: .generalTraining))
        }

        try context.save()
    }

    private static func deleteWorkoutModels(in context: ModelContext) throws {
        _ = try deleteAll(SetPerformance.self, in: context)
        _ = try deleteAll(ExercisePerformance.self, in: context)
        _ = try deleteAll(WorkoutSession.self, in: context)
        _ = try deleteAll(SetPrescription.self, in: context)
        _ = try deleteAll(ExercisePrescription.self, in: context)
        _ = try deleteAll(WorkoutPlan.self, in: context)
        _ = try deleteAll(ExerciseHistory.self, in: context)
        _ = try deleteAll(ProgressionPoint.self, in: context)
        try context.save()
    }

    private static func deleteHealthSampleModels(in context: ModelContext) throws {
        _ = try deleteAll(WeightEntry.self, in: context)
        _ = try deleteAll(WeightGoal.self, in: context)
        _ = try deleteAll(HealthStepsDistance.self, in: context)
        _ = try deleteAll(HealthEnergy.self, in: context)
        _ = try deleteAll(HealthSleepBlock.self, in: context)
        _ = try deleteAll(HealthSleepNight.self, in: context)
        _ = try deleteAll(HealthHeart.self, in: context)
        _ = try deleteAll(HealthRespiratoryRate.self, in: context)
        _ = try deleteAll(HealthWristTemperature.self, in: context)
        _ = try deleteAll(HydrationEntry.self, in: context)
    }

    private static func startingWeight(for scenario: HealthSampleScenario) -> Double {
        switch scenario {
        case .rareFastCut:
            return 98
        case .everyOtherWeek:
            return 87
        case .everyCoupleDays:
            return 82
        case .daily:
            return 76
        }
    }

    private static func shouldLogWeight(onOffset offset: Int, scenario: HealthSampleScenario) -> Bool {
        switch scenario {
        case .rareFastCut:
            return [0, 11, 23, 34].contains(offset)
        case .everyOtherWeek:
            return offset % 14 == 0 || offset == 34
        case .everyCoupleDays:
            return offset % 3 == 0 || offset == 34
        case .daily:
            return true
        }
    }

    private static func sampleWeight(startWeight: Double, progress: Double, offset: Int, scenario: HealthSampleScenario) -> Double {
        let wave = sin(Double(offset) * 0.7) * 0.25
        switch scenario {
        case .rareFastCut:
            return startWeight - 7.8 * progress + wave
        case .everyOtherWeek:
            return startWeight - 1.8 * progress + wave * 1.8
        case .everyCoupleDays:
            return startWeight + 1.6 * progress + wave
        case .daily:
            return startWeight - 3.2 * progress + wave * 0.6
        }
    }

    private static func seedWeightGoal(for scenario: HealthSampleScenario, startDay: Date, startWeight: Double, context: ModelContext) {
        let targetDate = Calendar.autoupdatingCurrent.date(byAdding: .day, value: 60, to: startDay)
        let targetWeight: Double
        let type: WeightGoalType
        switch scenario {
        case .rareFastCut:
            type = .cut
            targetWeight = startWeight - 12
        case .everyOtherWeek, .daily:
            type = .cut
            targetWeight = startWeight - 6
        case .everyCoupleDays:
            type = .bulk
            targetWeight = startWeight + 4
        }
        let goal = WeightGoal(type: type, startWeight: startWeight, targetWeight: targetWeight, targetDate: targetDate, targetRatePerWeek: nil)
        goal.startedAt = startDay
        context.insert(goal)
    }

    private static func seedDailyHealthRows(on day: Date, offset: Int, progress: Double, scenario: HealthSampleScenario, context: ModelContext) {
        let highActivity = scenario == .rareFastCut || scenario == .daily
        let steps = Int((highActivity ? 10500 : 6200) + sin(Double(offset) * 0.45) * 1800 + progress * (highActivity ? 2200 : 800))
        let activeEnergy = Double(max(180, steps / 18))
        let restingEnergy = 1580.0 + sin(Double(offset) * 0.2) * 45
        context.insert(HealthStepsDistance(date: day, stepCount: max(1200, steps), distance: Double(max(1200, steps)) * 0.78))
        context.insert(HealthEnergy(date: day, activeEnergyBurned: activeEnergy, restingEnergyBurned: restingEnergy))

        let hydrationBase = highActivity ? 2950.0 : 2100.0
        for entryIndex in 0..<3 {
            context.insert(HydrationEntry(date: day.addingTimeInterval(Double(9 + entryIndex * 4) * 3600), volume: hydrationBase / 3 + Double((offset + entryIndex) % 3) * 70, hasBeenExportedToHealth: true, healthSampleUUID: UUID(), isAvailableInHealthKit: true))
        }

        let night = HealthSleepNight(wakeDay: day)
        let asleep = (highActivity ? 7.4 : 6.5) * 3600 + sin(Double(offset) * 0.35) * 1800
        let inBed = asleep + 35 * 60
        let endDate = day.addingTimeInterval(7.5 * 3600)
        let startDate = endDate.addingTimeInterval(-inBed)
        night.sleepStart = startDate
        night.sleepEnd = endDate
        night.allSleepStart = startDate
        night.allSleepEnd = endDate
        night.timeAsleep = asleep
        night.timeInBed = inBed
        night.awakeDuration = max(10 * 60, inBed - asleep)
        night.remDuration = asleep * 0.22
        night.coreDuration = asleep * 0.53
        night.deepDuration = asleep * 0.18
        night.asleepUnspecifiedDuration = asleep - night.remDuration - night.coreDuration - night.deepDuration
        night.isAvailableInHealthKit = true
        night.blocks = [HealthSleepBlock(startDate: startDate, endDate: endDate, isPrimary: true, timeAsleep: asleep, timeInBed: inBed, awakeDuration: night.awakeDuration, remDuration: night.remDuration, coreDuration: night.coreDuration, deepDuration: night.deepDuration, asleepUnspecifiedDuration: night.asleepUnspecifiedDuration, night: night)]
        context.insert(night)

        let heart = HealthHeart(date: day)
        heart.minHeartRate = 49 + sin(Double(offset) * 0.3) * 2
        heart.maxHeartRate = highActivity ? 172 + sin(Double(offset) * 0.5) * 8 : 148 + sin(Double(offset) * 0.5) * 6
        heart.restingHeartRate = (highActivity ? 61 : 68) - progress * (highActivity ? 5 : 1) + sin(Double(offset) * 0.25)
        heart.walkingHeartRateAverage = (highActivity ? 93 : 101) - progress * 3
        heart.heartRateVariabilitySDNN = (highActivity ? 48 : 35) + progress * (highActivity ? 8 : 2) + sin(Double(offset) * 0.4) * 3
        context.insert(heart)

        let respiratory = HealthRespiratoryRate(date: day)
        respiratory.minRate = 12.0 + sin(Double(offset) * 0.2) * 0.4
        respiratory.maxRate = 18.0 + sin(Double(offset) * 0.33) * 0.8
        context.insert(respiratory)
        context.insert(HealthWristTemperature(date: day, temperature: 36.4 + sin(Double(offset) * 0.45) * 0.25))
    }

    static func touchAllModels(in context: ModelContext) throws {
        // Standalone models
        let appSettings = AppSettings(); context.insert(appSettings)
        let userProfile = UserProfile(); context.insert(userProfile)
        let syncState = HealthSyncState(); context.insert(syncState)
        let repRangePolicy = RepRangePolicy(); context.insert(repRangePolicy)
        let preWorkoutCtx = PreWorkoutContext(); context.insert(preWorkoutCtx)
        let suggestionEvent = SuggestionEvent(); context.insert(suggestionEvent)
        let prescriptionChange = PrescriptionChange(); context.insert(prescriptionChange)
        let suggestionEval = SuggestionEvaluation(); context.insert(suggestionEval)
        let healthWorkout = HealthWorkout(debugPlaceholder: true); context.insert(healthWorkout)
        let restTimeHistory = RestTimeHistory(seconds: 90); context.insert(restTimeHistory)
        let trainingGoal = TrainingGoal(kind: .generalTraining); context.insert(trainingGoal)
        let trainingCondition = TrainingConditionPeriod(kind: .sick, trainingImpact: .contextOnly); context.insert(trainingCondition)
        let weightEntry = WeightEntry(date: .now, weight: 80); context.insert(weightEntry)
        let weightGoal = WeightGoal(); context.insert(weightGoal)
        let stepsGoal = StepsGoal(targetSteps: 8000); context.insert(stepsGoal)
        let sleepGoal = SleepGoal(targetSleepDuration: 8 * 3600); context.insert(sleepGoal)
        let hydrationEntry = HydrationEntry(date: .now, volume: 500); context.insert(hydrationEntry)
        let hydrationGoal = HydrationGoal(targetML: 3000); context.insert(hydrationGoal)
        let heart = HealthHeart(date: .now); context.insert(heart)
        let respiratory = HealthRespiratoryRate(date: .now); context.insert(respiratory)
        let energy = HealthEnergy(date: .now); context.insert(energy)
        let steps = HealthStepsDistance(date: .now); context.insert(steps)
        let wristTemp = HealthWristTemperature(date: .now, temperature: 36.5); context.insert(wristTemp)
        let sleepNight = HealthSleepNight(wakeDay: .now); context.insert(sleepNight)
        let sleepBlock = HealthSleepBlock(startDate: .now, endDate: .now, night: sleepNight); context.insert(sleepBlock)
        let exerciseHistory = ExerciseHistory(catalogID: "_debug_touch"); context.insert(exerciseHistory)
        let progressionPoint = ProgressionPoint(date: .now, weight: 0, totalReps: 0, volume: 0, estimated1RM: 0); context.insert(progressionPoint)

        // Models needing an Exercise
        let catalogItem = ExerciseCatalog.all.first!
        let exercise = Exercise(from: catalogItem); context.insert(exercise)

        // WorkoutPlan chain
        let plan = WorkoutPlan(); context.insert(plan)
        let prescription = ExercisePrescription(exercise: exercise, workoutPlan: plan); context.insert(prescription)
        let setPrescription = SetPrescription(exercisePrescription: prescription); context.insert(setPrescription)

        // WorkoutSession chain
        let session = WorkoutSession(); context.insert(session)
        let performance = ExercisePerformance(exercise: exercise, workoutSession: session); context.insert(performance)
        let setPerformance = SetPerformance(exercise: performance); context.insert(setPerformance)

        // WorkoutSplit chain
        let split = WorkoutSplit(mode: .weekly); context.insert(split)
        let splitDay = WorkoutSplitDay(weekday: 1, split: split); context.insert(splitDay)

        // Cardio chain
        let cardioSession = CardioSession(activity: .run, environment: .outdoor); context.insert(cardioSession)
        let cardioRoutePoint = CardioRoutePoint(index: 0, latitude: 0, longitude: 0, timestamp: .now, session: cardioSession); context.insert(cardioRoutePoint)
        let cardioMachineInterval = CardioMachineInterval(index: 0, session: cardioSession); context.insert(cardioMachineInterval)

        // Hydration day
        let hydrationDay = HydrationDay(); context.insert(hydrationDay)

        try context.save()
        AppLog.info("Debug touchAllModels: all model tables touched.")

        // Clean up inserted debug objects
        let toDelete: [any PersistentModel] = [
            appSettings, userProfile, syncState, repRangePolicy, preWorkoutCtx,
            suggestionEvent, prescriptionChange, suggestionEval, healthWorkout,
            restTimeHistory, trainingGoal, trainingCondition,
            weightEntry, weightGoal, stepsGoal, sleepGoal,
            hydrationEntry, hydrationGoal,
            heart, respiratory, energy, steps, wristTemp,
            sleepNight, sleepBlock,
            exerciseHistory, progressionPoint,
            exercise, plan, prescription, setPrescription,
            session, performance, setPerformance,
            split, splitDay,
            cardioSession, cardioRoutePoint, cardioMachineInterval,
            hydrationDay,
        ]
        for obj in toDelete { context.delete(obj) }
        try context.save()
        AppLog.info("Debug touchAllModels: cleanup complete.")
    }

    private static func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws -> Int {
        let models = try context.fetch(FetchDescriptor<T>())
        for model in models {
            context.delete(model)
        }
        return models.count
    }
}
#endif
