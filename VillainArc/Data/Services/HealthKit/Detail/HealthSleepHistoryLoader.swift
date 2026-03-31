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

    private(set) var intervalsByWakeDay: [Date: [HealthSleepStageInterval]] = [:]
    private(set) var loadedDayWakeDays: Set<Date> = []

    var isLoadingDay = false
    var loadErrorMessage: String?

    private var hasStartedInitialLoad = false

    func loadInitialIfNeeded(latestWakeDay: Date?) async {
        guard !hasStartedInitialLoad else { return }
        guard let latestWakeDay else { return }

        hasStartedInitialLoad = true

        await loadDayIfNeeded(wakeDay: latestWakeDay)
    }

    func loadDayIfNeeded(wakeDay: Date) async {
        guard HealthAuthorizationManager.isHealthDataAvailable else { return }
        guard HealthAuthorizationManager.hasRequestedSleepAnalysisAuthorization else { return }
        guard !hasLoadedIntervals(for: wakeDay) else { return }
        guard !isLoadingDay else { return }

        isLoadingDay = true
        defer { isLoadingDay = false }

        await loadIntervals(for: wakeDay) {
            self.loadedDayWakeDays.insert(wakeDay)
        }
    }

    private func loadIntervals(for wakeDay: Date, onSuccess: () -> Void) async {
        do {
            intervalsByWakeDay[wakeDay] = try await stageIntervals(for: wakeDay)
            loadErrorMessage = nil
            onSuccess()
        } catch {
            loadErrorMessage = "Unable to load Apple Health sleep stages right now."
            print("Failed to load Apple Health sleep history intervals: \(error)")
        }
    }

    private func stageIntervals(for wakeDay: Date) async throws -> [HealthSleepStageInterval] {
        let queryRange = sampleEndDateQueryRange(for: wakeDay)
        let predicate = HKQuery.predicateForSamples(withStart: queryRange.lowerBound, end: queryRange.upperBound, options: .strictEndDate)
        let descriptor = HKSampleQueryDescriptor(predicates: [.categorySample(type: HealthKitCatalog.sleepAnalysisType, predicate: predicate)], sortDescriptors: [SortDescriptor(\.endDate), SortDescriptor(\.startDate)])
        let samples = try await descriptor.result(for: healthStore)

        return samples.compactMap(stageInterval(from:))
            .filter { $0.wakeDay == wakeDay }
            .sorted {
                if $0.startDate == $1.startDate { return $0.endDate < $1.endDate }
                return $0.startDate < $1.startDate
            }
    }

    private func stageInterval(from sample: HKCategorySample) -> HealthSleepStageInterval? {
        guard let stage = stage(for: sample) else { return nil }
        let timeZone = timeZone(for: sample)
        return HealthSleepStageInterval(wakeDay: HealthSleepNight.wakeDayKey(for: sample.endDate, in: timeZone ?? .autoupdatingCurrent), startDate: sample.startDate, endDate: sample.endDate, stage: stage, timeZoneIdentifier: timeZone?.identifier, isApproximate: false)
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

    private func sampleEndDateQueryRange(for wakeDay: Date) -> Range<Date> {
        let start = HealthSleepNight.previousWakeDay(before: wakeDay)
        let end = HealthSleepNight.nextWakeDay(after: HealthSleepNight.nextWakeDay(after: wakeDay))
        return start..<end
    }

    private func hasLoadedIntervals(for wakeDay: Date) -> Bool { loadedDayWakeDays.contains(wakeDay) }
}
