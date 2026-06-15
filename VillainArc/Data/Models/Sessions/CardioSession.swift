import Foundation
import HealthKit
import SwiftData

// MARK: - Taxonomy
//
// Cardio is modeled on two axes (activity × environment) plus a stored capture
// mode (how the session's detail is recorded), instead of a flat named-type enum.
// This represents any cardio session; types VillainArc can't natively record fall
// back to `.healthKitOnly`.

nonisolated enum CardioActivity: String, CaseIterable, Codable, Hashable, Identifiable {
    case run
    case walk
    case hike
    case cycle
    case row
    case elliptical
    case stairStepper
    case swim
    case other

    nonisolated var id: String { rawValue }

    var title: String {
        switch self {
        case .run: return "Run"
        case .walk: return "Walk"
        case .hike: return "Hike"
        case .cycle: return "Cycle"
        case .row: return "Row"
        case .elliptical: return "Elliptical"
        case .stairStepper: return "Stair Stepper"
        case .swim: return "Swim"
        case .other: return "Cardio"
        }
    }

    var shortTitle: String {
        switch self {
        case .run: return "Run"
        case .walk: return "Walk"
        case .hike: return "Hike"
        case .cycle: return "Cycle"
        case .row: return "Row"
        case .elliptical: return "Elliptical"
        case .stairStepper: return "Stairs"
        case .swim: return "Swim"
        case .other: return "Cardio"
        }
    }

    var systemImage: String {
        switch self {
        case .run: return "figure.run"
        case .walk: return "figure.walk"
        case .hike: return "figure.hiking"
        case .cycle: return "figure.outdoor.cycle"
        case .row: return "figure.rower"
        case .elliptical: return "figure.elliptical"
        case .stairStepper: return "figure.stair.stepper"
        case .swim: return "figure.pool.swim"
        case .other: return "figure.mixed.cardio"
        }
    }

    var healthActivityType: HKWorkoutActivityType {
        switch self {
        case .run: return .running
        case .walk: return .walking
        case .hike: return .hiking
        case .cycle: return .cycling
        case .row: return .rowing
        case .elliptical: return .elliptical
        case .stairStepper: return .stairClimbing
        case .swim: return .swimming
        case .other: return .mixedCardio
        }
    }

    var supportsOutdoor: Bool {
        switch self {
        case .run, .walk, .hike, .cycle, .swim: return true
        case .row, .elliptical, .stairStepper, .other: return false
        }
    }

    var supportsIndoor: Bool {
        self != .hike
    }

    // The natural way to capture this activity's detail in a given environment.
    func defaultCaptureMode(in environment: CardioEnvironment) -> CardioCaptureMode {
        switch environment {
        case .outdoor:
            switch self {
            case .run, .walk, .hike, .cycle: return .gpsRoute
            default: return .healthKitOnly
            }
        case .indoor:
            switch self {
            case .run, .walk, .cycle, .stairStepper: return .machineIntervals
            default: return .healthKitOnly
            }
        }
    }

    // Display label that folds in the environment, e.g. "Treadmill Walk", "Outdoor Run".
    func title(in environment: CardioEnvironment) -> String {
        switch (self, environment) {
        case (.run, .outdoor): return "Outdoor Run"
        case (.run, .indoor): return "Treadmill Run"
        case (.walk, .outdoor): return "Outdoor Walk"
        case (.walk, .indoor): return "Treadmill Walk"
        case (.cycle, .outdoor): return "Outdoor Cycle"
        case (.cycle, .indoor): return "Indoor Cycle"
        case (.swim, .outdoor): return "Open Water Swim"
        case (.swim, .indoor): return "Pool Swim"
        case (.hike, _): return "Hike"
        default: return title
        }
    }
}

nonisolated enum CardioEnvironment: String, CaseIterable, Codable, Hashable {
    case outdoor
    case indoor

    var title: String { self == .outdoor ? "Outdoor" : "Indoor" }
    var healthLocationType: HKWorkoutSessionLocationType { self == .outdoor ? .outdoor : .indoor }
}

// How a session's per-sample detail is recorded. Only the matching relationship on
// CardioSession is populated; `.healthKitOnly` records none (metrics come from the
// linked HealthKit workout).
nonisolated enum CardioCaptureMode: String, Codable, Hashable {
    case gpsRoute
    case machineIntervals
    case healthKitOnly
}

