#if DEBUG
import SwiftData
import Foundation

enum DebugOperations {
    static func resetAppData() async throws {
        AppLog.info("Debug reset app data started.")
        let context = SharedModelContainer.container.mainContext

        RestTimerState.shared.stop()
        WorkoutActivityManager.end()
        NotificationCoordinator.cancelRestTimer()
        SharedModelContainer.sharedDefaults.removeObject(forKey: DataManager.exerciseCatalogVersionKey)

        let deletedCount = try deleteAllModels(in: context)
        try ensureDebugReadyBaseline(in: context)
        try await DataManager.seedExercisesForOnboarding()
        let isSetupReady = SetupGuard.isReady(context: context)

        HealthMetricWidgetReloader.reloadAllHealthMetrics()
        AppRouter.shared.collapseActiveFlowPresentations()
        AppRouter.shared.activeAppSheet = nil
        AppRouter.shared.activeHealthSheet = nil
        AppRouter.shared.activeSplitSheet = nil
        AppRouter.shared.homeTabPath.removeAll()
        AppRouter.shared.healthTabPath.removeAll()
        AppRouter.shared.tabSelection = .home
        AppLog.info("Debug reset app data completed. deletedRecords=\(deletedCount), setupReady=\(isSetupReady)")
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

    private static func ensureDebugReadyBaseline(in context: ModelContext) throws {
        _ = try SystemState.ensureAppSettings(context: context)
        _ = try SystemState.ensureHealthSyncState(context: context)

        let profile = try SystemState.ensureUserProfile(context: context)
        profile.name = "Debug User"
        profile.birthday = Calendar.autoupdatingCurrent.date(from: DateComponents(year: 1995, month: 1, day: 1))
        profile.gender = .other
        profile.heightCm = 175
        profile.fitnessLevel = .intermediate
        profile.fitnessLevelSetAt = .now

        if try context.fetch(TrainingGoal.active).first == nil {
            context.insert(TrainingGoal(kind: .generalTraining))
        }

        try context.save()
    }

    private static func deleteAllModels(in context: ModelContext) throws -> Int {
        var deletedCount = 0
        deletedCount += try deleteAll(PrescriptionChange.self, in: context)
        deletedCount += try deleteAll(SuggestionEvaluation.self, in: context)
        deletedCount += try deleteAll(SuggestionEvent.self, in: context)
        deletedCount += try deleteAll(SetPerformance.self, in: context)
        deletedCount += try deleteAll(ExercisePerformance.self, in: context)
        deletedCount += try deleteAll(PreWorkoutContext.self, in: context)
        deletedCount += try deleteAll(WorkoutSession.self, in: context)
        deletedCount += try deleteAll(SetPrescription.self, in: context)
        deletedCount += try deleteAll(ExercisePrescription.self, in: context)
        deletedCount += try deleteAll(WorkoutPlan.self, in: context)
        deletedCount += try deleteAll(WorkoutSplitDay.self, in: context)
        deletedCount += try deleteAll(WorkoutSplit.self, in: context)
        deletedCount += try deleteAll(HealthSleepBlock.self, in: context)
        deletedCount += try deleteAll(HealthSleepNight.self, in: context)
        deletedCount += try deleteAll(ProgressionPoint.self, in: context)
        deletedCount += try deleteAll(ExerciseHistory.self, in: context)
        deletedCount += try deleteAll(RepRangePolicy.self, in: context)
        deletedCount += try deleteAll(HealthWorkout.self, in: context)
        deletedCount += try deleteAll(WeightEntry.self, in: context)
        deletedCount += try deleteAll(HealthStepsDistance.self, in: context)
        deletedCount += try deleteAll(HealthEnergy.self, in: context)
        deletedCount += try deleteAll(TrainingConditionPeriod.self, in: context)
        deletedCount += try deleteAll(HealthSyncState.self, in: context)
        deletedCount += try deleteAll(WeightGoal.self, in: context)
        deletedCount += try deleteAll(StepsGoal.self, in: context)
        deletedCount += try deleteAll(Exercise.self, in: context)
        deletedCount += try deleteAll(AppSettings.self, in: context)
        deletedCount += try deleteAll(UserProfile.self, in: context)
        deletedCount += try deleteAll(RestTimeHistory.self, in: context)
        deletedCount += try deleteAll(TrainingGoal.self, in: context)
        deletedCount += try deleteAll(SleepGoal.self, in: context)
        try context.save()
        return deletedCount
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
