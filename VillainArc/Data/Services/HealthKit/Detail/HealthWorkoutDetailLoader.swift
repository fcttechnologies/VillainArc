import CoreLocation
import Foundation
import HealthKit
import Observation
import SwiftData

struct HealthWorkoutDetailSummary: Equatable {
    let activityType: HKWorkoutActivityType
    let isIndoorWorkout: Bool?
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let averageHeartRateBPM: Double?
    let maximumHeartRateBPM: Double?
    let activeEnergyBurned: Double?
    let restingEnergyBurned: Double?
    let totalDistance: Double?

    init(workout: HKWorkout) {
        let activeEnergyType = HKQuantityType(.activeEnergyBurned)
        let basalEnergyType = HKQuantityType(.basalEnergyBurned)
        let heartRateType = HKQuantityType(.heartRate)
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        let heartRateStats = workout.statistics(for: heartRateType)
        activityType = workout.workoutActivityType
        isIndoorWorkout = workout.metadata?[HKMetadataKeyIndoorWorkout] as? Bool
        startDate = workout.startDate
        endDate = workout.endDate
        duration = workout.duration
        averageHeartRateBPM = heartRateStats?.averageQuantity()?.doubleValue(for: bpmUnit)
        maximumHeartRateBPM = heartRateStats?.maximumQuantity()?.doubleValue(for: bpmUnit)
        activeEnergyBurned = workout.statistics(for: activeEnergyType)?.sumQuantity()?.doubleValue(for: .kilocalorie())
        restingEnergyBurned = workout.statistics(for: basalEnergyType)?.sumQuantity()?.doubleValue(for: .kilocalorie())
        totalDistance = workout.totalDistance?.doubleValue(for: .meter())
    }

    init(workout: HealthWorkout) {
        activityType = workout.activityType
        isIndoorWorkout = workout.isIndoorWorkout
        startDate = workout.startDate
        endDate = workout.endDate
        duration = workout.duration
        averageHeartRateBPM = workout.averageHeartRateBPM
        maximumHeartRateBPM = workout.maximumHeartRateBPM
        activeEnergyBurned = workout.activeEnergyBurned
        restingEnergyBurned = workout.restingEnergyBurned
        totalDistance = workout.totalDistance
    }

    var activityTypeDisplayName: String { activityType.displayName(indoorWorkout: isIndoorWorkout) }

    var activeDuration: TimeInterval { duration }

    var totalDuration: TimeInterval { max(endDate.timeIntervalSince(startDate), activeDuration) }

    var pausedDuration: TimeInterval { max(0, totalDuration - activeDuration) }

    var totalCalories: Double? {
        guard let activeEnergyBurned, let restingEnergyBurned else { return nil }
        return activeEnergyBurned + restingEnergyBurned
    }

    var heartRateSummary: HealthWorkoutHeartRateSummary {
        HealthWorkoutHeartRateSummary(averageBPM: averageHeartRateBPM, maximumBPM: maximumHeartRateBPM)
    }
}

struct HealthWorkoutHeartRatePoint: Identifiable, Hashable {
    let date: Date
    let bpm: Double
    var id: Date { date }
}

struct HealthWorkoutHeartRateSample: Hashable {
    let startDate: Date
    let endDate: Date
    let bpm: Double
    var representativeDate: Date { endDate > startDate ? endDate : startDate }
}

struct HealthWorkoutHeartRateSummary: Equatable {
    let averageBPM: Double?
    let maximumBPM: Double?
    var hasContent: Bool { averageBPM != nil || maximumBPM != nil }
}

struct HealthWorkoutHeartRateZoneSummary: Identifiable, Hashable {
    let zone: Int
    let lowerBoundBPM: Int?
    let upperBoundBPM: Int?
    let duration: TimeInterval
    let percentage: Double
    var id: Int { zone }
}

struct HealthWorkoutDetailMetric: Identifiable, Hashable {
    enum ValueStyle: Hashable {
        case integer
        case breathsPerMinute
        case watts
        case cadencePerMinute
        case milliseconds
        case centimeters
        case score
    }
    let title: String
    let value: Double
    let valueStyle: ValueStyle
    var id: String { title }
}