// A pickable cardio preset (activity + environment) for the start UI, the start
// API, the stored favorite, and Shortcuts — a thin presentation layer over the
// axes model. Encodes as "activity|environment" for AppSettings storage.
nonisolated struct CardioSessionType: Codable, Hashable, Identifiable, Sendable {
    var activity: CardioActivity
    var environment: CardioEnvironment

    init(activity: CardioActivity, environment: CardioEnvironment) {
        self.activity = activity
        self.environment = environment
    }

    nonisolated var id: String { "\(activity.rawValue)|\(environment.rawValue)" }
    var title: String { activity.title(in: environment) }
    var systemImage: String { activity.systemImage }
    var isOutdoor: Bool { environment == .outdoor }

    var rawValue: String { id }
    init?(rawValue: String) {
        let parts = rawValue.split(separator: "|")
        guard parts.count == 2,
              let activity = CardioActivity(rawValue: String(parts[0])),
              let environment = CardioEnvironment(rawValue: String(parts[1])) else { return nil }
        self.init(activity: activity, environment: environment)
    }

    // Parity with the four legacy kinds the start UI offers today.
    static let presets: [CardioSessionType] = [
        CardioSessionType(activity: .run, environment: .outdoor),
        CardioSessionType(activity: .walk, environment: .outdoor),
        CardioSessionType(activity: .run, environment: .indoor),
        CardioSessionType(activity: .walk, environment: .indoor)
    ]
}

nonisolated enum CardioSessionStatus: String, Codable, Hashable {
    case active
    case done
}

nonisolated enum CardioSessionSource: String, Codable, Hashable {
    case location
    case manual
    case appleHealth
}

@Model final class CardioSession {
    #Index<CardioSession>([\.id], [\.status])

    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var postEffort: Int = 0
    var activityRawValue: String = CardioActivity.run.rawValue
    var environmentRawValue: String = CardioEnvironment.outdoor.rawValue
    var captureModeRawValue: String = CardioCaptureMode.gpsRoute.rawValue
    var status: String = CardioSessionStatus.active.rawValue
    var sourceRawValue: String = CardioSessionSource.location.rawValue
    var startedAt: Date?
    var endedAt: Date?
    var totalDistanceMeters: Double = 0
    var averageHeartRateBPM: Double?
    var activeEnergyKilocalories: Double?
    var elevationGainMeters: Double?
    var healthWorkoutUUID: UUID?
    var healthWorkout: HealthWorkout?
    @Relationship(deleteRule: .cascade, inverse: \CardioRoutePoint.session) var routePoints: [CardioRoutePoint]? = [CardioRoutePoint]()
    @Relationship(deleteRule: .cascade, inverse: \CardioMachineInterval.session) var machineIntervals: [CardioMachineInterval]? = [CardioMachineInterval]()

    init(activity: CardioActivity = .run, environment: CardioEnvironment = .outdoor, captureMode: CardioCaptureMode? = nil) {
        let mode = captureMode ?? activity.defaultCaptureMode(in: environment)
        self.activityRawValue = activity.rawValue
        self.environmentRawValue = environment.rawValue
        self.captureModeRawValue = mode.rawValue
        self.sourceRawValue = Self.defaultSource(for: mode).rawValue
        self.title = activity.title(in: environment)
    }

    convenience init(type: CardioSessionType, captureMode: CardioCaptureMode? = nil) {
        self.init(activity: type.activity, environment: type.environment, captureMode: captureMode)
    }

    // All auto-generated type titles, so a user-typed custom title can be told apart.
    private static let autoTitles: Set<String> = {
        var titles = Set<String>()
        for activity in CardioActivity.allCases {
            for environment in CardioEnvironment.allCases {
                titles.insert(activity.title(in: environment))
            }
        }
        return titles
    }()

    private static func defaultSource(for mode: CardioCaptureMode) -> CardioSessionSource {
        switch mode {
        case .gpsRoute: return .location
        case .machineIntervals: return .manual
        case .healthKitOnly: return .appleHealth
        }
    }

    var activity: CardioActivity {
        get { CardioActivity(rawValue: activityRawValue) ?? .run }
        set { activityRawValue = newValue.rawValue }
    }

    var environment: CardioEnvironment {
        get { CardioEnvironment(rawValue: environmentRawValue) ?? .outdoor }
        set { environmentRawValue = newValue.rawValue }
    }

    var captureMode: CardioCaptureMode {
        get { CardioCaptureMode(rawValue: captureModeRawValue) ?? .healthKitOnly }
        set { captureModeRawValue = newValue.rawValue }
    }

    var statusValue: CardioSessionStatus {
        get { CardioSessionStatus(rawValue: status) ?? .active }
        set { status = newValue.rawValue }
    }

    var source: CardioSessionSource {
        get { CardioSessionSource(rawValue: sourceRawValue) ?? Self.defaultSource(for: captureMode) }
        set { sourceRawValue = newValue.rawValue }
    }

