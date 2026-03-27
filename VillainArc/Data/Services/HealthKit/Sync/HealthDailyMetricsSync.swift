import Foundation
import HealthKit
import SwiftData

@MainActor final class HealthDailyMetricsSync {
    private enum RowChange {
        case none
        case created
        case updated
        case deleted
    }

    private struct MetricRefreshResult {
        let fetchedSampleCount: Int
        let deletedSampleCount: Int
        let refreshedDayCount: Int
        let createdRowCount: Int
        let updatedRowCount: Int
        let deletedRowCount: Int
        let refreshedRange: ClosedRange<Date>?
        let newAnchor: HKQueryAnchor
        let newSyncedRange: ClosedRange<Date>?
    }

    static let shared = HealthDailyMetricsSync()

    private let authorizationManager = HealthAuthorizationManager.shared
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

    func syncAll() async { await syncSteps(); await syncWalkingRunningDistance(); await syncActiveEnergyBurned(); await syncRestingEnergyBurned() }

    func syncSteps() async {
        guard authorizationManager.isHealthDataAvailable else { return }
        guard authorizationManager.hasRequestedStepCountAuthorization else { return }
        guard !isSyncingSteps else { return }

        isSyncingSteps = true
        defer { isSyncingSteps = false }

        let context = SharedModelContainer.container.mainContext
        let syncedRange = HealthSyncPreferences.stepCountSyncedRange
        let usesInitialImport = syncedRange == nil
        let anchor = usesInitialImport ? nil : HealthSyncPreferences.stepCountAnchor

        do {
            let result = try await syncMetric(type: stepCountType, unit: stepsUnit, anchor: anchor, syncedRange: syncedRange, context: context, mapValue: { Int($0.rounded()) }, applyValue: { try self.upsertStepCount(for: $0, stepCount: $1, context: $2) })
            HealthSyncPreferences.stepCountAnchor = result.newAnchor
            HealthSyncPreferences.stepCountSyncedRange = result.newSyncedRange
            print("Health steps sync completed. Fetched samples: \(result.fetchedSampleCount). Deleted samples: \(result.deletedSampleCount). Refreshed days: \(result.refreshedDayCount). Created rows: \(result.createdRowCount). Updated rows: \(result.updatedRowCount). Deleted rows: \(result.deletedRowCount). Refreshed range: \(result.refreshedRange.map { "\($0.lowerBound) - \($0.upperBound)" } ?? "none").")
        } catch {
            print("Failed to sync Health steps: \(error)")
        }
    }

    func syncWalkingRunningDistance() async {
        guard authorizationManager.isHealthDataAvailable else { return }
        guard authorizationManager.hasRequestedWalkingRunningDistanceAuthorization else { return }
        guard !isSyncingWalkingRunningDistance else { return }

        isSyncingWalkingRunningDistance = true
        defer { isSyncingWalkingRunningDistance = false }

        let context = SharedModelContainer.container.mainContext
        let syncedRange = HealthSyncPreferences.walkingRunningDistanceSyncedRange
        let usesInitialImport = syncedRange == nil
        let anchor = usesInitialImport ? nil : HealthSyncPreferences.walkingRunningDistanceAnchor

        do {
            let result = try await syncMetric(type: walkingRunningDistanceType, unit: distanceUnit, anchor: anchor, syncedRange: syncedRange, context: context, mapValue: { $0 }, applyValue: { try self.upsertWalkingRunningDistance(for: $0, distance: $1, context: $2) })
            HealthSyncPreferences.walkingRunningDistanceAnchor = result.newAnchor
            HealthSyncPreferences.walkingRunningDistanceSyncedRange = result.newSyncedRange
            print("Health walking/running distance sync completed. Fetched samples: \(result.fetchedSampleCount). Deleted samples: \(result.deletedSampleCount). Refreshed days: \(result.refreshedDayCount). Created rows: \(result.createdRowCount). Updated rows: \(result.updatedRowCount). Deleted rows: \(result.deletedRowCount). Refreshed range: \(result.refreshedRange.map { "\($0.lowerBound) - \($0.upperBound)" } ?? "none").")
        } catch {
            print("Failed to sync Health walking/running distance: \(error)")
        }
    }