struct HealthWorkoutActivitySummary: Identifiable, Hashable {
    let id: UUID
    let title: String
    let duration: TimeInterval
    let energyBurned: Double?
}

struct HealthWorkoutEffortSummary: Equatable {
    enum Source: Equatable {
        case actualScore
        case estimatedScore
        case physicalEffort
    }
    let source: Source
    let value: Double
}

struct HealthWorkoutSplitSummary: Identifiable, Hashable {
    let id: Int
    let markerDistanceMeters: Double
    let segmentDistanceMeters: Double
    let duration: TimeInterval
    let averageHeartRate: Double?
}

private struct HealthWorkoutDistanceSample: Hashable {
    let startDate: Date
    let endDate: Date
    let distanceMeters: Double
}

private struct HealthWorkoutHeartRateInterval: Hashable {
    let startDate: Date
    let endDate: Date
    let bpm: Double
}

struct HealthWorkoutRoutePoint: Hashable {
    let latitude: Double
    let longitude: Double
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}

struct HealthWorkoutSummaryStats: Equatable {
    let averageHeartRate: Double?
    let totalEnergyBurned: Double?
}

enum HealthWorkoutSummaryStatsLoader {
    private static let healthStore = HealthAuthorizationManager.shared.healthStore

    static func load(for workout: HealthWorkout) async -> HealthWorkoutSummaryStats {
        let cachedStats = HealthWorkoutSummaryStats(averageHeartRate: workout.averageHeartRateBPM, totalEnergyBurned: workout.totalEnergyBurned)

        guard workout.isAvailableInHealthKit else { return cachedStats }

        do {
            let predicate = NSPredicate(format: "%K == %@", HKPredicateKeyPathUUID, workout.healthWorkoutUUID as NSUUID)
            let descriptor = HKSampleQueryDescriptor(predicates: [.workout(predicate)], sortDescriptors: [], limit: 1)

            guard let liveWorkout = try await descriptor.result(for: healthStore).first else { return cachedStats }

            let liveSummary = HealthWorkoutDetailSummary(workout: liveWorkout)
            return HealthWorkoutSummaryStats(averageHeartRate: liveSummary.averageHeartRateBPM, totalEnergyBurned: liveSummary.totalCalories ?? workout.totalEnergyBurned)
        } catch {
            print("Failed to load summary Health stats for \(workout.healthWorkoutUUID): \(error)")
            return cachedStats
        }
    }
}

@MainActor @Observable final class HealthWorkoutDetailLoader {
    private static let chartMaxPoints = 180
    private let cachedWorkout: HealthWorkout
    private let healthStore = HealthAuthorizationManager.shared.healthStore
    var summary: HealthWorkoutDetailSummary
    var heartRateSummary: HealthWorkoutHeartRateSummary
    var heartRatePoints: [HealthWorkoutHeartRatePoint] = []
    var heartRateZones: [HealthWorkoutHeartRateZoneSummary] = []
    var metrics: [HealthWorkoutDetailMetric] = []
    var activities: [HealthWorkoutActivitySummary] = []
    var effortSummary: HealthWorkoutEffortSummary?
    var splits: [HealthWorkoutSplitSummary] = []
    var routePoints: [HealthWorkoutRoutePoint] = []
    var isLoading = false
    var hasLoaded = false
    var isUsingCachedSummaryOnly: Bool
    var loadErrorMessage: String?
    private var loadedWorkout: HKWorkout?
    private var heartRateSamples: [HealthWorkoutHeartRateSample] = []
    private var distanceSamples: [HealthWorkoutDistanceSample] = []

