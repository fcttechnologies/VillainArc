import BackgroundTasks
import Foundation
import SwiftData

actor WeeklyHealthCoachingCoordinator {
    static let shared = WeeklyHealthCoachingCoordinator()

    nonisolated static let taskIdentifier = "com.villainarc.health.weeklyCoaching"

    private let minimumEntriesForAverage = 3
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }()

    private init() {}

    @discardableResult
    nonisolated func registerBackgroundTask() -> Bool {
        let didRegister = BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskIdentifier, using: nil) { task in
            print("Weekly health coaching background task launched: \(Self.taskIdentifier)")
            guard let appRefreshTask = task as? BGAppRefreshTask else {
                print("Weekly health coaching background task had unexpected type: \(type(of: task))")
                task.setTaskCompleted(success: false)
                return
            }

            self.handleAppRefresh(task: appRefreshTask)
        }
        print("Weekly health coaching background task registration \(didRegister ? "succeeded" : "failed"): \(Self.taskIdentifier)")
        return didRegister
    }

    nonisolated private func handleAppRefresh(task: BGAppRefreshTask) {
        nonisolated(unsafe) let backgroundTask = task
        let worker = Task {
            await refreshSchedule()
            guard !Task.isCancelled else { return }
            await evaluateAndDeliverWeeklyDigestIfNeeded()
            guard !Task.isCancelled else { return }
            print("Weekly health coaching background task completed successfully.")
            backgroundTask.setTaskCompleted(success: true)
        }

        backgroundTask.expirationHandler = {
            print("Weekly health coaching background task expired before completion.")
            worker.cancel()
            backgroundTask.setTaskCompleted(success: false)
        }
    }

    func refreshSchedule() async {
        guard await shouldScheduleWeeklyCoachingRefresh() else {
            print("Weekly health coaching refresh not scheduled; prerequisites are not currently met.")
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskIdentifier)
            return
        }

        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = nextSundayNoon(after: .now)

        do {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskIdentifier)
            try BGTaskScheduler.shared.submit(request)
            print("Scheduled weekly health coaching refresh for \(request.earliestBeginDate?.formatted(date: .abbreviated, time: .standard) ?? "the next system opportunity").")
        } catch {
            print("Failed to schedule weekly health coaching refresh: \(error)")
        }
    }

    private func shouldScheduleWeeklyCoachingRefresh() async -> Bool {
        guard HealthAuthorizationManager.isHealthDataAvailable else { return false }

        let status = await NotificationCoordinator.authorizationStatus()
        guard status.allowsLocalDelivery else { return false }

        let context = makeBackgroundContext()
        guard SetupGuard.isReady(context: context) else { return false }
        guard let settings = try? context.fetch(AppSettings.single).first else { return false }
        return settings.stepsNotificationMode == .coaching || settings.sleepNotificationMode == .coaching
    }

    private func evaluateAndDeliverWeeklyDigestIfNeeded() async {
        let context = makeBackgroundContext()
        guard SetupGuard.isReady(context: context) else { return }
        guard let settings = try? context.fetch(AppSettings.single).first else { return }
        let shouldIncludeSteps = settings.stepsNotificationMode == .coaching
        let shouldIncludeSleep = settings.sleepNotificationMode == .coaching
        guard shouldIncludeSteps || shouldIncludeSleep else { return }

        let reportWeek = lastCompletedSundayToSaturdayWeek(relativeTo: .now)
        guard let syncState = try? context.fetch(HealthSyncState.single).first else { return }
        if let lastDeliveredWeekStart = syncState.weeklyCoachingLastDeliveredWeekStart,
           calendar.isDate(lastDeliveredWeekStart, inSameDayAs: reportWeek.start) {
            return
        }

        let averageSteps = shouldIncludeSteps ? weeklyAverageSteps(in: reportWeek, context: context) : nil
        let averageSleep = shouldIncludeSleep ? weeklyAverageSleep(in: reportWeek, context: context) : nil
        guard averageSteps != nil || averageSleep != nil else { return }

        let didScheduleNotification = await NotificationCoordinator.deliverWeeklyHealthCoaching(
            averageSteps: averageSteps,
            averageSleepDuration: averageSleep,
            weekStart: reportWeek.start
        )

        guard didScheduleNotification else { return }
        syncState.weeklyCoachingLastDeliveredWeekStart = reportWeek.start
        try? context.save()
    }

    private func weeklyAverageSteps(in week: ReportWeek, context: ModelContext) -> Int? {
        guard let entries = try? context.fetch(HealthStepsDistance.inDayRange(week.start...week.end)) else { return nil }
        guard entries.count >= minimumEntriesForAverage else { return nil }

        let average = Double(entries.reduce(0) { $0 + max(0, $1.stepCount) }) / Double(entries.count)
        let roundedAverage = Int(average.rounded())
        return roundedAverage > 0 ? roundedAverage : nil
    }

    private func weeklyAverageSleep(in week: ReportWeek, context: ModelContext) -> TimeInterval? {
        let storedStart = HealthSleepNight.wakeDayKey(for: week.start)
        let storedEnd = HealthSleepNight.wakeDayKey(for: week.end)
        guard let entries = try? context.fetch(HealthSleepNight.inStoredWakeDayRange(storedStart...storedEnd)) else { return nil }
        let availableEntries = entries.filter { $0.isAvailableInHealthKit && $0.timeAsleep > 0 }
        guard availableEntries.count >= minimumEntriesForAverage else { return nil }

        let average = availableEntries.reduce(0) { $0 + max(0, $1.timeAsleep) } / Double(availableEntries.count)
        return average > 0 ? average : nil
    }

    private func lastCompletedSundayToSaturdayWeek(relativeTo date: Date) -> ReportWeek {
        let today = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: today)
        let daysSinceSunday = max(weekday - 1, 0)
        let currentWeekStart = calendar.date(byAdding: .day, value: -daysSinceSunday, to: today) ?? today
        let reportStart = calendar.date(byAdding: .day, value: -7, to: currentWeekStart) ?? currentWeekStart
        let reportEnd = calendar.date(byAdding: .day, value: 6, to: reportStart) ?? reportStart
        return ReportWeek(start: reportStart, end: reportEnd)
    }

    private func nextSundayNoon(after date: Date) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.weekday = 1
        components.hour = 12
        components.minute = 0
        components.second = 0

        return calendar.nextDate(after: date, matching: components, matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward) ?? date.addingTimeInterval(7 * 24 * 60 * 60)
    }

    private func makeBackgroundContext() -> ModelContext {
        let context = ModelContext(SharedModelContainer.container)
        context.autosaveEnabled = false
        return context
    }
}

private struct ReportWeek {
    let start: Date
    let end: Date
}