    func syncActiveEnergyBurned() async {
        guard authorizationManager.isHealthDataAvailable else { return }
        guard authorizationManager.hasRequestedActiveEnergyBurnedAuthorization else { return }
        guard !isSyncingActiveEnergy else { return }

        isSyncingActiveEnergy = true
        defer { isSyncingActiveEnergy = false }

        let context = SharedModelContainer.container.mainContext
        let syncedRange = HealthSyncPreferences.activeEnergyBurnedSyncedRange
        let usesInitialImport = syncedRange == nil
        let anchor = usesInitialImport ? nil : HealthSyncPreferences.activeEnergyBurnedAnchor

        do {
            let result = try await syncMetric(type: activeEnergyBurnedType, unit: energyUnit, anchor: anchor, syncedRange: syncedRange, context: context, mapValue: { $0 }, applyValue: { try self.upsertActiveEnergyBurned(for: $0, activeEnergyBurned: $1, context: $2) })
            HealthSyncPreferences.activeEnergyBurnedAnchor = result.newAnchor
            HealthSyncPreferences.activeEnergyBurnedSyncedRange = result.newSyncedRange
            print("Health active energy sync completed. Fetched samples: \(result.fetchedSampleCount). Deleted samples: \(result.deletedSampleCount). Refreshed days: \(result.refreshedDayCount). Created rows: \(result.createdRowCount). Updated rows: \(result.updatedRowCount). Deleted rows: \(result.deletedRowCount). Refreshed range: \(result.refreshedRange.map { "\($0.lowerBound) - \($0.upperBound)" } ?? "none").")
        } catch {
            print("Failed to sync Health active energy: \(error)")
        }
    }

    func syncRestingEnergyBurned() async {
        guard authorizationManager.isHealthDataAvailable else { return }
        guard authorizationManager.hasRequestedRestingEnergyBurnedAuthorization else { return }
        guard !isSyncingRestingEnergy else { return }

        isSyncingRestingEnergy = true
        defer { isSyncingRestingEnergy = false }

        let context = SharedModelContainer.container.mainContext
        let syncedRange = HealthSyncPreferences.restingEnergyBurnedSyncedRange
        let usesInitialImport = syncedRange == nil
        let anchor = usesInitialImport ? nil : HealthSyncPreferences.restingEnergyBurnedAnchor

        do {
            let result = try await syncMetric(type: restingEnergyBurnedType, unit: energyUnit, anchor: anchor, syncedRange: syncedRange, context: context, mapValue: { $0 }, applyValue: { try self.upsertRestingEnergyBurned(for: $0, restingEnergyBurned: $1, context: $2) })
            HealthSyncPreferences.restingEnergyBurnedAnchor = result.newAnchor
            HealthSyncPreferences.restingEnergyBurnedSyncedRange = result.newSyncedRange
            print("Health resting energy sync completed. Fetched samples: \(result.fetchedSampleCount). Deleted samples: \(result.deletedSampleCount). Refreshed days: \(result.refreshedDayCount). Created rows: \(result.createdRowCount). Updated rows: \(result.updatedRowCount). Deleted rows: \(result.deletedRowCount). Refreshed range: \(result.refreshedRange.map { "\($0.lowerBound) - \($0.upperBound)" } ?? "none").")
        } catch {
            print("Failed to sync Health resting energy: \(error)")
        }
    }

    private func anchoredResult(for type: HKQuantityType, anchor: HKQueryAnchor?) async throws -> HKAnchoredObjectQueryDescriptor<HKQuantitySample>.Result {
        let descriptor = HKAnchoredObjectQueryDescriptor(predicates: [.quantitySample(type: type)], anchor: anchor)
        return try await descriptor.result(for: authorizationManager.healthStore)
    }

    private func dayStart(for sample: HKQuantitySample) -> Date {
        calendar.startOfDay(for: sample.endDate)
    }

    private func refreshRange(addedDays: Set<Date>, syncedRange: ClosedRange<Date>?, hasDeletions: Bool) -> ClosedRange<Date>? {
        let addedRange = dateRange(from: addedDays)

        guard hasDeletions else { return addedRange }
        guard let syncedRange else { return addedRange }

        if let addedRange {
            return min(syncedRange.lowerBound, addedRange.lowerBound)...max(syncedRange.upperBound, addedRange.upperBound)
        }

        return syncedRange
    }

    private func expandedSyncedRange(afterRefreshing refreshedRange: ClosedRange<Date>, existingRange: ClosedRange<Date>?) -> ClosedRange<Date> {
        guard let existingRange else { return refreshedRange }
        return min(existingRange.lowerBound, refreshedRange.lowerBound)...max(existingRange.upperBound, refreshedRange.upperBound)
    }

    private func dateRange(from days: Set<Date>) -> ClosedRange<Date>? {
        guard let earliest = days.min(), let latest = days.max() else { return nil }
        return earliest...latest
    }

