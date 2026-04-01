import Foundation
import HealthKit
import Observation

struct HealthMovementDaySamples: Sendable {
    let stepSamples: [TimeSeriesSample]
    let distanceSamples: [TimeSeriesSample]
}

struct HealthEnergyDaySamples: Sendable {
    let totalSamples: [TimeSeriesSample]
    let activeSamples: [TimeSeriesSample]
}

@Observable final class HealthIntradayMetricsLoader {
    private let healthStore = HealthAuthorizationManager.healthStore
    private let calendar = Calendar.autoupdatingCurrent
    private let stepSampleNamespace: UInt64 = 0x5354455048444159
    private let distanceSampleNamespace: UInt64 = 0x4449535448444159
    private let activeEnergySampleNamespace: UInt64 = 0x4143545648444159
    private let totalEnergySampleNamespace: UInt64 = 0x544F544C48444159

    private(set) var movementByDay: [Date: HealthMovementDaySamples] = [:]
    private(set) var energyByDay: [Date: HealthEnergyDaySamples] = [:]
    private(set) var loadedMovementDays: Set<Date> = []
    private(set) var loadedEnergyDays: Set<Date> = []

    var isLoadingMovementDay = false
    var isLoadingEnergyDay = false
    var movementLoadErrorMessage: String?
    var energyLoadErrorMessage: String?

    func loadMovementDayIfNeeded(day: Date) async {
        guard HealthAuthorizationManager.isHealthDataAvailable else { return }
        guard HealthAuthorizationManager.hasRequestedStepCountAuthorization || HealthAuthorizationManager.hasRequestedWalkingRunningDistanceAuthorization else { return }

        let dayStart = calendar.startOfDay(for: day)
        guard !loadedMovementDays.contains(dayStart) else { return }
        guard !isLoadingMovementDay else { return }

        isLoadingMovementDay = true
        defer { isLoadingMovementDay = false }

        do {
            async let stepSamples = hourlySamples(for: HealthKitCatalog.stepCountType, unit: HealthKitCatalog.countUnit, dayStart: dayStart, namespace: stepSampleNamespace)
            async let distanceSamples = hourlySamples(for: HealthKitCatalog.walkingRunningDistanceType, unit: HealthKitCatalog.meterUnit, dayStart: dayStart, namespace: distanceSampleNamespace)
            movementByDay[dayStart] = try await HealthMovementDaySamples(stepSamples: stepSamples, distanceSamples: distanceSamples)
            movementLoadErrorMessage = nil
            loadedMovementDays.insert(dayStart)
        } catch {
            movementLoadErrorMessage = "Unable to load Apple Health intraday movement right now."
            print("Failed to load Apple Health intraday movement: \(error)")
        }
    }

    func loadEnergyDayIfNeeded(day: Date) async {
        guard HealthAuthorizationManager.isHealthDataAvailable else { return }
        guard HealthAuthorizationManager.hasRequestedActiveEnergyBurnedAuthorization || HealthAuthorizationManager.hasRequestedRestingEnergyBurnedAuthorization else { return }

        let dayStart = calendar.startOfDay(for: day)
        guard !loadedEnergyDays.contains(dayStart) else { return }
        guard !isLoadingEnergyDay else { return }

        isLoadingEnergyDay = true
        defer { isLoadingEnergyDay = false }

        do {
            async let activeSamples = hourlySamples(for: HealthKitCatalog.activeEnergyBurnedType, unit: HealthKitCatalog.kilocalorieUnit, dayStart: dayStart, namespace: activeEnergySampleNamespace)
            async let restingSamples = hourlySamples(for: HealthKitCatalog.restingEnergyBurnedType, unit: HealthKitCatalog.kilocalorieUnit, dayStart: dayStart, namespace: totalEnergySampleNamespace ^ activeEnergySampleNamespace)
            let resolvedActiveSamples = try await activeSamples
            let resolvedRestingSamples = try await restingSamples
            energyByDay[dayStart] = HealthEnergyDaySamples(totalSamples: combinedSamples(lhs: resolvedActiveSamples, rhs: resolvedRestingSamples, namespace: totalEnergySampleNamespace), activeSamples: resolvedActiveSamples)
            energyLoadErrorMessage = nil
            loadedEnergyDays.insert(dayStart)
        } catch {
            energyLoadErrorMessage = "Unable to load Apple Health intraday energy right now."
            print("Failed to load Apple Health intraday energy: \(error)")
        }
    }

    private func hourlySamples(for type: HKQuantityType, unit: HKUnit, dayStart: Date, namespace: UInt64) async throws -> [TimeSeriesSample] {
        let dayEndExclusive = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let predicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEndExclusive)
        let samplePredicate = HKSamplePredicate.quantitySample(type: type, predicate: predicate)
        let descriptor = HKStatisticsCollectionQueryDescriptor(predicate: samplePredicate, options: .cumulativeSum, anchorDate: dayStart, intervalComponents: DateComponents(hour: 1))
        let result = try await descriptor.result(for: healthStore)

        var samples: [TimeSeriesSample] = []
        result.enumerateStatistics(from: dayStart, to: dayEndExclusive) { statistics, _ in
            let value = max(0, statistics.sumQuantity()?.doubleValue(for: unit) ?? 0)
            guard value > 0 else { return }
            let hourStart = statistics.startDate
            samples.append(TimeSeriesSample(id: stableTimeSeriesSampleID(namespace: namespace, date: hourStart), date: hourStart, value: value))
        }
        return samples.sorted { $0.date < $1.date }
    }

    private func combinedSamples(lhs: [TimeSeriesSample], rhs: [TimeSeriesSample], namespace: UInt64) -> [TimeSeriesSample] {
        let totals = Dictionary(grouping: lhs + rhs, by: \.date)
        return totals.keys.sorted(by: <).map { date in
            let total = totals[date, default: []].reduce(0) { $0 + $1.value }
            return TimeSeriesSample(id: stableTimeSeriesSampleID(namespace: namespace, date: date), date: date, value: total)
        }
    }
}
