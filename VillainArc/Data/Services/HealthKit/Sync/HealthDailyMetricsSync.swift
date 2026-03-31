import Foundation
import HealthKit
import SwiftData

actor HealthDailyMetricsSync {
    private final class TotalsByDayBox<Value>: @unchecked Sendable {
        var value: [Date: Value] = [:]
    }

    private struct StepsGoalCompletionNotification: Sendable {
        let targetSteps: Int
        let achievedStepCount: Int
    }

    private struct MetricSyncResult {
        let newAnchor: HKQueryAnchor
        let newSyncedRange: ClosedRange<Date>?
        let refreshedRange: ClosedRange<Date>?
        let shouldAdvanceSyncState: Bool
    }

    static let shared = HealthDailyMetricsSync()

    private let calendar = Calendar.autoupdatingCurrent

    private var isSyncingMovementMetrics = false
    private var isSyncingEnergyMetrics = false
    private var needsAnotherMovementMetricsSync = false
    private var needsAnotherEnergyMetricsSync = false
    private var pendingStepSync = false
    private var pendingWalkingRunningDistanceSync = false
    private var pendingActiveEnergySync = false
    private var pendingRestingEnergySync = false

    private init() {}

    func syncAll() async {
        await syncMovementMetrics()
        await syncEnergyMetrics()
    }

    func syncSteps() async {
        guard HealthAuthorizationManager.isHealthDataAvailable else { return }
        guard HealthAuthorizationManager.hasRequestedStepCountAuthorization else { return }
        pendingStepSync = true
        await syncMovementMetricsIfNeeded()
    }

    func syncWalkingRunningDistance() async {
        guard HealthAuthorizationManager.isHealthDataAvailable else { return }
        guard HealthAuthorizationManager.hasRequestedWalkingRunningDistanceAuthorization else { return }
        pendingWalkingRunningDistanceSync = true
        await syncMovementMetricsIfNeeded()
    }

    func syncActiveEnergyBurned() async {
        guard HealthAuthorizationManager.isHealthDataAvailable else { return }
        guard HealthAuthorizationManager.hasRequestedActiveEnergyBurnedAuthorization else { return }
        pendingActiveEnergySync = true
        await syncEnergyMetricsIfNeeded()
    }

    func syncRestingEnergyBurned() async {
        guard HealthAuthorizationManager.isHealthDataAvailable else { return }
        guard HealthAuthorizationManager.hasRequestedRestingEnergyBurnedAuthorization else { return }
        pendingRestingEnergySync = true
        await syncEnergyMetricsIfNeeded()
    }

    private func syncMovementMetrics() async {
        guard HealthAuthorizationManager.isHealthDataAvailable else { return }
        if HealthAuthorizationManager.hasRequestedStepCountAuthorization { pendingStepSync = true }
        if HealthAuthorizationManager.hasRequestedWalkingRunningDistanceAuthorization { pendingWalkingRunningDistanceSync = true }
        await syncMovementMetricsIfNeeded()
    }

    private func syncEnergyMetrics() async {
        guard HealthAuthorizationManager.isHealthDataAvailable else { return }
        if HealthAuthorizationManager.hasRequestedActiveEnergyBurnedAuthorization { pendingActiveEnergySync = true }
        if HealthAuthorizationManager.hasRequestedRestingEnergyBurnedAuthorization { pendingRestingEnergySync = true }
        await syncEnergyMetricsIfNeeded()
    }

    private func syncMovementMetricsIfNeeded() async {
        if isSyncingMovementMetrics {
            needsAnotherMovementMetricsSync = true
            return
        }

        while true {
            isSyncingMovementMetrics = true
            needsAnotherMovementMetricsSync = false

            let shouldSyncSteps = pendingStepSync
            let shouldSyncDistance = pendingWalkingRunningDistanceSync
            pendingStepSync = false
            pendingWalkingRunningDistanceSync = false

            if shouldSyncSteps { await syncStepsPass() }
            if shouldSyncDistance { await syncWalkingRunningDistancePass() }

            isSyncingMovementMetrics = false
            guard !needsAnotherMovementMetricsSync else { continue }
            return
        }
    }

    private func syncEnergyMetricsIfNeeded() async {
        if isSyncingEnergyMetrics {
            needsAnotherEnergyMetricsSync = true
            return
        }

        while true {
            isSyncingEnergyMetrics = true
            needsAnotherEnergyMetricsSync = false

            let shouldSyncActiveEnergy = pendingActiveEnergySync
            let shouldSyncRestingEnergy = pendingRestingEnergySync
            pendingActiveEnergySync = false
            pendingRestingEnergySync = false

            if shouldSyncActiveEnergy { await syncActiveEnergyPass() }
            if shouldSyncRestingEnergy { await syncRestingEnergyPass() }

            isSyncingEnergyMetrics = false
            guard !needsAnotherEnergyMetricsSync else { continue }
            return
        }
    }

    private func syncStepsPass() async {
        let context = makeBackgroundContext()
        guard let syncState = try? SystemState.healthSyncState(context: context) else { return }
        let syncedRange = syncState.stepCountSyncedRange
        let usesInitialImport = syncedRange == nil
        let anchor = usesInitialImport ? nil : HealthSyncPreferences.stepCountAnchor
        let notificationsBox = TotalsByDayBox<StepsGoalCompletionNotification>()

        do {
            let result = try await syncMetric(type: HealthKitCatalog.stepCountType, unit: HealthKitCatalog.countUnit, anchor: anchor, syncedRange: syncedRange, context: context, mapValue: { Int($0.rounded()) }, applyValue: { try self.upsertStepCount(for: $0, stepCount: $1, context: $2, notificationsBox: notificationsBox) })
            if result.shouldAdvanceSyncState {
                HealthSyncPreferences.stepCountAnchor = result.newAnchor
                syncState.stepCountSyncedRange = result.newSyncedRange
                try context.save()
            }
            for notification in notificationsBox.value.values {
                await NotificationCoordinator.deliverStepsGoalCompletion(targetSteps: notification.targetSteps, stepCount: notification.achievedStepCount)
            }
            logMetricSyncIfNeeded(named: "steps", refreshedRange: result.refreshedRange)
        } catch {
            print("Failed to sync Health steps: \(error)")
        }
    }

    private func syncWalkingRunningDistancePass() async {
        let context = makeBackgroundContext()
        guard let syncState = try? SystemState.healthSyncState(context: context) else { return }
        let syncedRange = syncState.walkingRunningDistanceSyncedRange
        let usesInitialImport = syncedRange == nil
        let anchor = usesInitialImport ? nil : HealthSyncPreferences.walkingRunningDistanceAnchor

        do {
            let result = try await syncMetric(type: HealthKitCatalog.walkingRunningDistanceType, unit: HealthKitCatalog.meterUnit, anchor: anchor, syncedRange: syncedRange, context: context, mapValue: { $0 }, applyValue: { try self.upsertWalkingRunningDistance(for: $0, distance: $1, context: $2) })
            if result.shouldAdvanceSyncState {
                HealthSyncPreferences.walkingRunningDistanceAnchor = result.newAnchor
                syncState.walkingRunningDistanceSyncedRange = result.newSyncedRange
                try context.save()
            }
            logMetricSyncIfNeeded(named: "walking/running distance", refreshedRange: result.refreshedRange)
        } catch {
            print("Failed to sync Health walking/running distance: \(error)")
        }
    }

    private func syncActiveEnergyPass() async {
        let context = makeBackgroundContext()
        guard let syncState = try? SystemState.healthSyncState(context: context) else { return }
        let syncedRange = syncState.activeEnergyBurnedSyncedRange
        let usesInitialImport = syncedRange == nil
        let anchor = usesInitialImport ? nil : HealthSyncPreferences.activeEnergyBurnedAnchor

        do {
            let result = try await syncMetric(type: HealthKitCatalog.activeEnergyBurnedType, unit: HealthKitCatalog.kilocalorieUnit, anchor: anchor, syncedRange: syncedRange, context: context, mapValue: { $0 }, applyValue: { try self.upsertActiveEnergyBurned(for: $0, activeEnergyBurned: $1, context: $2) })
            if result.shouldAdvanceSyncState {
                HealthSyncPreferences.activeEnergyBurnedAnchor = result.newAnchor
                syncState.activeEnergyBurnedSyncedRange = result.newSyncedRange
                try context.save()
            }
            logMetricSyncIfNeeded(named: "active energy", refreshedRange: result.refreshedRange)
        } catch {
            print("Failed to sync Health active energy: \(error)")
        }
    }

    private func syncRestingEnergyPass() async {
        let context = makeBackgroundContext()
        guard let syncState = try? SystemState.healthSyncState(context: context) else { return }
        let syncedRange = syncState.restingEnergyBurnedSyncedRange
        let usesInitialImport = syncedRange == nil
        let anchor = usesInitialImport ? nil : HealthSyncPreferences.restingEnergyBurnedAnchor

        do {
            let result = try await syncMetric(type: HealthKitCatalog.restingEnergyBurnedType, unit: HealthKitCatalog.kilocalorieUnit, anchor: anchor, syncedRange: syncedRange, context: context, mapValue: { $0 }, applyValue: { try self.upsertRestingEnergyBurned(for: $0, restingEnergyBurned: $1, context: $2) })
            if result.shouldAdvanceSyncState {
                HealthSyncPreferences.restingEnergyBurnedAnchor = result.newAnchor
                syncState.restingEnergyBurnedSyncedRange = result.newSyncedRange
                try context.save()
            }
            logMetricSyncIfNeeded(named: "resting energy", refreshedRange: result.refreshedRange)
        } catch {
            print("Failed to sync Health resting energy: \(error)")
        }
    }

    private func anchoredResult(for type: HKQuantityType, anchor: HKQueryAnchor?) async throws -> HKAnchoredObjectQueryDescriptor<HKQuantitySample>.Result {
        let descriptor = HKAnchoredObjectQueryDescriptor(predicates: [.quantitySample(type: type)], anchor: anchor)
        return try await descriptor.result(for: HealthAuthorizationManager.healthStore)
    }

    private func dayStart(for sample: HKQuantitySample) -> Date {
        calendar.startOfDay(for: sample.endDate)
    }

    private func refreshRange(addedDays: Set<Date>, syncedRange: ClosedRange<Date>?, hasDeletions: Bool) -> ClosedRange<Date>? {
        let changedRange = dateRange(from: addedDays)

        if hasDeletions {
            return mergedRange(syncedRange, changedRange)
        }

        guard let changedRange else { return nil }
        guard let syncedRange else { return changedRange }

        if changedRange.lowerBound > syncedRange.upperBound {
            let gapStart = nextDay(after: syncedRange.upperBound)
            return gapStart...changedRange.upperBound
        }

        if changedRange.upperBound < syncedRange.lowerBound {
            let gapEnd = previousDay(before: syncedRange.lowerBound)
            return changedRange.lowerBound...gapEnd
        }

        return changedRange
    }

    private func expandedSyncedRange(afterRefreshing refreshedRange: ClosedRange<Date>, existingRange: ClosedRange<Date>?) -> ClosedRange<Date> {
        guard let existingRange else { return refreshedRange }
        return min(existingRange.lowerBound, refreshedRange.lowerBound)...max(existingRange.upperBound, refreshedRange.upperBound)
    }

    private func dateRange(from days: Set<Date>) -> ClosedRange<Date>? {
        guard let earliest = days.min(), let latest = days.max() else { return nil }
        return earliest...latest
    }

    private func mergedRange(_ lhs: ClosedRange<Date>?, _ rhs: ClosedRange<Date>?) -> ClosedRange<Date>? {
        switch (lhs, rhs) {
        case let (.some(lhs), .some(rhs)):
            return min(lhs.lowerBound, rhs.lowerBound)...max(lhs.upperBound, rhs.upperBound)
        case let (.some(lhs), .none):
            return lhs
        case let (.none, .some(rhs)):
            return rhs
        case (.none, .none):
            return nil
        }
    }

    private func nextDay(after date: Date) -> Date {
        let dayStart = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
    }

    private func previousDay(before date: Date) -> Date {
        let dayStart = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: -1, to: dayStart) ?? dayStart
    }

    private func syncMetric<Value>(type: HKQuantityType, unit: HKUnit, anchor: HKQueryAnchor?, syncedRange: ClosedRange<Date>?, context: ModelContext, mapValue: @escaping (Double) -> Value, applyValue: @escaping (Date, Value, ModelContext) throws -> Void) async throws -> MetricSyncResult {
        let result = try await anchoredResult(for: type, anchor: anchor)
        let shouldAdvanceSyncState = await shouldAdvanceSyncState(for: type, result: result)
        let refreshRange = refreshRange(addedDays: Set(result.addedSamples.map(dayStart(for:))), syncedRange: syncedRange, hasDeletions: !result.deletedObjects.isEmpty)

        if let refreshRange {
            // Keep the row mutation and save phase await-free so each metric pass applies its
            // day updates atomically once the actor resumes from HealthKit.
            try await refreshMetricRange(dayRange: refreshRange, type: type, unit: unit, context: context, mapValue: mapValue, applyValue: applyValue)
            try context.save()
        }

        return MetricSyncResult(newAnchor: result.newAnchor, newSyncedRange: refreshRange.map { expandedSyncedRange(afterRefreshing: $0, existingRange: syncedRange) } ?? syncedRange, refreshedRange: refreshRange, shouldAdvanceSyncState: shouldAdvanceSyncState)
    }

    private func shouldAdvanceSyncState(for type: HKQuantityType, result: HKAnchoredObjectQueryDescriptor<HKQuantitySample>.Result) async -> Bool {
        if !result.addedSamples.isEmpty || !result.deletedObjects.isEmpty { return true }
        return await HealthReadProbe.hasReadableQuantitySample(for: type)
    }

    private func logMetricSyncIfNeeded(named metricName: String, refreshedRange: ClosedRange<Date>?) {
        guard let refreshedRange else { return }
        print("Synced Apple Health \(metricName) for \(formattedDayRange(refreshedRange)).")
    }

    private func formattedDayRange(_ dayRange: ClosedRange<Date>) -> String {
        let start = calendar.startOfDay(for: dayRange.lowerBound)
        let end = calendar.startOfDay(for: dayRange.upperBound)
        let startText = start.formatted(date: .abbreviated, time: .omitted)
        let endText = end.formatted(date: .abbreviated, time: .omitted)
        return start == end ? startText : "\(startText) to \(endText)"
    }

    private func refreshMetricRange<Value>(dayRange: ClosedRange<Date>, type: HKQuantityType, unit: HKUnit, context: ModelContext, mapValue: @escaping (Double) -> Value, applyValue: @escaping (Date, Value, ModelContext) throws -> Void) async throws {
        let lowerDayStart = calendar.startOfDay(for: dayRange.lowerBound)
        let upperDayStart = calendar.startOfDay(for: dayRange.upperBound)
        let upperDayExclusive = calendar.date(byAdding: .day, value: 1, to: upperDayStart) ?? upperDayStart
        let valuesByDay = try await dailyTotalsByDay(for: type, unit: unit, rangeStart: lowerDayStart, rangeEndExclusive: upperDayExclusive, mapValue: mapValue)

        var currentDay = lowerDayStart
        while currentDay < upperDayExclusive {
            try applyValue(currentDay, valuesByDay[currentDay] ?? mapValue(0), context)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDay) else { break }
            currentDay = nextDay
        }
    }

    private func dailyTotalsByDay<Value>(for type: HKQuantityType, unit: HKUnit, rangeStart: Date, rangeEndExclusive: Date, mapValue: @escaping (Double) -> Value) async throws -> [Date: Value] {
        let predicate = HKQuery.predicateForSamples(withStart: rangeStart, end: rangeEndExclusive)
        let samplePredicate = HKSamplePredicate.quantitySample(type: type, predicate: predicate)
        let descriptor = HKStatisticsCollectionQueryDescriptor(predicate: samplePredicate, options: .cumulativeSum, anchorDate: rangeStart, intervalComponents: DateComponents(day: 1))

        let result = try await descriptor.result(for: HealthAuthorizationManager.healthStore)
        let totalsByDay = TotalsByDayBox<Value>()
        let calendar = self.calendar

        result.enumerateStatistics(from: rangeStart, to: rangeEndExclusive) { statistics, _ in
            let dayStart = calendar.startOfDay(for: statistics.startDate)
            let total = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
            totalsByDay.value[dayStart] = mapValue(max(0, total))
        }

        return totalsByDay.value
    }

    private func upsertStepCount(for dayStart: Date, stepCount: Int, context: ModelContext, notificationsBox: TotalsByDayBox<StepsGoalCompletionNotification>) throws {
        let summary = try fetchOrCreateStepsDistance(for: dayStart, context: context)
        summary.stepCount = max(0, stepCount)
        let achievedTodayTransition = try StepsGoalEvaluator.reevaluateAchievement(for: summary, context: context)
        if achievedTodayTransition {
            let targetSteps = try context.fetch(StepsGoal.forDay(dayStart)).first?.targetSteps ?? summary.stepCount
            notificationsBox.value[dayStart] = StepsGoalCompletionNotification(targetSteps: targetSteps, achievedStepCount: summary.stepCount)
        }
    }

    private func upsertWalkingRunningDistance(for dayStart: Date, distance: Double, context: ModelContext) throws {
        let summary = try fetchOrCreateStepsDistance(for: dayStart, context: context)
        summary.distance = max(0, distance)
    }

    private func upsertActiveEnergyBurned(for dayStart: Date, activeEnergyBurned: Double, context: ModelContext) throws {
        let energy = try fetchOrCreateEnergy(for: dayStart, context: context)
        energy.activeEnergyBurned = max(0, activeEnergyBurned)
    }

    private func upsertRestingEnergyBurned(for dayStart: Date, restingEnergyBurned: Double, context: ModelContext) throws {
        let energy = try fetchOrCreateEnergy(for: dayStart, context: context)
        energy.restingEnergyBurned = max(0, restingEnergyBurned)
    }

    private func fetchOrCreateStepsDistance(for dayStart: Date, context: ModelContext) throws -> HealthStepsDistance {
        if let existing = try context.fetch(HealthStepsDistance.forDay(dayStart)).first { return existing }
        let goalTargetSteps = try context.fetch(StepsGoal.forDay(dayStart)).first?.targetSteps
        let summary = HealthStepsDistance(date: dayStart, goalTargetSteps: goalTargetSteps)
        context.insert(summary)
        return summary
    }

    private func fetchOrCreateEnergy(for dayStart: Date, context: ModelContext) throws -> HealthEnergy {
        if let existing = try context.fetch(HealthEnergy.forDay(dayStart)).first { return existing }
        let energy = HealthEnergy(date: dayStart)
        context.insert(energy)
        return energy
    }

    private func makeBackgroundContext() -> ModelContext {
        let context = ModelContext(SharedModelContainer.container)
        context.autosaveEnabled = false
        return context
    }
}