    private func syncMetric<Value>(type: HKQuantityType, unit: HKUnit, anchor: HKQueryAnchor?, syncedRange: ClosedRange<Date>?, context: ModelContext, mapValue: @escaping (Double) -> Value, applyValue: @escaping (Date, Value, ModelContext) throws -> (created: Bool, updated: Bool, deleted: Bool)) async throws -> MetricRefreshResult {
        let result = try await anchoredResult(for: type, anchor: anchor)
        let refreshRange = refreshRange(addedDays: Set(result.addedSamples.map(dayStart(for:))), syncedRange: syncedRange, hasDeletions: !result.deletedObjects.isEmpty)
        var refreshedDayCount = 0
        var createdRowCount = 0
        var updatedRowCount = 0
        var deletedRowCount = 0

        if let refreshRange {
            (refreshedDayCount, createdRowCount, updatedRowCount, deletedRowCount) = try await refreshMetricRange(dayRange: refreshRange, type: type, unit: unit, context: context, mapValue: mapValue, applyValue: applyValue)
            try context.save()
        }

        return MetricRefreshResult(fetchedSampleCount: result.addedSamples.count, deletedSampleCount: result.deletedObjects.count, refreshedDayCount: refreshedDayCount, createdRowCount: createdRowCount, updatedRowCount: updatedRowCount, deletedRowCount: deletedRowCount, refreshedRange: refreshRange, newAnchor: result.newAnchor, newSyncedRange: refreshRange.map { expandedSyncedRange(afterRefreshing: $0, existingRange: syncedRange) } ?? syncedRange)
    }

    private func refreshMetricRange<Value>(dayRange: ClosedRange<Date>, type: HKQuantityType, unit: HKUnit, context: ModelContext, mapValue: @escaping (Double) -> Value, applyValue: @escaping (Date, Value, ModelContext) throws -> (created: Bool, updated: Bool, deleted: Bool)) async throws -> (days: Int, created: Int, updated: Int, deleted: Int) {
        let lowerDayStart = calendar.startOfDay(for: dayRange.lowerBound)
        let upperDayStart = calendar.startOfDay(for: dayRange.upperBound)
        let upperDayExclusive = calendar.date(byAdding: .day, value: 1, to: upperDayStart) ?? upperDayStart
        let valuesByDay = try await dailyTotalsByDay(for: type, unit: unit, rangeStart: lowerDayStart, rangeEndExclusive: upperDayExclusive, mapValue: mapValue)
        var refreshedDayCount = 0
        var createdRowCount = 0
        var updatedRowCount = 0
        var deletedRowCount = 0

        var currentDay = lowerDayStart
        while currentDay < upperDayExclusive {
            if let value = valuesByDay[currentDay] {
                let change = try applyValue(currentDay, value, context)
                refreshedDayCount += 1
                createdRowCount += change.created ? 1 : 0
                updatedRowCount += change.updated ? 1 : 0
                deletedRowCount += change.deleted ? 1 : 0
            } else {
                let change = try applyValue(currentDay, mapValue(0), context)
                refreshedDayCount += 1
                createdRowCount += change.created ? 1 : 0
                updatedRowCount += change.updated ? 1 : 0
                deletedRowCount += change.deleted ? 1 : 0
            }
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDay) else { break }
            currentDay = nextDay
        }

