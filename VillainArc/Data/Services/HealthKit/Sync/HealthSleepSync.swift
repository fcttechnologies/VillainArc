import Foundation
import HealthKit
import SwiftData

actor HealthSleepSync {
    private struct ReconstructedSleepBlock {
        let interval: DateInterval
        let wakeDay: Date
        let asleepDuration: TimeInterval
        let inBedDuration: TimeInterval
        let awakeDuration: TimeInterval
        let remDuration: TimeInterval
        let coreDuration: TimeInterval
        let deepDuration: TimeInterval
        let asleepUnspecifiedDuration: TimeInterval
    }

    private struct SleepNightSummary {
        let sleepStart: Date
        let sleepEnd: Date
        let allSleepStart: Date
        let allSleepEnd: Date
        let timeAsleep: TimeInterval
        let timeInBed: TimeInterval
        let awakeDuration: TimeInterval
        let remDuration: TimeInterval
        let coreDuration: TimeInterval
        let deepDuration: TimeInterval
        let asleepUnspecifiedDuration: TimeInterval
        let napDuration: TimeInterval
        let blocks: [ReconstructedSleepBlock]
    }

    static let shared = HealthSleepSync()

    private let mergeGapTolerance: TimeInterval = 60 * 60

    private var isSyncingSleepNights = false
    private var needsAnotherSleepNightSync = false

    private init() {}

    func syncAll() async { await syncSleepNights() }

    func syncSleepNights() async {
        guard HealthAuthorizationManager.isHealthDataAvailable else { return }
        guard HealthAuthorizationManager.hasRequestedSleepAnalysisAuthorization else { return }

        if isSyncingSleepNights {
            needsAnotherSleepNightSync = true
            return
        }

        while true {
            isSyncingSleepNights = true
            needsAnotherSleepNightSync = false

            let context = makeBackgroundContext()
            guard let syncState = try? SystemState.healthSyncState(context: context) else {
                isSyncingSleepNights = false
                return
            }

            let syncedRange = syncState.sleepWakeDaySyncedRange
            let usesInitialImport = syncedRange == nil
            let anchor = usesInitialImport ? nil : HealthSyncPreferences.sleepAnalysisAnchor
            let retainRemovedHealthData = currentKeepRemovedHealthDataSetting(context: context)

            do {
                let result = try await anchoredResult(anchor: anchor)
                let shouldAdvanceSyncState = await shouldAdvanceSyncState(for: result)
                let refreshedRange = refreshRange(addedSamples: result.addedSamples, syncedRange: syncedRange, hasDeletions: !result.deletedObjects.isEmpty)
                var sleepGoalNotification: SleepGoalNotification?

                if let refreshedRange {
                    let samples = try await sleepSamples(inWakeDayRange: refreshedRange)
                    let summariesByWakeDay = summarizeNights(from: samples, in: refreshedRange)
                    try rebuildWakeDays(in: refreshedRange, summariesByWakeDay: summariesByWakeDay, retainRemovedHealthData: retainRemovedHealthData, context: context)

                    let todayWakeDay = HealthSleepNight.wakeDayKey(for: .now)
                    if refreshedRange.contains(todayWakeDay) {
                        let todaySummary = try context.fetch(HealthSleepNight.forStoredWakeDayKey(todayWakeDay)).first
                        sleepGoalNotification = try SleepGoalEvaluator.reconcileToday(summary: todaySummary, syncState: syncState, context: context)
                    }

                    try context.save()
                }

                if shouldAdvanceSyncState {
                    HealthSyncPreferences.sleepAnalysisAnchor = result.newAnchor
                    syncState.sleepWakeDaySyncedRange = refreshedRange.map {
                        expandedSyncedRange(afterRefreshing: $0, existingRange: syncedRange)
                    } ?? syncedRange
                    try context.save()
                }

                logSleepSyncIfNeeded(refreshedRange: refreshedRange)
                if let sleepGoalNotification {
                    await NotificationCoordinator.deliverSleepGoal(sleepGoalNotification)
                }
            } catch {
                print("Failed to sync Apple Health sleep summaries: \(error)")
            }

            isSyncingSleepNights = false
            guard needsAnotherSleepNightSync else { return }
        }
    }

    private func anchoredResult(anchor: HKQueryAnchor?) async throws -> HKAnchoredObjectQueryDescriptor<HKCategorySample>.Result {
        let descriptor = HKAnchoredObjectQueryDescriptor(predicates: [.categorySample(type: HealthKitCatalog.sleepAnalysisType)], anchor: anchor)
        return try await descriptor.result(for: HealthAuthorizationManager.healthStore)
    }

    private func shouldAdvanceSyncState(for result: HKAnchoredObjectQueryDescriptor<HKCategorySample>.Result) async -> Bool {
        if !result.addedSamples.isEmpty || !result.deletedObjects.isEmpty { return true }
        return await HealthReadProbe.hasReadableCategorySample(for: HealthKitCatalog.sleepAnalysisType)
    }

    private func refreshRange(addedSamples: [HKCategorySample], syncedRange: ClosedRange<Date>?, hasDeletions: Bool) -> ClosedRange<Date>? {
        let changedRange = approximateWakeDayRange(for: addedSamples)

        if hasDeletions {
            return mergedRange(syncedRange, changedRange)
        }

        guard let changedRange else { return nil }
        guard let syncedRange else { return changedRange }

        if changedRange.lowerBound > syncedRange.upperBound {
            let gapStart = HealthSleepNight.nextWakeDay(after: syncedRange.upperBound)
            return gapStart...changedRange.upperBound
        }

        if changedRange.upperBound < syncedRange.lowerBound {
            let gapEnd = HealthSleepNight.previousWakeDay(before: syncedRange.lowerBound)
            return changedRange.lowerBound...gapEnd
        }

        return changedRange
    }

    private func expandedSyncedRange(afterRefreshing refreshedRange: ClosedRange<Date>, existingRange: ClosedRange<Date>?) -> ClosedRange<Date> {
        guard let existingRange else { return refreshedRange }
        return min(existingRange.lowerBound, refreshedRange.lowerBound)...max(existingRange.upperBound, refreshedRange.upperBound)
    }

    private func dateRange(from wakeDays: Set<Date>) -> ClosedRange<Date>? {
        guard let earliest = wakeDays.min(), let latest = wakeDays.max() else { return nil }
        return earliest...latest
    }

    private func approximateWakeDayRange(for samples: [HKCategorySample]) -> ClosedRange<Date>? {
        let candidateWakeDays = samples.flatMap { sample -> [Date] in
            let timeZone = timeZone(for: sample) ?? .autoupdatingCurrent
            return [
                HealthSleepNight.wakeDayKey(for: sample.startDate, in: timeZone),
                HealthSleepNight.wakeDayKey(for: sample.endDate, in: timeZone)
            ]
        }

        guard let changedRange = dateRange(from: Set(candidateWakeDays)) else { return nil }
        return paddedWakeDayRange(changedRange, days: 1)
    }

    private func paddedWakeDayRange(_ range: ClosedRange<Date>, days: Int) -> ClosedRange<Date> {
        var lowerBound = range.lowerBound
        var upperBound = range.upperBound

        for _ in 0..<max(days, 0) {
            lowerBound = HealthSleepNight.previousWakeDay(before: lowerBound)
            upperBound = HealthSleepNight.nextWakeDay(after: upperBound)
        }

        return lowerBound...upperBound
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

    private func sleepSamples(inWakeDayRange wakeDayRange: ClosedRange<Date>) async throws -> [HKCategorySample] {
        let queryRange = overlappingSampleQueryRange(for: wakeDayRange)
        let predicate = HKQuery.predicateForSamples(withStart: queryRange.lowerBound, end: queryRange.upperBound)
        let descriptor = HKSampleQueryDescriptor(predicates: [.categorySample(type: HealthKitCatalog.sleepAnalysisType, predicate: predicate)], sortDescriptors: [SortDescriptor(\.startDate), SortDescriptor(\.endDate)])
        return try await descriptor.result(for: HealthAuthorizationManager.healthStore)
    }

    private func overlappingSampleQueryRange(for wakeDayRange: ClosedRange<Date>) -> Range<Date> {
        let start = HealthSleepNight.previousWakeDay(before: wakeDayRange.lowerBound)
        let endExclusive = HealthSleepNight.nextWakeDay(after: wakeDayRange.upperBound)
        return start..<endExclusive
    }

    private func rebuildWakeDays(in wakeDayRange: ClosedRange<Date>, summariesByWakeDay: [Date: SleepNightSummary], retainRemovedHealthData: Bool, context: ModelContext) throws {
        var wakeDay = wakeDayRange.lowerBound

        while wakeDay <= wakeDayRange.upperBound {
            try rebuildWakeDay(wakeDay, summary: summariesByWakeDay[wakeDay], retainRemovedHealthData: retainRemovedHealthData, context: context)

            let nextWakeDay = HealthSleepNight.nextWakeDay(after: wakeDay)
            guard nextWakeDay > wakeDay else { break }
            wakeDay = nextWakeDay
        }
    }

    private func rebuildWakeDay(_ wakeDay: Date, summary: SleepNightSummary?, retainRemovedHealthData: Bool, context: ModelContext) throws {
        let existing = try context.fetch(HealthSleepNight.forStoredWakeDayKey(wakeDay)).first

        guard let summary else {
            if let existing {
                if retainRemovedHealthData {
                    existing.isAvailableInHealthKit = false
                } else {
                    context.delete(existing)
                }
            }
            return
        }

        let night = existing ?? HealthSleepNight(storedWakeDayKey: wakeDay)
        night.wakeDay = wakeDay
        night.sleepStart = summary.sleepStart
        night.sleepEnd = summary.sleepEnd
        night.allSleepStart = summary.allSleepStart
        night.allSleepEnd = summary.allSleepEnd
        night.timeAsleep = summary.timeAsleep
        night.timeInBed = summary.timeInBed
        night.awakeDuration = summary.awakeDuration
        night.remDuration = summary.remDuration
        night.coreDuration = summary.coreDuration
        night.deepDuration = summary.deepDuration
        night.asleepUnspecifiedDuration = summary.asleepUnspecifiedDuration
        night.napDuration = summary.napDuration
        night.isAvailableInHealthKit = true

        if existing == nil {
            context.insert(night)
        }

        replaceBlocks(for: night, with: summary.blocks, context: context)
    }

    private func summarizeNights(from samples: [HKCategorySample], in wakeDayRange: ClosedRange<Date>) -> [Date: SleepNightSummary] {
        let inBedIntervals = intervals(for: .inBed, in: samples)
        let awakeIntervals = intervals(for: .awake, in: samples)
        let asleepIntervals = allAsleepIntervals(in: samples)
        let basisIntervals = if !inBedIntervals.isEmpty {
            inBedIntervals
        } else if !asleepIntervals.isEmpty {
            asleepIntervals
        } else {
            awakeIntervals
        }

        let remIntervals = intervals(for: .asleepREM, in: samples)
        let coreIntervals = intervals(for: .asleepCore, in: samples)
        let deepIntervals = intervals(for: .asleepDeep, in: samples)
        let unspecifiedIntervals = unspecifiedSleepIntervals(in: samples)
        let blocks = mergedIntervals(basisIntervals, gapTolerance: mergeGapTolerance).map { ReconstructedSleepBlock(interval: $0, wakeDay: wakeDay(for: $0, from: samples), asleepDuration: totalDuration(of: asleepIntervals, clippedTo: $0), inBedDuration: inBedIntervals.isEmpty ? $0.duration : totalDuration(of: inBedIntervals, clippedTo: $0), awakeDuration: totalDuration(of: awakeIntervals, clippedTo: $0), remDuration: totalDuration(of: remIntervals, clippedTo: $0), coreDuration: totalDuration(of: coreIntervals, clippedTo: $0), deepDuration: totalDuration(of: deepIntervals, clippedTo: $0), asleepUnspecifiedDuration: totalDuration(of: unspecifiedIntervals, clippedTo: $0)) }

        return Dictionary(grouping: blocks.filter { $0.wakeDay >= wakeDayRange.lowerBound && $0.wakeDay <= wakeDayRange.upperBound }, by: \.wakeDay)
            .compactMapValues { summarizeNight(blocks: $0) }
    }

    private func summarizeNight(blocks: [ReconstructedSleepBlock]) -> SleepNightSummary? {
        guard let primaryBlock = selectPrimaryBlock(from: blocks) else { return nil }
        guard let allSleepStart = blocks.map(\.interval.start).min(), let allSleepEnd = blocks.map(\.interval.end).max() else { return nil }

        let totalTimeAsleep = blocks.reduce(0) { $0 + $1.asleepDuration }
        let totalTimeInBed = blocks.reduce(0) { $0 + $1.inBedDuration }
        let totalAwakeDuration = blocks.reduce(0) { $0 + $1.awakeDuration }
        let totalRemDuration = blocks.reduce(0) { $0 + $1.remDuration }
        let totalCoreDuration = blocks.reduce(0) { $0 + $1.coreDuration }
        let totalDeepDuration = blocks.reduce(0) { $0 + $1.deepDuration }
        let totalAsleepUnspecifiedDuration = blocks.reduce(0) { $0 + $1.asleepUnspecifiedDuration }
        let napDuration = max(0, totalTimeAsleep - primaryBlock.asleepDuration)

        return SleepNightSummary(sleepStart: primaryBlock.interval.start, sleepEnd: primaryBlock.interval.end, allSleepStart: allSleepStart, allSleepEnd: allSleepEnd, timeAsleep: max(0, totalTimeAsleep), timeInBed: max(0, totalTimeInBed), awakeDuration: max(0, totalAwakeDuration), remDuration: max(0, totalRemDuration), coreDuration: max(0, totalCoreDuration), deepDuration: max(0, totalDeepDuration), asleepUnspecifiedDuration: max(0, totalAsleepUnspecifiedDuration), napDuration: napDuration, blocks: blocks)
    }

    private func selectPrimaryBlock(from blocks: [ReconstructedSleepBlock]) -> ReconstructedSleepBlock? {
        blocks.max { lhs, rhs in
            if lhs.asleepDuration != rhs.asleepDuration {
                return lhs.asleepDuration < rhs.asleepDuration
            }
            if lhs.inBedDuration != rhs.inBedDuration {
                return lhs.inBedDuration < rhs.inBedDuration
            }
            if lhs.interval.duration != rhs.interval.duration {
                return lhs.interval.duration < rhs.interval.duration
            }
            return lhs.interval.end < rhs.interval.end
        }
    }

    private func intervals(for value: HKCategoryValueSleepAnalysis, in samples: [HKCategorySample]) -> [DateInterval] {
        samples.compactMap { sample in
            guard sleepValue(for: sample) == value else { return nil }
            return interval(sample)
        }
    }

    private func unspecifiedSleepIntervals(in samples: [HKCategorySample]) -> [DateInterval] {
        samples.compactMap { sample in
            guard let value = sleepValue(for: sample) else { return nil }
            switch value {
            case .asleep, .asleepUnspecified:
                return interval(sample)
            default:
                return nil
            }
        }
    }

    private func allAsleepIntervals(in samples: [HKCategorySample]) -> [DateInterval] {
        samples.compactMap { sample in
            guard let value = sleepValue(for: sample), HKCategoryValueSleepAnalysis.allAsleepValues.contains(value) else { return nil }
            return interval(sample)
        }
    }

    private func totalDuration(of intervals: [DateInterval], clippedTo clipInterval: DateInterval) -> TimeInterval {
        mergedIntervals(intervals.compactMap { interval in
            let start = max(interval.start, clipInterval.start)
            let end = min(interval.end, clipInterval.end)
            guard end > start else { return nil }
            return DateInterval(start: start, end: end)
        }, gapTolerance: 0)
        .reduce(0) { $0 + $1.duration }
    }

    private func mergedIntervals(_ intervals: [DateInterval], gapTolerance: TimeInterval) -> [DateInterval] {
        let sortedIntervals = intervals.sorted {
            if $0.start == $1.start { return $0.end < $1.end }
            return $0.start < $1.start
        }

        guard let first = sortedIntervals.first else { return [] }
        var merged: [DateInterval] = [first]

        for interval in sortedIntervals.dropFirst() {
            guard let last = merged.last else {
                merged.append(interval)
                continue
            }

            if interval.start <= last.end.addingTimeInterval(gapTolerance) {
                let combined = DateInterval(start: last.start, end: max(last.end, interval.end))
                merged[merged.count - 1] = combined
            } else {
                merged.append(interval)
            }
        }

        return merged
    }

    private func interval(_ sample: HKCategorySample) -> DateInterval { DateInterval(start: sample.startDate, end: sample.endDate) }

    private func sleepValue(for sample: HKCategorySample) -> HKCategoryValueSleepAnalysis? { HKCategoryValueSleepAnalysis(rawValue: sample.value) }

    private func wakeDay(for interval: DateInterval, from samples: [HKCategorySample]) -> Date {
        let blockTimeZone = timeZone(forBlockInterval: interval, from: samples) ?? .autoupdatingCurrent
        return HealthSleepNight.wakeDayKey(for: interval.end, in: blockTimeZone)
    }

    private func timeZone(forBlockInterval blockInterval: DateInterval, from samples: [HKCategorySample]) -> TimeZone? {
        samples
            .filter { interval($0).intersects(blockInterval) }
            .sorted { lhs, rhs in
                if lhs.endDate == rhs.endDate { return lhs.startDate > rhs.startDate }
                return lhs.endDate > rhs.endDate
            }
            .compactMap(timeZone(for:))
            .first
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

    private func logSleepSyncIfNeeded(refreshedRange: ClosedRange<Date>?) {
        guard let refreshedRange else { return }
        print("Synced Apple Health sleep summaries for \(formattedWakeDayRange(refreshedRange)).")
    }

    private func formattedWakeDayRange(_ range: ClosedRange<Date>) -> String {
        let startText = wakeDayLogText(range.lowerBound)
        let endText = wakeDayLogText(range.upperBound)
        return range.lowerBound == range.upperBound ? startText : "\(startText) to \(endText)"
    }

    private func wakeDayLogText(_ wakeDay: Date) -> String { HealthSleepNight.displayDate(forWakeDay: wakeDay).formatted(.dateTime.month(.abbreviated).day().year()) }

    private func currentKeepRemovedHealthDataSetting(context: ModelContext) -> Bool { (try? context.fetch(AppSettings.single).first?.keepRemovedHealthData) ?? true }

    private func replaceBlocks(for night: HealthSleepNight, with blocks: [ReconstructedSleepBlock], context: ModelContext) {
        for block in Array(night.blocks ?? []) {
            context.delete(block)
        }

        night.blocks = blocks
            .sorted {
                if $0.interval.start == $1.interval.start { return $0.interval.end < $1.interval.end }
                return $0.interval.start < $1.interval.start
            }
            .map { block in
                let persistedBlock = HealthSleepBlock(startDate: block.interval.start, endDate: block.interval.end, isPrimary: block.interval.start == night.sleepStart && block.interval.end == night.sleepEnd, timeAsleep: max(0, block.asleepDuration), timeInBed: max(0, block.inBedDuration), awakeDuration: max(0, block.awakeDuration), remDuration: max(0, block.remDuration), coreDuration: max(0, block.coreDuration), deepDuration: max(0, block.deepDuration), asleepUnspecifiedDuration: max(0, block.asleepUnspecifiedDuration), night: night)
                context.insert(persistedBlock)
                return persistedBlock
            }
    }

    private func makeBackgroundContext() -> ModelContext {
        let context = ModelContext(SharedModelContainer.container)
        context.autosaveEnabled = false
        return context
    }
}