    // Sets the activity/environment (and the matching default capture mode), and
    // refreshes the title unless the user has typed a custom one.
    func updateType(activity: CardioActivity, environment: CardioEnvironment, captureMode: CardioCaptureMode? = nil) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let titleIsAuto = trimmed.isEmpty || Self.autoTitles.contains(trimmed)
        self.activity = activity
        self.environment = environment
        self.captureMode = captureMode ?? activity.defaultCaptureMode(in: environment)
        if titleIsAuto {
            self.title = activity.title(in: environment)
        }
    }

    // MARK: Convenience

    var isOutdoor: Bool { environment == .outdoor }
    // "Manual" in the legacy sense = the user logs machine intervals by hand.
    var isManual: Bool { captureMode == .machineIntervals }
    var usesRoute: Bool { captureMode == .gpsRoute }
    var usesMachineIntervals: Bool { captureMode == .machineIntervals }
    var isHealthKitOnly: Bool { captureMode == .healthKitOnly }

    var systemImage: String { activity.systemImage }
    var healthActivityType: HKWorkoutActivityType { activity.healthActivityType }
    var healthLocationType: HKWorkoutSessionLocationType { environment.healthLocationType }

    // Environment-qualified type label, e.g. "Treadmill Walk".
    var typeTitle: String { activity.title(in: environment) }

    var displayTitle: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? typeTitle : trimmedTitle
    }

    var sortedRoutePoints: [CardioRoutePoint] {
        (routePoints ?? []).sorted {
            if $0.timestamp == $1.timestamp { return $0.index < $1.index }
            return $0.timestamp < $1.timestamp
        }
    }

    var sortedMachineIntervals: [CardioMachineInterval] {
        (machineIntervals ?? []).sorted { $0.index < $1.index }
    }

    var duration: TimeInterval {
        guard let startedAt else { return 0 }
        let end = endedAt ?? .now
        return max(0, end.timeIntervalSince(startedAt))
    }

    var averagePaceSecondsPerMeter: Double? {
        guard totalDistanceMeters > 0, duration > 0 else { return nil }
        return duration / totalDistanceMeters
    }

    /// Interval distance computed to the present moment — the active (latest) interval keeps
    /// accruing until the next interval starts or the session ends. This is the read-only twin of
    /// `recalculateMachineDistance()` so the live metric grid and Live Activity can show the same
    /// growing distance without mutating/saving every tick.
    var liveMachineDistanceMeters: Double {
        let intervals = sortedMachineIntervals
        guard !intervals.isEmpty else { return 0 }
        let end = endedAt ?? .now
        var total = 0.0
        for (i, interval) in intervals.enumerated() {
            let nextStart = i + 1 < intervals.count ? intervals[i + 1].addedAt : end
            total += ((interval.speedKPH ?? 0) / 3.6) * max(0, nextStart.timeIntervalSince(interval.addedAt))
        }
        return total
    }

    /// The session's distance in meters, resolved to a SINGLE source per capture mode so the
    /// in-app metric grid, the Live Activity, and the finished detail never disagree (this is the
    /// pace-bug fix — no more `max()` across the interval distance and the Watch's HealthKit
    /// estimate). gpsRoute → the GPS route distance (kept current by `CardioRouteRecorder`);
    /// machineIntervals → the live interval distance; healthKitOnly → the live HealthKit distance
    /// when available, otherwise the stored total.
    func resolvedDistanceMeters(healthKitDistance: Double?) -> Double {
        switch captureMode {
        case .gpsRoute: return totalDistanceMeters
        case .machineIntervals: return liveMachineDistanceMeters
        case .healthKitOnly: return healthKitDistance ?? totalDistanceMeters
        }
    }

    func finish(at endDate: Date = .now) {
        endedAt = max(startedAt ?? endDate, endDate)
        statusValue = .done
        switch captureMode {
        case .machineIntervals:
            recalculateMachineDistance()
        case .gpsRoute:
            recalculateRouteDistance()
        case .healthKitOnly:
            break
        }
    }

    func recalculateMachineDistance() {
        let intervals = sortedMachineIntervals
        let sessionEnd = endedAt ?? .now
        for (i, interval) in intervals.enumerated() {
            let nextStart = i + 1 < intervals.count ? intervals[i + 1].addedAt : sessionEnd
            let durationSeconds = max(0, nextStart.timeIntervalSince(interval.addedAt))
            interval.distanceMeters = ((interval.speedKPH ?? 0) / 3.6) * durationSeconds
        }
        totalDistanceMeters = intervals.reduce(0) { $0 + $1.distanceMeters }
    }

    func intervalDuration(for interval: CardioMachineInterval) -> TimeInterval {
        let intervals = sortedMachineIntervals
        guard let idx = intervals.firstIndex(where: { $0.id == interval.id }) else { return 0 }
        let sessionEnd = endedAt ?? .now
        let nextStart = idx + 1 < intervals.count ? intervals[idx + 1].addedAt : sessionEnd
        return max(0, nextStart.timeIntervalSince(interval.addedAt))
    }

    func recalculateRouteDistance() {
        let points = sortedRoutePoints
        guard points.count > 1 else { return }

        var distance = 0.0
        var gain = 0.0
        for (start, end) in zip(points, points.dropFirst()) {
            distance += Self.distanceMeters(
                fromLatitude: start.latitude,
                longitude: start.longitude,
                toLatitude: end.latitude,
                longitude: end.longitude
            )
            if let startAltitude = start.altitude, let endAltitude = end.altitude, endAltitude > startAltitude {
                gain += endAltitude - startAltitude
            }
        }
        totalDistanceMeters = distance
        if gain > 0 { elevationGainMeters = gain }
    }

    static func distanceMeters(fromLatitude startLatitude: Double, longitude startLongitude: Double, toLatitude endLatitude: Double, longitude endLongitude: Double) -> Double {
        let earthRadiusMeters = 6_371_000.0
        let startLat = startLatitude * .pi / 180
        let endLat = endLatitude * .pi / 180
        let deltaLat = (endLatitude - startLatitude) * .pi / 180
        let deltaLon = (endLongitude - startLongitude) * .pi / 180
        let a = sin(deltaLat / 2) * sin(deltaLat / 2) + cos(startLat) * cos(endLat) * sin(deltaLon / 2) * sin(deltaLon / 2)
        return earthRadiusMeters * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}

