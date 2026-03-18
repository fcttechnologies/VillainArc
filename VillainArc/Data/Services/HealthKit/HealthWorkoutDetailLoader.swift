import Foundation
import HealthKit
import Observation

struct HealthWorkoutDetailSummary: Equatable {
    let activityType: HKWorkoutActivityType
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let activeEnergyBurned: Double?
    let restingEnergyBurned: Double?
    let totalDistance: Double?
    let sourceName: String

    init(workout: HKWorkout) {
        let activeEnergyType = HKQuantityType(.activeEnergyBurned)
        let basalEnergyType = HKQuantityType(.basalEnergyBurned)
        activityType = workout.workoutActivityType
        startDate = workout.startDate
        endDate = workout.endDate
        duration = workout.duration
        activeEnergyBurned = workout
            .statistics(for: activeEnergyType)?
            .sumQuantity()?
            .doubleValue(for: .kilocalorie())
        restingEnergyBurned = workout
            .statistics(for: basalEnergyType)?
            .sumQuantity()?
            .doubleValue(for: .kilocalorie())
        totalDistance = workout.totalDistance?.doubleValue(for: .meter())
        sourceName = workout.sourceRevision.source.name
    }

    init(workout: HealthWorkout) {
        activityType = workout.activityType
        startDate = workout.startDate
        endDate = workout.endDate
        duration = workout.duration
        activeEnergyBurned = workout.totalEnergyBurned
        restingEnergyBurned = nil
        totalDistance = workout.totalDistance
        sourceName = workout.sourceName
    }

    var activityTypeDisplayName: String {
        activityType.displayName
    }

    var totalCalories: Double? {
        guard let activeEnergyBurned, let restingEnergyBurned else { return nil }
        return activeEnergyBurned + restingEnergyBurned
    }
}

struct HealthWorkoutHeartRatePoint: Identifiable, Hashable {
    let date: Date
    let bpm: Double

    var id: Date { date }
}

struct HealthWorkoutEnergyPoint: Identifiable, Hashable {
    let date: Date
    let cumulativeCalories: Double

    var id: Date { date }
}

struct HealthWorkoutHeartRateSummary: Equatable {
    let averageBPM: Double?
    let minimumBPM: Double?
    let maximumBPM: Double?

    var hasContent: Bool {
        averageBPM != nil || minimumBPM != nil || maximumBPM != nil
    }
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

@MainActor
@Observable
final class HealthWorkoutDetailLoader {
    private static let chartMaxPoints = 180

    private let cachedWorkout: HealthWorkout
    private let healthStore = HealthAuthorizationManager.shared.healthStore

    var summary: HealthWorkoutDetailSummary
    var heartRateSummary = HealthWorkoutHeartRateSummary(averageBPM: nil, minimumBPM: nil, maximumBPM: nil)
    var heartRatePoints: [HealthWorkoutHeartRatePoint] = []
    var energyPoints: [HealthWorkoutEnergyPoint] = []
    var metrics: [HealthWorkoutDetailMetric] = []
    var activities: [HealthWorkoutActivitySummary] = []
    var isLoading = false
    var hasLoaded = false
    var isUsingCachedSummaryOnly: Bool
    var loadErrorMessage: String?

    init(workout: HealthWorkout) {
        cachedWorkout = workout
        summary = HealthWorkoutDetailSummary(workout: workout)
        isUsingCachedSummaryOnly = !workout.isAvailableInHealthKit
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load()
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        loadErrorMessage = nil

        defer {
            isLoading = false
            hasLoaded = true
        }

        guard cachedWorkout.isAvailableInHealthKit else {
            isUsingCachedSummaryOnly = true
            return
        }

        do {
            guard let workout = try await fetchWorkout() else {
                isUsingCachedSummaryOnly = true
                loadErrorMessage = "This workout is no longer available in Apple Health."
                return
            }

            summary = HealthWorkoutDetailSummary(workout: workout)
            isUsingCachedSummaryOnly = false

            async let heartRateLoad = loadHeartRate(for: workout)
            async let energyLoad = loadActiveEnergy(for: workout)

            let (loadedHeartRateSummary, loadedHeartRatePoints) = try await heartRateLoad
            let loadedEnergyPoints = try await energyLoad

            heartRateSummary = loadedHeartRateSummary
            heartRatePoints = loadedHeartRatePoints
            metrics = loadMetrics(for: workout)
            activities = makeActivitySummaries(from: workout.workoutActivities)
            energyPoints = loadedEnergyPoints
        } catch {
            isUsingCachedSummaryOnly = true
            loadErrorMessage = "Unable to load live Apple Health details right now."
            print("Failed to load Health workout details for \(cachedWorkout.healthWorkoutUUID): \(error)")
        }
    }

    private func fetchWorkout() async throws -> HKWorkout? {
        let predicate = NSPredicate(format: "%K == %@", HKPredicateKeyPathUUID, cachedWorkout.healthWorkoutUUID as NSUUID)
        let descriptor = HKSampleQueryDescriptor(predicates: [.workout(predicate)], sortDescriptors: [], limit: 1)
        return try await descriptor.result(for: healthStore).first
    }

