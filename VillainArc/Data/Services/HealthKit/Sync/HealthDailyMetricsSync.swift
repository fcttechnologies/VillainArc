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
    }

    static let shared = HealthDailyMetricsSync()

    private let stepCountType = HKQuantityType(.stepCount)
    private let walkingRunningDistanceType = HKQuantityType(.distanceWalkingRunning)
    private let activeEnergyBurnedType = HKQuantityType(.activeEnergyBurned)
    private let restingEnergyBurnedType = HKQuantityType(.basalEnergyBurned)
    private let stepsUnit = HKUnit.count()
    private let distanceUnit = HKUnit.meter()
    private let energyUnit = HKUnit.kilocalorie()
    private let calendar = Calendar.autoupdatingCurrent

    private var isSyncingSteps = false
    private var isSyncingWalkingRunningDistance = false
    private var isSyncingActiveEnergy = false
    private var isSyncingRestingEnergy = false

    private init() {}

    func syncAll() async {
        await syncSteps()
        await syncWalkingRunningDistance()
        await syncActiveEnergyBurned()
        await syncRestingEnergyBurned()
    }

    func syncSteps() async {
        guard HealthAuthorizationManager.isHealthDataAvailable else { return }
        guard HealthAuthorizationManager.hasRequestedStepCountAuthorization else { return }
        guard !isSyncingSteps else { return }

        isSyncingSteps = true
        defer { isSyncingSteps = false }

        let context = makeBackgroundContext()
        guard let syncState = try? SystemState.healthSyncState(context: context) else { return }
        let syncedRange = syncState.stepCountSyncedRange
        let usesInitialImport = syncedRange == nil
        let anchor = usesInitialImport ? nil : HealthSyncPreferences.stepCountAnchor

        do {
            let result = try await syncMetric(type: stepCountType, unit: stepsUnit, anchor: anchor, syncedRange: syncedRange, context: context, mapValue: { Int($0.rounded()) }, applyValue: { try self.upsertStepCount(for: $0, stepCount: $1, context: $2) })
            HealthSyncPreferences.stepCountAnchor = result.newAnchor
            syncState.stepCountSyncedRange = result.newSyncedRange
            try context.save()
        } catch {
            print("Failed to sync Health steps: \(error)")
        }
    }

    func syncWalkingRunningDistance() async {
        guard HealthAuthorizationManager.isHealthDataAvailable else { return }
        guard HealthAuthorizationManager.hasRequestedWalkingRunningDistanceAuthorization else { return }
        guard !isSyncingWalkingRunningDistance else { return }

        isSyncingWalkingRunningDistance = true
        defer { isSyncingWalkingRunningDistance = false }

        let context = makeBackgroundContext()
        guard let syncState = try? SystemState.healthSyncState(context: context) else { return }
        let syncedRange = syncState.walkingRunningDistanceSyncedRange
        let usesInitialImport = syncedRange == nil
        let anchor = usesInitialImport ? nil : HealthSyncPreferences.walkingRunningDistanceAnchor

        do {
            let result = try await syncMetric(type: walkingRunningDistanceType, unit: distanceUnit, anchor: anchor, syncedRange: syncedRange, context: context, mapValue: { $0 }, applyValue: { try self.upsertWalkingRunningDistance(for: $0, distance: $1, context: $2) })
            HealthSyncPreferences.walkingRunningDistanceAnchor = result.newAnchor
            syncState.walkingRunningDistanceSyncedRange = result.newSyncedRange
            try context.save()
        } catch {
            print("Failed to sync Health walking/running distance: \(error)")
        }
    }

    func syncActiveEnergyBurned() async {
        guard HealthAuthorizationManager.isHealthDataAvailable else { return }
        guard HealthAuthorizationManager.hasRequestedActiveEnergyBurnedAuthorization else { return }
        guard !isSyncingActiveEnergy else { return }

        isSyncingActiveEnergy = true
        defer { isSyncingActiveEnergy = false }

        let context = makeBackgroundContext()
        guard let syncState = try? SystemState.healthSyncState(context: context) else { return }
        let syncedRange = syncState.activeEnergyBurnedSyncedRange
        let usesInitialImport = syncedRange == nil
        let anchor = usesInitialImport ? nil : HealthSyncPreferences.activeEnergyBurnedAnchor

        do {
            let result = try await syncMetric(type: activeEnergyBurnedType, unit: energyUnit, anchor: anchor, syncedRange: syncedRange, context: context, mapValue: { $0 }, applyValue: { try self.upsertActiveEnergyBurned(for: $0, activeEnergyBurned: $1, context: $2) })
            HealthSyncPreferences.activeEnergyBurnedAnchor = result.newAnchor
            syncState.activeEnergyBurnedSyncedRange = result.newSyncedRange
            try context.save()
        } catch {
            print("Failed to sync Health active energy: \(error)")
        }
    }

    func syncRestingEnergyBurned() async {
        guard HealthAuthorizationManager.isHealthDataAvailable else { return }
        guard HealthAuthorizationManager.hasRequestedRestingEnergyBurnedAuthorization else { return }
        guard !isSyncingRestingEnergy else { return }

        isSyncingRestingEnergy = true
        defer { isSyncingRestingEnergy = false }

        let context = makeBackgroundContext()
        guard let syncState = try? SystemState.healthSyncState(context: context) else { return }
        let syncedRange = syncState.restingEnergyBurnedSyncedRange
        let usesInitialImport = syncedRange == nil
        let anchor = usesInitialImport ? nil : HealthSyncPreferences.restingEnergyBurnedAnchor

        do {
            let result = try await syncMetric(type: restingEnergyBurnedType, unit: energyUnit, anchor: anchor, syncedRange: syncedRange, context: context, mapValue: { $0 }, applyValue: { try self.upsertRestingEnergyBurned(for: $0, restingEnergyBurned: $1, context: $2) })
            HealthSyncPreferences.restingEnergyBurnedAnchor = result.newAnchor
            syncState.restingEnergyBurnedSyncedRange = result.newSyncedRange
            try context.save()
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
        let refreshRange = refreshRange(addedDays: Set(result.addedSamples.map(dayStart(for:))), syncedRange: syncedRange, hasDeletions: !result.deletedObjects.isEmpty)

        if let refreshRange {
            try await refreshMetricRange(dayRange: refreshRange, type: type, unit: unit, context: context, mapValue: mapValue, applyValue: applyValue)
            try context.save()
        }

        return MetricSyncResult(newAnchor: result.newAnchor, newSyncedRange: refreshRange.map { expandedSyncedRange(afterRefreshing: $0, existingRange: syncedRange) } ?? syncedRange)
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

    private func upsertStepCount(for dayStart: Date, stepCount: Int, context: ModelContext) throws {
        let summary = try fetchOrCreateStepsDistance(for: dayStart, context: context)
        summary.stepCount = max(0, stepCount)
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
        let summary = HealthStepsDistance(date: dayStart)
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