    init(workout: HealthWorkout) {
        cachedWorkout = workout
        let cachedSummary = HealthWorkoutDetailSummary(workout: workout)
        summary = cachedSummary
        heartRateSummary = cachedSummary.heartRateSummary
        isUsingCachedSummaryOnly = !workout.isAvailableInHealthKit
    }
    func loadIfNeeded(distanceUnit: DistanceUnit, estimatedMaxHeartRate: Double?) async {
        guard !hasLoaded else {
            refreshDerivedData(distanceUnit: distanceUnit, estimatedMaxHeartRate: estimatedMaxHeartRate)
            return
        }
        await load(distanceUnit: distanceUnit, estimatedMaxHeartRate: estimatedMaxHeartRate)
    }
    func load(distanceUnit: DistanceUnit, estimatedMaxHeartRate: Double?) async {
        guard !isLoading else { return }
        isLoading = true
        loadErrorMessage = nil
        defer {
            isLoading = false
            hasLoaded = true
        }
        guard cachedWorkout.isAvailableInHealthKit else {
            isUsingCachedSummaryOnly = true
            refreshDerivedData(distanceUnit: distanceUnit, estimatedMaxHeartRate: estimatedMaxHeartRate)
            return
        }
        do {
            guard let workout = try await fetchWorkout() else {
                isUsingCachedSummaryOnly = true
                loadErrorMessage = "This workout is no longer available in Apple Health."
                markCachedWorkoutUnavailable()
                refreshDerivedData(distanceUnit: distanceUnit, estimatedMaxHeartRate: estimatedMaxHeartRate)
                return
            }
            loadedWorkout = workout
            let liveSummary = HealthWorkoutDetailSummary(workout: workout)
            summary = liveSummary
            heartRateSummary = liveSummary.heartRateSummary
            isUsingCachedSummaryOnly = false
            async let heartRateLoad = loadHeartRate(for: workout)
            async let distanceLoad = loadDistanceSamples(for: workout)
            async let effortLoad = loadEffort(for: workout)
            async let routeLoad = loadRoute(for: workout)
            let (loadedHeartRatePoints, loadedHeartRateSamples) = try await heartRateLoad
            let loadedDistanceSamples = try await distanceLoad
            let loadedEffortSummary = await effortLoad
            let loadedRoutePoints = try await routeLoad
            heartRatePoints = loadedHeartRatePoints
            heartRateSamples = loadedHeartRateSamples
            metrics = loadMetrics(for: workout)
            activities = makeActivitySummaries(from: workout.workoutActivities)
            distanceSamples = loadedDistanceSamples
            effortSummary = loadedEffortSummary
            routePoints = loadedRoutePoints
            refreshDerivedData(distanceUnit: distanceUnit, estimatedMaxHeartRate: estimatedMaxHeartRate)
        } catch {
            isUsingCachedSummaryOnly = true
            loadErrorMessage = "Unable to load live Apple Health details right now."
            refreshDerivedData(distanceUnit: distanceUnit, estimatedMaxHeartRate: estimatedMaxHeartRate)
            print("Failed to load Health workout details for \(cachedWorkout.healthWorkoutUUID): \(error)")
        }
    }
    private func loadEffort(for workout: HKWorkout) async -> HealthWorkoutEffortSummary? {
        do {
            let predicate = NSPredicate(format: "%K == %@", HKPredicateKeyPathUUID, workout.uuid as NSUUID)
            let descriptor = HKWorkoutEffortRelationshipQueryDescriptor(predicate: predicate, anchor: nil, option: .mostRelevant)
            let result = try await descriptor.result(for: healthStore)
            let relatedSamples = result.relationships.filter { $0.workout.uuid == workout.uuid }.flatMap { $0.samples ?? [] }
            if let summary = makeEffortSummary(from: relatedSamples) { return summary }
        } catch { print("Failed to load workout effort relationship for \(cachedWorkout.healthWorkoutUUID): \(error)") }
        return fallbackEffortSummary(from: workout)
    }
    func refreshDerivedData(distanceUnit: DistanceUnit, estimatedMaxHeartRate: Double?) {
        let workoutStart = loadedWorkout?.startDate ?? cachedWorkout.startDate
        let workoutEnd = loadedWorkout?.endDate ?? cachedWorkout.endDate
        heartRateZones = makeHeartRateZoneSummaries(from: heartRateSamples, workoutStart: workoutStart, workoutEnd: workoutEnd, estimatedMaxHeartRate: estimatedMaxHeartRate)
        splits = makeSplitSummaries(from: distanceSamples, heartRateSamples: heartRateSamples, workoutStart: workoutStart, workoutEnd: workoutEnd, distanceUnit: distanceUnit)
    }
    private func fetchWorkout() async throws -> HKWorkout? {
        let predicate = NSPredicate(format: "%K == %@", HKPredicateKeyPathUUID, cachedWorkout.healthWorkoutUUID as NSUUID)
        let descriptor = HKSampleQueryDescriptor(predicates: [.workout(predicate)], sortDescriptors: [], limit: 1)
        return try await descriptor.result(for: healthStore).first
    }
    private func loadHeartRate(for workout: HKWorkout) async throws -> ([HealthWorkoutHeartRatePoint], [HealthWorkoutHeartRateSample]) {
        let heartRateType = HKQuantityType(.heartRate)
        let workoutPredicate = HKQuery.predicateForObjects(from: workout)
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        let descriptor = HKSampleQueryDescriptor(predicates: [.quantitySample(type: heartRateType, predicate: workoutPredicate)], sortDescriptors: [SortDescriptor(\.startDate, order: .forward)], limit: HKObjectQueryNoLimit)
        let samples = try await descriptor.result(for: healthStore)
        let heartRateSamples = samples.map { sample in HealthWorkoutHeartRateSample(startDate: sample.startDate, endDate: sample.endDate, bpm: sample.quantity.doubleValue(for: bpmUnit)) }.filter { $0.bpm > 0 }.sorted { $0.representativeDate < $1.representativeDate }
        let points = heartRateSamples.map { sample in HealthWorkoutHeartRatePoint(date: sample.representativeDate, bpm: sample.bpm) }
        return (downsampledHeartRatePoints(from: points, maxPoints: Self.chartMaxPoints), heartRateSamples)
    }
    private func loadDistanceSamples(for workout: HKWorkout) async throws -> [HealthWorkoutDistanceSample] {
        guard let distanceType = distanceType(for: workout.workoutActivityType) else { return [] }
        let workoutPredicate = HKQuery.predicateForObjects(from: workout)
        let descriptor = HKSampleQueryDescriptor(predicates: [.quantitySample(type: distanceType, predicate: workoutPredicate)], sortDescriptors: [SortDescriptor(\.startDate, order: .forward)], limit: HKObjectQueryNoLimit)
        return try await descriptor.result(for: healthStore)
            .compactMap { sample in
                let distanceMeters = sample.quantity.doubleValue(for: .meter())
                guard distanceMeters > 0 else { return nil }
                let endDate = sample.endDate > sample.startDate ? sample.endDate : sample.startDate
                return HealthWorkoutDistanceSample(startDate: sample.startDate, endDate: endDate, distanceMeters: distanceMeters)
            }
    }
    private func loadRoute(for workout: HKWorkout) async throws -> [HealthWorkoutRoutePoint] {
        let workoutPredicate = HKQuery.predicateForObjects(from: workout)
        let descriptor = HKSampleQueryDescriptor(predicates: [.workoutRoute(workoutPredicate)], sortDescriptors: [SortDescriptor(\.startDate, order: .forward)], limit: HKObjectQueryNoLimit)
        let routes = try await descriptor.result(for: healthStore)
        guard !routes.isEmpty else { return [] }
        var coordinates: [CLLocationCoordinate2D] = []
        for route in routes {
            let routeDescriptor = HKWorkoutRouteQueryDescriptor(route)
            for try await location in routeDescriptor.results(for: healthStore) {
                let coordinate = location.coordinate
                guard CLLocationCoordinate2DIsValid(coordinate) else { continue }
                if let last = coordinates.last, abs(last.latitude - coordinate.latitude) < 0.000_001, abs(last.longitude - coordinate.longitude) < 0.000_001 { continue }
                coordinates.append(coordinate)
            }
        }
        return downsampledRouteCoordinates(from: coordinates, maxPoints: 600).map { HealthWorkoutRoutePoint(latitude: $0.latitude, longitude: $0.longitude) }
    }
    private func loadMetrics(for workout: HKWorkout) -> [HealthWorkoutDetailMetric] {
        var items: [HealthWorkoutDetailMetric] = []
        let flightsClimbedType = HKQuantityType(.flightsClimbed)
        let swimmingStrokeCountType = HKQuantityType(.swimmingStrokeCount)
        if let flights = workout.statistics(for: flightsClimbedType)?.sumQuantity()?.doubleValue(for: .count()), flights > 0 {
            items.append(.init(title: "Flights Climbed", value: flights, valueStyle: .integer))
        }
        if let strokes = workout.statistics(for: swimmingStrokeCountType)?.sumQuantity()?.doubleValue(for: .count()), strokes > 0 {
            items.append(.init(title: "Swim Strokes", value: strokes, valueStyle: .integer))
        }
        appendAverageMetric(title: "Respiratory Rate", type: .respiratoryRate, unit: .count().unitDivided(by: .minute()), style: .breathsPerMinute, from: workout, to: &items)
        appendAverageMetric(title: "Running Power", type: .runningPower, unit: .watt(), style: .watts, from: workout, to: &items)
        appendAverageMetric(title: "Cycling Power", type: .cyclingPower, unit: .watt(), style: .watts, from: workout, to: &items)
        appendAverageMetric(title: "Cycling Cadence", type: .cyclingCadence, unit: .count().unitDivided(by: .minute()), style: .cadencePerMinute, from: workout, to: &items)
        appendAverageMetric(title: "Stride Length", type: .runningStrideLength, unit: .meter(), style: .centimeters, from: workout, to: &items)
        appendAverageMetric(title: "Ground Contact", type: .runningGroundContactTime, unit: .secondUnit(with: .milli), style: .milliseconds, from: workout, to: &items)
        appendAverageMetric(title: "Vertical Oscillation", type: .runningVerticalOscillation, unit: .meter(), style: .centimeters, from: workout, to: &items)
        return items
    }
    private func appendAverageMetric(title: String, type: HKQuantityTypeIdentifier, unit: HKUnit, style: HealthWorkoutDetailMetric.ValueStyle, from workout: HKWorkout, to items: inout [HealthWorkoutDetailMetric]) {
        let quantityType = HKQuantityType(type)
        guard let value = workout.statistics(for: quantityType)?.averageQuantity()?.doubleValue(for: unit), value > 0 else { return }
        items.append(.init(title: title, value: value, valueStyle: style))
    }
    private func makeActivitySummaries(from workoutActivities: [HKWorkoutActivity]) -> [HealthWorkoutActivitySummary] {
        let activeEnergyType = HKQuantityType(.activeEnergyBurned)
        return workoutActivities.map { activity in
            let energyBurned = activity.statistics(for: activeEnergyType)?.sumQuantity()?.doubleValue(for: .kilocalorie())
            return HealthWorkoutActivitySummary(id: activity.uuid, title: activity.workoutConfiguration.activityType.displayName, duration: activity.duration, energyBurned: energyBurned)
        }
    }
    private func downsampledHeartRatePoints(from points: [HealthWorkoutHeartRatePoint], maxPoints: Int) -> [HealthWorkoutHeartRatePoint] {
        guard points.count > maxPoints, maxPoints > 1 else { return points }
        let stride = Double(points.count - 1) / Double(maxPoints - 1)
        return (0..<maxPoints)
            .compactMap { index in
                let pointIndex = Int((Double(index) * stride).rounded())
                guard points.indices.contains(pointIndex) else { return nil }
                return points[pointIndex]
            }
    }
    private func downsampledRouteCoordinates(from coordinates: [CLLocationCoordinate2D], maxPoints: Int) -> [CLLocationCoordinate2D] {
        guard coordinates.count > maxPoints, maxPoints > 1 else { return coordinates }
        let stride = Double(coordinates.count - 1) / Double(maxPoints - 1)
        return (0..<maxPoints)
            .compactMap { index in
                let pointIndex = Int((Double(index) * stride).rounded())
                guard coordinates.indices.contains(pointIndex) else { return nil }
                return coordinates[pointIndex]
            }
    }
    private func distanceType(for activityType: HKWorkoutActivityType) -> HKQuantityType? {
        switch activityType {
        case .walking, .running, .hiking: return HKQuantityType(.distanceWalkingRunning)
        case .wheelchairWalkPace, .wheelchairRunPace: return HKQuantityType(.distanceWheelchair)
        case .cycling: return HKQuantityType(.distanceCycling)
        case .swimming: return HKQuantityType(.distanceSwimming)
        case .rowing: return HKQuantityType(.distanceRowing)
        case .paddleSports: return HKQuantityType(.distancePaddleSports)
        case .crossCountrySkiing: return HKQuantityType(.distanceCrossCountrySkiing)
        default: return nil
        }
    }
    private func makeHeartRateZoneSummaries(from samples: [HealthWorkoutHeartRateSample], workoutStart: Date, workoutEnd: Date, estimatedMaxHeartRate: Double?) -> [HealthWorkoutHeartRateZoneSummary] {
        guard let estimatedMaxHeartRate, estimatedMaxHeartRate > 0 else { return [] }
        let intervals = makeHeartRateIntervals(from: samples, workoutStart: workoutStart, workoutEnd: workoutEnd)
        guard !intervals.isEmpty else { return [] }
        var durationsByZone = Dictionary(uniqueKeysWithValues: (1...5).map { ($0, 0.0) })
        for interval in intervals {
            let zone = heartRateZone(for: interval.bpm, estimatedMaxHeartRate: estimatedMaxHeartRate)
            durationsByZone[zone, default: 0] += interval.endDate.timeIntervalSince(interval.startDate)
        }
        let trackedDuration = durationsByZone.values.reduce(0, +)
        guard trackedDuration > 0 else { return [] }
        return (1...5)
            .compactMap { zone in
                let duration = durationsByZone[zone, default: 0]
                guard duration > 0 else { return nil }
                let (lowerBoundBPM, upperBoundBPM) = heartRateBounds(for: zone, estimatedMaxHeartRate: estimatedMaxHeartRate)
                return HealthWorkoutHeartRateZoneSummary(zone: zone, lowerBoundBPM: lowerBoundBPM.map { Int($0.rounded(.down)) }, upperBoundBPM: upperBoundBPM.map { Int($0.rounded(.down)) }, duration: duration, percentage: duration / trackedDuration)
            }
    }
    private func heartRateZone(for bpm: Double, estimatedMaxHeartRate: Double) -> Int {
        let percentage = bpm / estimatedMaxHeartRate
        switch percentage {
        case ..<0.6: return 1
        case ..<0.7: return 2
        case ..<0.8: return 3
        case ..<0.9: return 4
        default: return 5
        }
    }
    private func heartRateBounds(for zone: Int, estimatedMaxHeartRate: Double) -> (Double?, Double?) {
        switch zone {
        case 1: return (nil, estimatedMaxHeartRate * 0.6)
        case 2: return (estimatedMaxHeartRate * 0.6, estimatedMaxHeartRate * 0.7)
        case 3: return (estimatedMaxHeartRate * 0.7, estimatedMaxHeartRate * 0.8)
        case 4: return (estimatedMaxHeartRate * 0.8, estimatedMaxHeartRate * 0.9)
        case 5: return (estimatedMaxHeartRate * 0.9, nil)
        default: return (nil, nil)
        }
    }
    private func makeSplitSummaries(from distanceSamples: [HealthWorkoutDistanceSample], heartRateSamples: [HealthWorkoutHeartRateSample], workoutStart: Date, workoutEnd: Date, distanceUnit: DistanceUnit) -> [HealthWorkoutSplitSummary] {
        guard !distanceSamples.isEmpty else { return [] }
        let targetSplitDistance = distanceUnit.toMeters(1)
        guard targetSplitDistance > 0 else { return [] }
        let heartRateIntervals = makeHeartRateIntervals(from: heartRateSamples, workoutStart: workoutStart, workoutEnd: workoutEnd)
        var splits: [HealthWorkoutSplitSummary] = []
        var currentDistance = 0.0
        var currentDuration = 0.0
        var currentStartDate: Date?
        var cumulativeDistance = 0.0
        var nextSplitID = 1
        for sample in distanceSamples {
            let sampleDuration = max(sample.endDate.timeIntervalSince(sample.startDate), 0)
            guard sample.distanceMeters > 0 else { continue }
            var consumedDistance = 0.0
            while consumedDistance < sample.distanceMeters {
                let remainingSampleDistance = sample.distanceMeters - consumedDistance
                let remainingSplitDistance = targetSplitDistance - currentDistance
                let distanceChunk = min(remainingSampleDistance, remainingSplitDistance)
                let startRatio = consumedDistance / sample.distanceMeters
                let endRatio = (consumedDistance + distanceChunk) / sample.distanceMeters
                let chunkStartDate = sample.startDate.addingTimeInterval(sampleDuration * startRatio)
                let chunkEndDate = sample.startDate.addingTimeInterval(sampleDuration * endRatio)
                currentStartDate = currentStartDate ?? chunkStartDate
                currentDistance += distanceChunk
                currentDuration += max(chunkEndDate.timeIntervalSince(chunkStartDate), 0)
                cumulativeDistance += distanceChunk
                consumedDistance += distanceChunk
                if currentDistance + 0.01 >= targetSplitDistance {
                    let splitStartDate = currentStartDate ?? chunkStartDate
                    splits.append(makeSplitSummary(id: nextSplitID, markerDistanceMeters: cumulativeDistance, segmentDistanceMeters: currentDistance, duration: currentDuration, startDate: splitStartDate, endDate: chunkEndDate, heartRateIntervals: heartRateIntervals))
                    nextSplitID += 1
                    currentDistance = 0
                    currentDuration = 0
                    currentStartDate = chunkEndDate
                }
            }
        }
        if currentDistance > 0 {
            let endDate = distanceSamples.last?.endDate ?? workoutEnd
            if let currentStartDate, endDate > currentStartDate {
                splits.append(makeSplitSummary(id: nextSplitID, markerDistanceMeters: cumulativeDistance, segmentDistanceMeters: currentDistance, duration: currentDuration, startDate: currentStartDate, endDate: endDate, heartRateIntervals: heartRateIntervals))
            }
        }
        return splits
    }
    private func makeSplitSummary(id: Int, markerDistanceMeters: Double, segmentDistanceMeters: Double, duration: TimeInterval, startDate: Date, endDate: Date, heartRateIntervals: [HealthWorkoutHeartRateInterval]) -> HealthWorkoutSplitSummary {
        let averageHeartRate = averageHeartRate(in: DateInterval(start: startDate, end: endDate), heartRateIntervals: heartRateIntervals)
        return HealthWorkoutSplitSummary(id: id, markerDistanceMeters: markerDistanceMeters, segmentDistanceMeters: segmentDistanceMeters, duration: duration, averageHeartRate: averageHeartRate)
    }
    private func averageHeartRate(in interval: DateInterval, heartRateIntervals: [HealthWorkoutHeartRateInterval]) -> Double? {
        var weightedHeartRate = 0.0
        var totalDuration = 0.0
        for heartRateInterval in heartRateIntervals {
            let overlapStart = max(interval.start, heartRateInterval.startDate)
            let overlapEnd = min(interval.end, heartRateInterval.endDate)
            let overlapDuration = overlapEnd.timeIntervalSince(overlapStart)
            guard overlapDuration > 0 else { continue }
            weightedHeartRate += heartRateInterval.bpm * overlapDuration
            totalDuration += overlapDuration
        }
        guard totalDuration > 0 else { return nil }
        return weightedHeartRate / totalDuration
    }
    private func makeHeartRateIntervals(from samples: [HealthWorkoutHeartRateSample], workoutStart: Date, workoutEnd: Date) -> [HealthWorkoutHeartRateInterval] {
        guard !samples.isEmpty, workoutEnd > workoutStart else { return [] }
        return samples.enumerated()
            .compactMap { index, sample in
                let startDate: Date
                if index == samples.startIndex {
                    startDate = workoutStart
                } else {
                    startDate = midpoint(between: samples[index - 1].representativeDate, and: sample.representativeDate)
                }
                let endDate: Date
                if index == samples.index(before: samples.endIndex) {
                    endDate = workoutEnd
                } else {
                    endDate = midpoint(between: sample.representativeDate, and: samples[index + 1].representativeDate)
                }
                let clampedStartDate = max(workoutStart, startDate)
                let clampedEndDate = min(workoutEnd, endDate)
                guard clampedEndDate > clampedStartDate else { return nil }
                return HealthWorkoutHeartRateInterval(startDate: clampedStartDate, endDate: clampedEndDate, bpm: sample.bpm)
            }
    }
    private func midpoint(between start: Date, and end: Date) -> Date { Date(timeIntervalSince1970: (start.timeIntervalSince1970 + end.timeIntervalSince1970) / 2) }
    private func makeEffortSummary(from samples: [HKSample]) -> HealthWorkoutEffortSummary? {
        let quantitySamples = samples.compactMap { $0 as? HKQuantitySample }
        if let workoutEffortType = HKQuantityType.quantityType(forIdentifier: .workoutEffortScore), let actualSample = quantitySamples.first(where: { $0.quantityType == workoutEffortType }) {
            let value = actualSample.quantity.doubleValue(for: .appleEffortScore())
            if value > 0 { return HealthWorkoutEffortSummary(source: .actualScore, value: value) }
        }
        if let estimatedEffortType = HKQuantityType.quantityType(forIdentifier: .estimatedWorkoutEffortScore), let estimatedSample = quantitySamples.first(where: { $0.quantityType == estimatedEffortType }) {
            let value = estimatedSample.quantity.doubleValue(for: .appleEffortScore())
            if value > 0 { return HealthWorkoutEffortSummary(source: .estimatedScore, value: value) }
        }
        return nil
    }
    private func fallbackEffortSummary(from workout: HKWorkout) -> HealthWorkoutEffortSummary? {
        if let workoutEffortType = HKQuantityType.quantityType(forIdentifier: .workoutEffortScore), let workoutEffort = workout.statistics(for: workoutEffortType)?.averageQuantity()?.doubleValue(for: .appleEffortScore()), workoutEffort > 0 {
            return HealthWorkoutEffortSummary(source: .actualScore, value: workoutEffort)
        }
        if let estimatedEffortType = HKQuantityType.quantityType(forIdentifier: .estimatedWorkoutEffortScore), let estimatedEffort = workout.statistics(for: estimatedEffortType)?.averageQuantity()?.doubleValue(for: .appleEffortScore()), estimatedEffort > 0 {
            return HealthWorkoutEffortSummary(source: .estimatedScore, value: estimatedEffort)
        }
        if let physicalEffortType = HKQuantityType.quantityType(forIdentifier: .physicalEffort), let physicalEffort = workout.statistics(for: physicalEffortType)?.averageQuantity()?.doubleValue(for: HKUnit(from: "kcal/(kg*hr)")), physicalEffort > 0 {
            return HealthWorkoutEffortSummary(source: .physicalEffort, value: physicalEffort)
        }
        return nil
    }
    private func markCachedWorkoutUnavailable() {
        guard cachedWorkout.isAvailableInHealthKit else { return }
        cachedWorkout.isAvailableInHealthKit = false
        if let context = cachedWorkout.modelContext { saveContext(context: context) }
    }
}
