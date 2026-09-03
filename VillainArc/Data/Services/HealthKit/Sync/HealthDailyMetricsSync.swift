import Foundation
import HealthKit
import SwiftData

actor HealthDailyMetricsSync {
    private final class TotalsByDayBox<Value>: @unchecked Sendable {
        var value: [Date: Value] = [:]
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
    private var isSyncingHeartMetrics = false
    private var needsAnotherMovementMetricsSync = false
    private var needsAnotherEnergyMetricsSync = false
    private var needsAnotherHeartMetricsSync = false
    private var pendingStepSync = false
    private var pendingWalkingRunningDistanceSync = false
    private var pendingActiveEnergySync = false
    private var pendingRestingEnergySync = false
    private var pendingHeartRateSync = false
    private var pendingRestingHeartRateSync = false
    private var pendingWalkingHeartRateSync = false
    private var pendingHeartRateVariabilitySync = false
    private var pendingRespiratoryRateSync = false
    private var pendingWristTemperatureSync = false

    private init() {}

    func syncAll() async {
        await syncMovementMetrics()
        await syncEnergyMetrics()
        await syncHeartMetrics()
        await syncRespiratoryRateIfNeeded()
        await syncWristTemperatureIfNeeded()
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

    func syncHeartRate() async {
        guard HealthAuthorizationManager.isHealthDataAvailable else { return }
        guard HealthAuthorizationManager.hasRequestedHeartRateAuthorization else { return }
        pendingHeartRateSync = true
        await syncHeartMetricsIfNeeded()
    }

    func syncRestingHeartRate() async {
        guard HealthAuthorizationManager.isHealthDataAvailable else { return }
        guard HealthAuthorizationManager.hasRequestedRestingHeartRateAuthorization else { return }
        pendingRestingHeartRateSync = true
        await syncHeartMetricsIfNeeded()
    }

    func syncWalkingHeartRate() async {
        guard HealthAuthorizationManager.isHealthDataAvailable else { return }
        guard HealthAuthorizationManager.hasRequestedWalkingHeartRateAuthorization else { return }
        pendingWalkingHeartRateSync = true
        await syncHeartMetricsIfNeeded()
    }

    func syncHeartRateVariability() async {
        guard HealthAuthorizationManager.isHealthDataAvailable else { return }
        guard HealthAuthorizationManager.hasRequestedHeartRateVariabilityAuthorization else { return }
        pendingHeartRateVariabilitySync = true
        await syncHeartMetricsIfNeeded()
    }

    func syncRespiratoryRate() async {
        guard HealthAuthorizationManager.isHealthDataAvailable else { return }
        guard HealthAuthorizationManager.hasRequestedRespiratoryRateAuthorization else { return }
        pendingRespiratoryRateSync = true
        await syncRespiratoryRateIfNeeded()
    }

    func syncWristTemperature() async {
        guard HealthAuthorizationManager.isHealthDataAvailable else { return }
        guard HealthAuthorizationManager.hasRequestedWristTemperatureAuthorization else { return }
        pendingWristTemperatureSync = true
        await syncWristTemperatureIfNeeded()
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

    private func syncHeartMetrics() async {
        guard HealthAuthorizationManager.isHealthDataAvailable else { return }
        if HealthAuthorizationManager.hasRequestedHeartRateAuthorization { pendingHeartRateSync = true }
        if HealthAuthorizationManager.hasRequestedRestingHeartRateAuthorization { pendingRestingHeartRateSync = true }
        if HealthAuthorizationManager.hasRequestedWalkingHeartRateAuthorization { pendingWalkingHeartRateSync = true }
        if HealthAuthorizationManager.hasRequestedHeartRateVariabilityAuthorization { pendingHeartRateVariabilitySync = true }
        await syncHeartMetricsIfNeeded()
    }

    private func syncRespiratoryRateIfNeeded() async {
        guard HealthAuthorizationManager.isHealthDataAvailable else { return }
        if HealthAuthorizationManager.hasRequestedRespiratoryRateAuthorization { pendingRespiratoryRateSync = true }
        if pendingRespiratoryRateSync {
            pendingRespiratoryRateSync = false
            await syncRespiratoryRatePass()
        }
    }

    private func syncWristTemperatureIfNeeded() async {
        guard HealthAuthorizationManager.isHealthDataAvailable else { return }
        if HealthAuthorizationManager.hasRequestedWristTemperatureAuthorization { pendingWristTemperatureSync = true }
        if pendingWristTemperatureSync {
            pendingWristTemperatureSync = false
            await syncWristTemperaturePass()
        }
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

    private func syncHeartMetricsIfNeeded() async {
        if isSyncingHeartMetrics {
            needsAnotherHeartMetricsSync = true
            return
        }

        while true {
            isSyncingHeartMetrics = true
            needsAnotherHeartMetricsSync = false

            let shouldSyncHR = pendingHeartRateSync
            let shouldSyncRestingHR = pendingRestingHeartRateSync
            let shouldSyncWalkingHR = pendingWalkingHeartRateSync
            let shouldSyncHRV = pendingHeartRateVariabilitySync
            pendingHeartRateSync = false
            pendingRestingHeartRateSync = false
            pendingWalkingHeartRateSync = false
            pendingHeartRateVariabilitySync = false

            if shouldSyncHR { await syncHeartRatePass() }
            if shouldSyncRestingHR { await syncRestingHeartRatePass() }
            if shouldSyncWalkingHR { await syncWalkingHeartRatePass() }
            if shouldSyncHRV { await syncHeartRateVariabilityPass() }

            isSyncingHeartMetrics = false
            guard !needsAnotherHeartMetricsSync else { continue }
            return
        }
    }

    private func syncStepsPass() async {
        let context = makeBackgroundContext()
        guard let syncState = try? SystemState.healthSyncState(context: context) else { return }
        let syncedRange = syncState.stepCountSyncedRange
        let usesInitialImport = syncedRange == nil
        let anchor = usesInitialImport ? nil : HealthSyncPreferences.stepCountAnchor
        let notificationsBox = TotalsByDayBox<StepsEventNotification>()

        do {
            let result = try await syncStepCount(anchor: anchor, syncedRange: syncedRange, context: context, syncState: syncState, notificationsBox: notificationsBox, usesInitialImport: usesInitialImport)
            if result.shouldAdvanceSyncState {
                HealthSyncPreferences.stepCountAnchor = result.newAnchor
                syncState.stepCountSyncedRange = result.newSyncedRange
                try context.save()
            }
            for notification in notificationsBox.value.values {
                await NotificationCoordinator.deliverStepsEvent(notification)
                HealthMetricWidgetReloader.reloadSteps()
            }
            logMetricSyncIfNeeded(named: "steps", refreshedRange: result.refreshedRange)
        } catch {
            AppLog.error("Failed to sync Health steps", error: error)
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
            AppLog.error("Failed to sync Health walking/running distance", error: error)
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
            AppLog.error("Failed to sync Health active energy", error: error)
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
            AppLog.error("Failed to sync Health resting energy", error: error)
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
        AppLog.info("Synced Apple Health \(metricName) for \(formattedDayRange(refreshedRange)).")
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

        // `enumerateStatistics` hands its block an `UnsafeMutablePointer<ObjCBool>` stop flag and
        // HealthKit ships no safe form of the walk. This is safe because the pointer is ignored
        // rather than stored: the block never writes through it and never lets it escape, so the
        // only lifetime involved is the framework's own, for the duration of the call.
        unsafe result.enumerateStatistics(from: rangeStart, to: rangeEndExclusive) { statistics, _ in
            let dayStart = calendar.startOfDay(for: statistics.startDate)
            let total = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
            totalsByDay.value[dayStart] = mapValue(max(0, total))
        }

        return totalsByDay.value
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

    private func syncStepCount(anchor: HKQueryAnchor?, syncedRange: ClosedRange<Date>?, context: ModelContext, syncState: HealthSyncState, notificationsBox: TotalsByDayBox<StepsEventNotification>, usesInitialImport: Bool) async throws -> MetricSyncResult {
        let result = try await anchoredResult(for: HealthKitCatalog.stepCountType, anchor: anchor)
        let shouldAdvanceSyncState = await shouldAdvanceSyncState(for: HealthKitCatalog.stepCountType, result: result)
        let dayRange = refreshRange(addedDays: Set(result.addedSamples.map(dayStart(for:))), syncedRange: syncedRange, hasDeletions: !result.deletedObjects.isEmpty)
        let shouldRecomputeBestDailyStepsKnown = usesInitialImport || !result.deletedObjects.isEmpty || syncState.bestDailyStepsKnown == nil

        if let dayRange {
            try await refreshStepCountRange(dayRange: dayRange, context: context, syncState: syncState, notificationsBox: notificationsBox, recomputeBestDailyStepsKnown: shouldRecomputeBestDailyStepsKnown)
            try context.save()
        } else if shouldRecomputeBestDailyStepsKnown {
            syncState.bestDailyStepsKnown = try StepsCoachingEvaluator.historicalBestDailySteps(excluding: .now, context: context)
            try context.save()
        }

        return MetricSyncResult(newAnchor: result.newAnchor, newSyncedRange: dayRange.map { expandedSyncedRange(afterRefreshing: $0, existingRange: syncedRange) } ?? syncedRange, refreshedRange: dayRange, shouldAdvanceSyncState: shouldAdvanceSyncState)
    }

    private func refreshStepCountRange(dayRange: ClosedRange<Date>, context: ModelContext, syncState: HealthSyncState, notificationsBox: TotalsByDayBox<StepsEventNotification>, recomputeBestDailyStepsKnown: Bool) async throws {
        let lowerDayStart = calendar.startOfDay(for: dayRange.lowerBound)
        let upperDayStart = calendar.startOfDay(for: dayRange.upperBound)
        let upperDayExclusive = calendar.date(byAdding: .day, value: 1, to: upperDayStart) ?? upperDayStart
        let valuesByDay = try await dailyTotalsByDay(for: HealthKitCatalog.stepCountType, unit: HealthKitCatalog.countUnit, rangeStart: lowerDayStart, rangeEndExclusive: upperDayExclusive, mapValue: { Int($0.rounded()) })

        let today = calendar.startOfDay(for: .now)
        var currentDay = lowerDayStart
        var todaySummary: HealthStepsDistance?
        var goalJustAchievedToday = false

        while currentDay < upperDayExclusive {
            let summary = try fetchOrCreateStepsDistance(for: currentDay, context: context)
            summary.stepCount = max(0, valuesByDay[currentDay] ?? 0)
            let goalJustAchieved = try StepsGoalEvaluator.reevaluateAchievement(for: summary, context: context)
            if calendar.isDate(currentDay, inSameDayAs: today) {
                todaySummary = summary
                goalJustAchievedToday = goalJustAchieved
            }
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDay) else { break }
            currentDay = nextDay
        }

        if recomputeBestDailyStepsKnown {
            syncState.bestDailyStepsKnown = try StepsCoachingEvaluator.historicalBestDailySteps(excluding: today, context: context)
        } else if let refreshedHistoricalBest = valuesByDay.filter({ !calendar.isDate($0.key, inSameDayAs: today) }).map(\.value).max() {
            syncState.bestDailyStepsKnown = max(syncState.bestDailyStepsKnown ?? 0, refreshedHistoricalBest)
        }

        guard dayRange.contains(today) else { return }

        if let event = try StepsCoachingEvaluator.reconcileToday(summary: todaySummary, syncState: syncState, context: context, goalJustAchieved: goalJustAchievedToday, trigger: .syncUpdate) {
            notificationsBox.value[today] = event
        }
    }

    private func syncHeartRatePass() async {
        let context = makeBackgroundContext()
        guard let syncState = try? SystemState.healthSyncState(context: context) else { return }
        let syncedRange = syncState.heartRateSyncedRange
        let anchor = syncedRange == nil ? nil : HealthSyncPreferences.heartRateAnchor

        do {
            let result = try await syncDiscreteMetric(
                type: HealthKitCatalog.heartRateType,
                unit: HealthKitCatalog.bpmUnit,
                anchor: anchor,
                syncedRange: syncedRange,
                context: context,
                applyValues: { try self.upsertHeartRateMinMax(for: $0, min: $1, max: $2, context: $4) }
            )
            if result.shouldAdvanceSyncState {
                HealthSyncPreferences.heartRateAnchor = result.newAnchor
                syncState.heartRateSyncedRange = result.newSyncedRange
                try context.save()
            }
            logMetricSyncIfNeeded(named: "heart rate", refreshedRange: result.refreshedRange)
            if result.refreshedRange != nil { HealthMetricWidgetReloader.reloadHeart() }
        } catch {
            AppLog.error("Failed to sync Health heart rate", error: error)
        }
    }

    private func syncRestingHeartRatePass() async {
        let context = makeBackgroundContext()
        guard let syncState = try? SystemState.healthSyncState(context: context) else { return }
        let syncedRange = syncState.restingHeartRateSyncedRange
        let anchor = syncedRange == nil ? nil : HealthSyncPreferences.restingHeartRateAnchor

        do {
            let result = try await syncDiscreteMetric(
                type: HealthKitCatalog.restingHeartRateType,
                unit: HealthKitCatalog.bpmUnit,
                anchor: anchor,
                syncedRange: syncedRange,
                context: context,
                applyValues: { try self.upsertRestingHeartRate(for: $0, avg: $3, context: $4) }
            )
            if result.shouldAdvanceSyncState {
                HealthSyncPreferences.restingHeartRateAnchor = result.newAnchor
                syncState.restingHeartRateSyncedRange = result.newSyncedRange
                try context.save()
            }
            logMetricSyncIfNeeded(named: "resting heart rate", refreshedRange: result.refreshedRange)
            if result.refreshedRange != nil { HealthMetricWidgetReloader.reloadHeart() }
        } catch {
            AppLog.error("Failed to sync Health resting heart rate", error: error)
        }
    }

    private func syncWalkingHeartRatePass() async {
        let context = makeBackgroundContext()
        guard let syncState = try? SystemState.healthSyncState(context: context) else { return }
        let syncedRange = syncState.walkingHeartRateSyncedRange
        let anchor = syncedRange == nil ? nil : HealthSyncPreferences.walkingHeartRateAnchor

        do {
            let result = try await syncDiscreteMetric(
                type: HealthKitCatalog.walkingHeartRateAverageType,
                unit: HealthKitCatalog.bpmUnit,
                anchor: anchor,
                syncedRange: syncedRange,
                context: context,
                applyValues: { try self.upsertWalkingHeartRate(for: $0, avg: $3, context: $4) }
            )
            if result.shouldAdvanceSyncState {
                HealthSyncPreferences.walkingHeartRateAnchor = result.newAnchor
                syncState.walkingHeartRateSyncedRange = result.newSyncedRange
                try context.save()
            }
            logMetricSyncIfNeeded(named: "walking heart rate", refreshedRange: result.refreshedRange)
            if result.refreshedRange != nil { HealthMetricWidgetReloader.reloadHeart() }
        } catch {
            AppLog.error("Failed to sync Health walking heart rate", error: error)
        }
    }

    private func syncHeartRateVariabilityPass() async {
        let context = makeBackgroundContext()
        guard let syncState = try? SystemState.healthSyncState(context: context) else { return }
        let syncedRange = syncState.heartRateVariabilitySyncedRange
        let anchor = syncedRange == nil ? nil : HealthSyncPreferences.heartRateVariabilityAnchor

        do {
            let result = try await syncDiscreteMetric(
                type: HealthKitCatalog.heartRateVariabilitySDNNType,
                unit: HealthKitCatalog.millisecondUnit,
                anchor: anchor,
                syncedRange: syncedRange,
                context: context,
                applyValues: { try self.upsertHeartRateVariability(for: $0, avg: $3, context: $4) }
            )
            if result.shouldAdvanceSyncState {
                HealthSyncPreferences.heartRateVariabilityAnchor = result.newAnchor
                syncState.heartRateVariabilitySyncedRange = result.newSyncedRange
                try context.save()
            }
            logMetricSyncIfNeeded(named: "heart rate variability", refreshedRange: result.refreshedRange)
            if result.refreshedRange != nil { HealthMetricWidgetReloader.reloadHeart() }
        } catch {
            AppLog.error("Failed to sync Health heart rate variability", error: error)
        }
    }

    private func syncRespiratoryRatePass() async {
        let context = makeBackgroundContext()
        guard let syncState = try? SystemState.healthSyncState(context: context) else { return }
        let syncedRange = syncState.respiratoryRateSyncedRange
        let anchor = syncedRange == nil ? nil : HealthSyncPreferences.respiratoryRateAnchor

        do {
            let result = try await syncDiscreteMetric(
                type: HealthKitCatalog.respiratoryRateType,
                unit: HKUnit.count().unitDivided(by: .minute()),
                anchor: anchor,
                syncedRange: syncedRange,
                context: context,
                applyValues: { try self.upsertRespiratoryRate(for: $0, min: $1, max: $2, context: $4) }
            )
            if result.shouldAdvanceSyncState {
                HealthSyncPreferences.respiratoryRateAnchor = result.newAnchor
                syncState.respiratoryRateSyncedRange = result.newSyncedRange
                try context.save()
            }
            logMetricSyncIfNeeded(named: "respiratory rate", refreshedRange: result.refreshedRange)
            if result.refreshedRange != nil { HealthMetricWidgetReloader.reloadRespiratoryRate() }
        } catch {
            AppLog.error("Failed to sync Health respiratory rate", error: error)
        }
    }

    private func syncWristTemperaturePass() async {
        let context = makeBackgroundContext()
        guard let syncState = try? SystemState.healthSyncState(context: context) else { return }
        let syncedRange = syncState.wristTemperatureSyncedRange
        let anchor = syncedRange == nil ? nil : HealthSyncPreferences.wristTemperatureAnchor

        do {
            let result = try await anchoredResult(for: HealthKitCatalog.appleSleepingWristTemperatureType, anchor: anchor)
            let shouldAdvanceSyncState = await shouldAdvanceSyncState(for: HealthKitCatalog.appleSleepingWristTemperatureType, result: result)
            let refreshRange = refreshRange(addedDays: Set(result.addedSamples.map(dayStart(for:))), syncedRange: syncedRange, hasDeletions: !result.deletedObjects.isEmpty)

            if let refreshRange {
                try await refreshWristTemperatureRange(dayRange: refreshRange, context: context)
                try context.save()
            }

            if shouldAdvanceSyncState {
                HealthSyncPreferences.wristTemperatureAnchor = result.newAnchor
                syncState.wristTemperatureSyncedRange = refreshRange.map { expandedSyncedRange(afterRefreshing: $0, existingRange: syncedRange) } ?? syncedRange
                try context.save()
            }
            logMetricSyncIfNeeded(named: "wrist temperature", refreshedRange: refreshRange)
            if refreshRange != nil { HealthMetricWidgetReloader.reloadWristTemperature() }
        } catch {
            AppLog.error("Failed to sync Health wrist temperature", error: error)
        }
    }

    private func syncDiscreteMetric(type: HKQuantityType, unit: HKUnit, anchor: HKQueryAnchor?, syncedRange: ClosedRange<Date>?, context: ModelContext, applyValues: @escaping (Date, Double?, Double?, Double?, ModelContext) throws -> Void) async throws -> MetricSyncResult {
        let result = try await anchoredResult(for: type, anchor: anchor)
        let shouldAdvanceSyncState = await shouldAdvanceSyncState(for: type, result: result)
        let refreshRange = refreshRange(addedDays: Set(result.addedSamples.map(dayStart(for:))), syncedRange: syncedRange, hasDeletions: !result.deletedObjects.isEmpty)

        if let refreshRange {
            try await refreshDiscreteMetricRange(dayRange: refreshRange, type: type, unit: unit, context: context, applyValues: applyValues)
            try context.save()
        }

        return MetricSyncResult(newAnchor: result.newAnchor, newSyncedRange: refreshRange.map { expandedSyncedRange(afterRefreshing: $0, existingRange: syncedRange) } ?? syncedRange, refreshedRange: refreshRange, shouldAdvanceSyncState: shouldAdvanceSyncState)
    }

    private func refreshDiscreteMetricRange(dayRange: ClosedRange<Date>, type: HKQuantityType, unit: HKUnit, context: ModelContext, applyValues: @escaping (Date, Double?, Double?, Double?, ModelContext) throws -> Void) async throws {
        let lowerDayStart = calendar.startOfDay(for: dayRange.lowerBound)
        let upperDayStart = calendar.startOfDay(for: dayRange.upperBound)
        let upperDayExclusive = calendar.date(byAdding: .day, value: 1, to: upperDayStart) ?? upperDayStart
        let statsByDay = try await dailyDiscreteStatsByDay(for: type, unit: unit, rangeStart: lowerDayStart, rangeEndExclusive: upperDayExclusive)

        var currentDay = lowerDayStart
        while currentDay < upperDayExclusive {
            let stats = statsByDay[currentDay]
            try applyValues(currentDay, stats?.min, stats?.max, stats?.avg, context)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDay) else { break }
            currentDay = nextDay
        }
    }

    private func dailyDiscreteStatsByDay(for type: HKQuantityType, unit: HKUnit, rangeStart: Date, rangeEndExclusive: Date) async throws -> [Date: (min: Double?, max: Double?, avg: Double?)] {
        let predicate = HKQuery.predicateForSamples(withStart: rangeStart, end: rangeEndExclusive)
        let samplePredicate = HKSamplePredicate.quantitySample(type: type, predicate: predicate)
        let descriptor = HKStatisticsCollectionQueryDescriptor(predicate: samplePredicate, options: [.discreteMin, .discreteMax, .discreteAverage], anchorDate: rangeStart, intervalComponents: DateComponents(day: 1))

        let result = try await descriptor.result(for: HealthAuthorizationManager.healthStore)
        let statsByDay = TotalsByDayBox<(min: Double?, max: Double?, avg: Double?)>()
        let calendar = self.calendar

        // The stop flag is ignored rather than stored, as in `dailyTotalsByDay` above.
        unsafe result.enumerateStatistics(from: rangeStart, to: rangeEndExclusive) { statistics, _ in
            let dayStart = calendar.startOfDay(for: statistics.startDate)
            let minVal = statistics.minimumQuantity()?.doubleValue(for: unit)
            let maxVal = statistics.maximumQuantity()?.doubleValue(for: unit)
            let avgVal = statistics.averageQuantity()?.doubleValue(for: unit)
            if minVal != nil || maxVal != nil || avgVal != nil {
                statsByDay.value[dayStart] = (minVal, maxVal, avgVal)
            }
        }

        return statsByDay.value
    }

    private func refreshWristTemperatureRange(dayRange: ClosedRange<Date>, context: ModelContext) async throws {
        let lowerDayStart = calendar.startOfDay(for: dayRange.lowerBound)
        let upperDayStart = calendar.startOfDay(for: dayRange.upperBound)
        let upperDayExclusive = calendar.date(byAdding: .day, value: 1, to: upperDayStart) ?? upperDayStart

        let predicate = HKQuery.predicateForSamples(withStart: lowerDayStart, end: upperDayExclusive)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HealthKitCatalog.appleSleepingWristTemperatureType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.endDate)]
        )
        let samples = try await descriptor.result(for: HealthAuthorizationManager.healthStore)

        var latestByDay: [Date: Double] = [:]
        for sample in samples {
            let day = calendar.startOfDay(for: sample.endDate)
            latestByDay[day] = sample.quantity.doubleValue(for: HealthKitCatalog.celsiusUnit)
        }

        var currentDay = lowerDayStart
        while currentDay < upperDayExclusive {
            if let tempC = latestByDay[currentDay] {
                let existing = try context.fetch(HealthWristTemperature.forDay(currentDay)).first
                if let existing {
                    existing.temperature = tempC
                } else {
                    let entry = HealthWristTemperature(date: currentDay, temperature: tempC)
                    context.insert(entry)
                }
            } else if let existing = try context.fetch(HealthWristTemperature.forDay(currentDay)).first {
                context.delete(existing)
            }
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDay) else { break }
            currentDay = nextDay
        }
    }

    private func upsertHeartRateMinMax(for dayStart: Date, min: Double?, max: Double?, context: ModelContext) throws {
        let heart = try fetchOrCreateHeart(for: dayStart, context: context, shouldCreate: min != nil || max != nil)
        heart?.minHeartRate = min
        heart?.maxHeartRate = max
        deleteHeartIfEmpty(heart, context: context)
    }

    private func upsertRestingHeartRate(for dayStart: Date, avg: Double?, context: ModelContext) throws {
        let heart = try fetchOrCreateHeart(for: dayStart, context: context, shouldCreate: avg != nil)
        heart?.restingHeartRate = avg
        deleteHeartIfEmpty(heart, context: context)
    }

    private func upsertWalkingHeartRate(for dayStart: Date, avg: Double?, context: ModelContext) throws {
        let heart = try fetchOrCreateHeart(for: dayStart, context: context, shouldCreate: avg != nil)
        heart?.walkingHeartRateAverage = avg
        deleteHeartIfEmpty(heart, context: context)
    }

    private func upsertHeartRateVariability(for dayStart: Date, avg: Double?, context: ModelContext) throws {
        let heart = try fetchOrCreateHeart(for: dayStart, context: context, shouldCreate: avg != nil)
        heart?.heartRateVariabilitySDNN = avg
        deleteHeartIfEmpty(heart, context: context)
    }

    private func upsertRespiratoryRate(for dayStart: Date, min: Double?, max: Double?, context: ModelContext) throws {
        let existing = try context.fetch(HealthRespiratoryRate.forDay(dayStart)).first
        guard min != nil || max != nil else {
            if let existing { context.delete(existing) }
            return
        }

        let rate = existing ?? { let newRate = HealthRespiratoryRate(date: dayStart); context.insert(newRate); return newRate }()
        rate.minRate = min
        rate.maxRate = max
    }

    private func fetchOrCreateHeart(for dayStart: Date, context: ModelContext, shouldCreate: Bool = true) throws -> HealthHeart? {
        if let existing = try context.fetch(HealthHeart.forDay(dayStart)).first { return existing }
        guard shouldCreate else { return nil }
        let heart = HealthHeart(date: dayStart)
        context.insert(heart)
        return heart
    }

    private func deleteHeartIfEmpty(_ heart: HealthHeart?, context: ModelContext) {
        guard let heart else { return }
        guard heart.minHeartRate == nil,
              heart.maxHeartRate == nil,
              heart.restingHeartRate == nil,
              heart.walkingHeartRateAverage == nil,
              heart.heartRateVariabilitySDNN == nil else { return }
        context.delete(heart)
    }

    private func makeBackgroundContext() -> ModelContext {
        let context = ModelContext(SharedModelContainer.container)
        context.autosaveEnabled = false
        return context
    }
}
