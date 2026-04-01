import Foundation
import HealthKit
import Observation

enum HealthSleepStage: String, CaseIterable, Sendable {
    case awake
    case rem
    case core
    case asleep
    case deep

    var title: String {
        switch self {
        case .awake:
            return "Awake"
        case .rem:
            return "REM"
        case .core:
            return "Core"
        case .asleep:
            return "Asleep"
        case .deep:
            return "Deep"
        }
    }
}

struct HealthSleepStageInterval: Identifiable, Hashable, Sendable {
    let wakeDay: Date
    let startDate: Date
    let endDate: Date
    let stage: HealthSleepStage
    let timeZoneIdentifier: String?
    let isApproximate: Bool

    var id: String { "\(stage.rawValue)-\(wakeDay.timeIntervalSinceReferenceDate)-\(startDate.timeIntervalSinceReferenceDate)-\(endDate.timeIntervalSinceReferenceDate)-\(isApproximate)" }
    var duration: TimeInterval { max(0, endDate.timeIntervalSince(startDate)) }
}

@Observable final class HealthSleepHistoryLoader {
    private let healthStore = HealthAuthorizationManager.healthStore
    private let queryPadding: TimeInterval = 60 * 60

    private(set) var intervalsByWakeDay: [Date: [HealthSleepStageInterval]] = [:]
    private(set) var loadedDayWakeDays: Set<Date> = []

    var isLoadingDay = false
    var loadErrorMessage: String?

    private var hasStartedInitialLoad = false

    func loadInitialIfNeeded(latestNight: HealthSleepNight?) async {
        guard !hasStartedInitialLoad else { return }
        guard let latestNight else { return }

        hasStartedInitialLoad = true

        await loadDayIfNeeded(night: latestNight)
    }

    func loadDayIfNeeded(night: HealthSleepNight) async {
        guard HealthAuthorizationManager.isHealthDataAvailable else { return }
        guard HealthAuthorizationManager.hasRequestedSleepAnalysisAuthorization else { return }
        guard !hasLoadedIntervals(for: night.wakeDay) else { return }
        guard !isLoadingDay else { return }

        isLoadingDay = true
        defer { isLoadingDay = false }

        await loadIntervals(for: night) {
            self.loadedDayWakeDays.insert(night.wakeDay)
        }
    }

    private func loadIntervals(for night: HealthSleepNight, onSuccess: () -> Void) async {
        do {
            intervalsByWakeDay[night.wakeDay] = try await stageIntervals(for: night)
            loadErrorMessage = nil
            onSuccess()
        } catch {
            loadErrorMessage = "Unable to load Apple Health sleep stages right now."
            print("Failed to load Apple Health sleep history intervals: \(error)")
        }
    }

    private func stageIntervals(for night: HealthSleepNight) async throws -> [HealthSleepStageInterval] {
        let blockIntervals = persistedBlockIntervals(for: night)
        guard let queryRange = sampleQueryRange(for: night, blockIntervals: blockIntervals) else { return [] }

        let predicate = HKQuery.predicateForSamples(withStart: queryRange.lowerBound, end: queryRange.upperBound)
        let descriptor = HKSampleQueryDescriptor(predicates: [.categorySample(type: HealthKitCatalog.sleepAnalysisType, predicate: predicate)], sortDescriptors: [SortDescriptor(\.endDate), SortDescriptor(\.startDate)])
        let samples = try await descriptor.result(for: healthStore)

        return samples.compactMap { stageInterval(from: $0, wakeDay: night.wakeDay, blockIntervals: blockIntervals) }
            .sorted {
                if $0.startDate == $1.startDate { return $0.endDate < $1.endDate }
                return $0.startDate < $1.startDate
            }
    }

    private func stageInterval(from sample: HKCategorySample, wakeDay: Date, blockIntervals: [DateInterval]) -> HealthSleepStageInterval? {
        guard let stage = stage(for: sample) else { return nil }
        let sampleInterval = DateInterval(start: sample.startDate, end: sample.endDate)
        guard blockIntervals.contains(where: { $0.intersects(sampleInterval) }) else { return nil }
        let timeZone = timeZone(for: sample)
        return HealthSleepStageInterval(wakeDay: wakeDay, startDate: sample.startDate, endDate: sample.endDate, stage: stage, timeZoneIdentifier: timeZone?.identifier, isApproximate: false)
    }

    private func stage(for sample: HKCategorySample) -> HealthSleepStage? {
        guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { return nil }

        switch value {
        case .awake:
            return .awake
        case .asleepREM:
            return .rem
        case .asleepCore:
            return .core
        case .asleep, .asleepUnspecified:
            return .asleep
        case .asleepDeep:
            return .deep
        default:
            return nil
        }
    }

    private func timeZone(for sample: HKCategorySample) -> TimeZone? {
        if let identifier = sample.metadata?[HKMetadataKeyTimeZone] as? String {
            return TimeZone(identifier: identifier)
        }
        if let timeZone = sample.metadata?[HKMetadataKeyTimeZone] as? TimeZone {
            return timeZone
        }
        if let timeZone = sample.metadata?[HKMetadataKeyTimeZone] as? NSTimeZone {
            return timeZone as TimeZone
        }
        return nil
    }

    private func hasLoadedIntervals(for wakeDay: Date) -> Bool { loadedDayWakeDays.contains(wakeDay) }

    private func persistedBlockIntervals(for night: HealthSleepNight) -> [DateInterval] {
        let intervals = night.sortedBlocks.map { DateInterval(start: $0.startDate, end: $0.endDate) }
        if !intervals.isEmpty { return intervals }
        if let allSleepStart = night.allSleepStart, let allSleepEnd = night.allSleepEnd, allSleepEnd > allSleepStart {
            return [DateInterval(start: allSleepStart, end: allSleepEnd)]
        }
        if let sleepStart = night.sleepStart, let sleepEnd = night.sleepEnd, sleepEnd > sleepStart {
            return [DateInterval(start: sleepStart, end: sleepEnd)]
        }
        return []
    }

    private func sampleQueryRange(for night: HealthSleepNight, blockIntervals: [DateInterval]) -> Range<Date>? {
        if let earliestStart = blockIntervals.map(\.start).min(), let latestEnd = blockIntervals.map(\.end).max() {
            return earliestStart.addingTimeInterval(-queryPadding)..<latestEnd.addingTimeInterval(queryPadding)
        }
        if let allSleepStart = night.allSleepStart, let allSleepEnd = night.allSleepEnd, allSleepEnd > allSleepStart {
            return allSleepStart.addingTimeInterval(-queryPadding)..<allSleepEnd.addingTimeInterval(queryPadding)
        }
        if let sleepStart = night.sleepStart, let sleepEnd = night.sleepEnd, sleepEnd > sleepStart {
            return sleepStart.addingTimeInterval(-queryPadding)..<sleepEnd.addingTimeInterval(queryPadding)
        }
        return nil
    }
}