        return (refreshedDayCount, createdRowCount, updatedRowCount, deletedRowCount)
    }

    private func dailyTotalsByDay<Value>(for type: HKQuantityType, unit: HKUnit, rangeStart: Date, rangeEndExclusive: Date, mapValue: @escaping (Double) -> Value) async throws -> [Date: Value] {
        let predicate = HKQuery.predicateForSamples(withStart: rangeStart, end: rangeEndExclusive)
        let samplePredicate = HKSamplePredicate.quantitySample(type: type, predicate: predicate)
        let descriptor = HKStatisticsCollectionQueryDescriptor(predicate: samplePredicate, options: .cumulativeSum, anchorDate: rangeStart, intervalComponents: DateComponents(day: 1))

        let result = try await descriptor.result(for: authorizationManager.healthStore)
        var totalsByDay: [Date: Value] = [:]

        result.enumerateStatistics(from: rangeStart, to: rangeEndExclusive) { statistics, _ in
            let dayStart = self.calendar.startOfDay(for: statistics.startDate)
            let total = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
            totalsByDay[dayStart] = mapValue(max(0, total))
        }

        return totalsByDay
    }

    private func upsertStepCount(for dayStart: Date, stepCount: Int, context: ModelContext) throws -> (created: Bool, updated: Bool, deleted: Bool) {
        let (summary, wasCreated) = try fetchOrCreateStepsDistance(for: dayStart, context: context)
        let previousStepCount = summary.stepCount
        summary.stepCount = max(0, stepCount)
        return tuple(for: rowChange(afterUpdating: summary, wasCreated: wasCreated, valueChanged: previousStepCount != summary.stepCount, context: context))
    }

    private func upsertWalkingRunningDistance(for dayStart: Date, distance: Double, context: ModelContext) throws -> (created: Bool, updated: Bool, deleted: Bool) {
        let (summary, wasCreated) = try fetchOrCreateStepsDistance(for: dayStart, context: context)
        let previousDistance = summary.distance
        summary.distance = max(0, distance)
        return tuple(for: rowChange(afterUpdating: summary, wasCreated: wasCreated, valueChanged: previousDistance != summary.distance, context: context))
    }

    private func upsertActiveEnergyBurned(for dayStart: Date, activeEnergyBurned: Double, context: ModelContext) throws -> (created: Bool, updated: Bool, deleted: Bool) {
        let (energy, wasCreated) = try fetchOrCreateEnergy(for: dayStart, context: context)
        let previousActiveEnergy = energy.activeEnergyBurned
        energy.activeEnergyBurned = max(0, activeEnergyBurned)
        return tuple(for: rowChange(afterUpdating: energy, wasCreated: wasCreated, valueChanged: previousActiveEnergy != energy.activeEnergyBurned, context: context))
    }

    private func upsertRestingEnergyBurned(for dayStart: Date, restingEnergyBurned: Double, context: ModelContext) throws -> (created: Bool, updated: Bool, deleted: Bool) {
        let (energy, wasCreated) = try fetchOrCreateEnergy(for: dayStart, context: context)
        let previousRestingEnergy = energy.restingEnergyBurned
        energy.restingEnergyBurned = max(0, restingEnergyBurned)
        return tuple(for: rowChange(afterUpdating: energy, wasCreated: wasCreated, valueChanged: previousRestingEnergy != energy.restingEnergyBurned, context: context))
    }

    private func fetchOrCreateStepsDistance(for dayStart: Date, context: ModelContext) throws -> (summary: HealthStepsDistance, created: Bool) {
        if let existing = try context.fetch(HealthStepsDistance.forDay(dayStart)).first { return (existing, false) }
        let summary = HealthStepsDistance(date: dayStart)
        context.insert(summary)
        return (summary, true)
    }

    private func fetchOrCreateEnergy(for dayStart: Date, context: ModelContext) throws -> (energy: HealthEnergy, created: Bool) {
        if let existing = try context.fetch(HealthEnergy.forDay(dayStart)).first { return (existing, false) }
        let energy = HealthEnergy(date: dayStart)
        context.insert(energy)
        return (energy, true)
    }

    private func deleteStepsDistanceIfEmpty(_ summary: HealthStepsDistance, context: ModelContext) -> Bool {
        if summary.stepCount <= 0 && summary.distance <= 0 { context.delete(summary); return true }
        return false
    }

    private func deleteEnergyIfEmpty(_ energy: HealthEnergy, context: ModelContext) -> Bool {
        if energy.activeEnergyBurned <= 0 && energy.restingEnergyBurned <= 0 { context.delete(energy); return true }
        return false
    }

    private func rowChange(afterUpdating summary: HealthStepsDistance, wasCreated: Bool, valueChanged: Bool, context: ModelContext) -> RowChange {
        let wasDeleted = deleteStepsDistanceIfEmpty(summary, context: context)
        if wasDeleted { return .deleted }
        if wasCreated { return .created }
        if valueChanged { return .updated }
        return .none
    }

    private func rowChange(afterUpdating energy: HealthEnergy, wasCreated: Bool, valueChanged: Bool, context: ModelContext) -> RowChange {
        let wasDeleted = deleteEnergyIfEmpty(energy, context: context)
        if wasDeleted { return .deleted }
        if wasCreated { return .created }
        if valueChanged { return .updated }
        return .none
    }

    private func tuple(for change: RowChange) -> (created: Bool, updated: Bool, deleted: Bool) {
        switch change {
        case .none:
            return (false, false, false)
        case .created:
            return (true, false, false)
        case .updated:
            return (false, true, false)
        case .deleted:
            return (false, false, true)
        }
    }
}