extension CardioSession {
    static func byID(_ id: UUID) -> FetchDescriptor<CardioSession> {
        let predicate = #Predicate<CardioSession> { $0.id == id }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        return descriptor
    }

    static var incomplete: FetchDescriptor<CardioSession> {
        let done = CardioSessionStatus.done.rawValue
        var descriptor = FetchDescriptor<CardioSession>(predicate: #Predicate { $0.status != done })
        descriptor.fetchLimit = 1
        return descriptor
    }

    static var history: FetchDescriptor<CardioSession> {
        let done = CardioSessionStatus.done.rawValue
        return FetchDescriptor(predicate: #Predicate { $0.status == done }, sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
    }

    static func recentCompleted(limit: Int) -> FetchDescriptor<CardioSession> {
        var descriptor = history
        descriptor.fetchLimit = limit
        return descriptor
    }
}

@Model final class CardioRoutePoint {
    #Index<CardioRoutePoint>([\.timestamp], [\.index])

    var id: UUID = UUID()
    var index: Int = 0
    var latitude: Double = 0
    var longitude: Double = 0
    var altitude: Double?
    var timestamp: Date = Date()
    var horizontalAccuracy: Double = 0
    var verticalAccuracy: Double?
    var course: Double?
    var speedMetersPerSecond: Double?
    var session: CardioSession?

    init(index: Int, latitude: Double, longitude: Double, altitude: Double? = nil, timestamp: Date, horizontalAccuracy: Double = 0, verticalAccuracy: Double? = nil, course: Double? = nil, speedMetersPerSecond: Double? = nil, session: CardioSession? = nil) {
        self.index = index
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.timestamp = timestamp
        self.horizontalAccuracy = horizontalAccuracy
        self.verticalAccuracy = verticalAccuracy
        self.course = course
        self.speedMetersPerSecond = speedMetersPerSecond
        self.session = session
    }
}

// A user-logged segment for an indoor machine session (treadmill, indoor bike,
// stair stepper…). Fields are optional so each machine fills only what applies:
// treadmill → speed/incline, bike → resistance/cadence/power, stair → resistance.
@Model final class CardioMachineInterval {
    #Index<CardioMachineInterval>([\.index])

    var id: UUID = UUID()
    var index: Int = 0
    var speedKPH: Double?
    var inclinePercent: Double?
    var resistanceLevel: Double?
    var cadenceRPM: Double?
    var powerWatts: Double?
    var addedAt: Date = Date()
    var distanceMeters: Double = 0
    var session: CardioSession?

    init(index: Int, speedKPH: Double? = nil, inclinePercent: Double? = nil, resistanceLevel: Double? = nil, cadenceRPM: Double? = nil, powerWatts: Double? = nil, addedAt: Date = .now, session: CardioSession? = nil) {
        self.index = index
        self.speedKPH = speedKPH.map { max(0, $0) }
        self.inclinePercent = inclinePercent.map { max(0, $0) }
        self.resistanceLevel = resistanceLevel.map { max(0, $0) }
        self.cadenceRPM = cadenceRPM.map { max(0, $0) }
        self.powerWatts = powerWatts.map { max(0, $0) }
        self.addedAt = addedAt
        self.session = session
    }
}