    private func loadHeartRate(for workout: HKWorkout) async throws -> (HealthWorkoutHeartRateSummary, [HealthWorkoutHeartRatePoint]) {
        let heartRateType = HKQuantityType(.heartRate)
        let workoutPredicate = HKQuery.predicateForObjects(from: workout)
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())

        let statistics = workout.statistics(for: heartRateType)
        let summary = HealthWorkoutHeartRateSummary(
            averageBPM: statistics?.averageQuantity()?.doubleValue(for: bpmUnit),
            minimumBPM: statistics?.minimumQuantity()?.doubleValue(for: bpmUnit),
            maximumBPM: statistics?.maximumQuantity()?.doubleValue(for: bpmUnit)
        )

        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: heartRateType, predicate: workoutPredicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)],
            limit: HKObjectQueryNoLimit
        )

        let samples = try await descriptor.result(for: healthStore)
        let points = samples
            .map { sample in
                HealthWorkoutHeartRatePoint(
                    date: sample.endDate,
                    bpm: sample.quantity.doubleValue(for: bpmUnit)
                )
            }
            .filter { $0.bpm > 0 }

        return (summary, downsampledHeartRatePoints(from: points, maxPoints: Self.chartMaxPoints))
    }

    private func loadActiveEnergy(for workout: HKWorkout) async throws -> [HealthWorkoutEnergyPoint] {
        let activeEnergyType = HKQuantityType(.activeEnergyBurned)
        let workoutPredicate = HKQuery.predicateForObjects(from: workout)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: activeEnergyType, predicate: workoutPredicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)],
            limit: HKObjectQueryNoLimit
        )

        let samples = try await descriptor.result(for: healthStore)
        var cumulativeCalories = 0.0

        let points = samples.compactMap { sample -> HealthWorkoutEnergyPoint? in
            let calories = sample.quantity.doubleValue(for: .kilocalorie())
            guard calories > 0 else { return nil }
            cumulativeCalories += calories
            return HealthWorkoutEnergyPoint(date: sample.endDate, cumulativeCalories: cumulativeCalories)
        }

        return downsampledEnergyPoints(from: points, maxPoints: Self.chartMaxPoints)
    }

    private func loadMetrics(for workout: HKWorkout) -> [HealthWorkoutDetailMetric] {
        var items: [HealthWorkoutDetailMetric] = []
        let flightsClimbedType = HKQuantityType(.flightsClimbed)
        let swimmingStrokeCountType = HKQuantityType(.swimmingStrokeCount)

        if let flights = workout.statistics(for: flightsClimbedType)?
            .sumQuantity()?
            .doubleValue(for: .count()),
           flights > 0 {
            items.append(.init(title: "Flights Climbed", value: flights, valueStyle: .integer))
        }

        if let strokes = workout.statistics(for: swimmingStrokeCountType)?
            .sumQuantity()?
            .doubleValue(for: .count()),
           strokes > 0 {
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
        guard let value = workout.statistics(for: quantityType)?
            .averageQuantity()?
            .doubleValue(for: unit),
              value > 0 else {
            return
        }

        items.append(.init(title: title, value: value, valueStyle: style))
    }

    private func makeActivitySummaries(from workoutActivities: [HKWorkoutActivity]) -> [HealthWorkoutActivitySummary] {
        let activeEnergyType = HKQuantityType(.activeEnergyBurned)

        return workoutActivities.map { activity in
            let energyBurned = activity
                .statistics(for: activeEnergyType)?
                .sumQuantity()?
                .doubleValue(for: .kilocalorie())

            return HealthWorkoutActivitySummary(id: activity.uuid, title: activity.workoutConfiguration.activityType.displayName, duration: activity.duration, energyBurned: energyBurned)
        }
    }

    private func downsampledHeartRatePoints(from points: [HealthWorkoutHeartRatePoint], maxPoints: Int) -> [HealthWorkoutHeartRatePoint] {
        guard points.count > maxPoints, maxPoints > 1 else { return points }

        let stride = Double(points.count - 1) / Double(maxPoints - 1)
        return (0..<maxPoints).compactMap { index in
            let pointIndex = Int((Double(index) * stride).rounded())
            guard points.indices.contains(pointIndex) else { return nil }
            return points[pointIndex]
        }
    }

    private func downsampledEnergyPoints(from points: [HealthWorkoutEnergyPoint], maxPoints: Int) -> [HealthWorkoutEnergyPoint] {
        guard points.count > maxPoints, maxPoints > 1 else { return points }

        let stride = Double(points.count - 1) / Double(maxPoints - 1)
        return (0..<maxPoints).compactMap { index in
            let pointIndex = Int((Double(index) * stride).rounded())
            guard points.indices.contains(pointIndex) else { return nil }
            return points[pointIndex]
        }
    }
}
