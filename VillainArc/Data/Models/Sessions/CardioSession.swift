import Foundation
import HealthKit
import SwiftData

nonisolated enum CardioSessionKind: String, CaseIterable, Codable, Hashable, Identifiable {
    case outdoorRun
    case outdoorWalk
    case treadmillRun
    case treadmillWalk

    nonisolated var id: String { rawValue }

    var title: String {
        switch self {
        case .outdoorRun: return "Outdoor Run"
        case .outdoorWalk: return "Outdoor Walk"
        case .treadmillRun: return "Treadmill Run"
        case .treadmillWalk: return "Treadmill Walk"
        }
    }

    var shortTitle: String {
        switch self {
        case .outdoorRun, .treadmillRun: return "Run"
        case .outdoorWalk, .treadmillWalk: return "Walk"
        }
    }

    var systemImage: String {
        switch self {
        case .outdoorRun, .treadmillRun: return "figure.run"
        case .outdoorWalk, .treadmillWalk: return "figure.walk"
        }
    }

    var isOutdoor: Bool {
        switch self {
        case .outdoorRun, .outdoorWalk: return true
        case .treadmillRun, .treadmillWalk: return false
        }
    }

    var isManual: Bool { !isOutdoor }

    var healthActivityType: HKWorkoutActivityType {
        switch self {
        case .outdoorRun, .treadmillRun: return .running
        case .outdoorWalk, .treadmillWalk: return .walking
        }
    }

    var healthLocationType: HKWorkoutSessionLocationType {
        isOutdoor ? .outdoor : .indoor
    }
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
    var kindRawValue: String = CardioSessionKind.outdoorRun.rawValue
    var status: String = CardioSessionStatus.active.rawValue
    var sourceRawValue: String = CardioSessionSource.location.rawValue
    var startedAt: Date?
    var endedAt: Date?
    var totalDistanceMeters: Double = 0
    var healthWorkoutUUID: UUID?
    var healthWorkout: HealthWorkout?
    @Relationship(deleteRule: .cascade, inverse: \CardioRoutePoint.session) var routePoints: [CardioRoutePoint]? = [CardioRoutePoint]()
    @Relationship(deleteRule: .cascade, inverse: \CardioTreadmillInterval.session) var treadmillIntervals: [CardioTreadmillInterval]? = [CardioTreadmillInterval]()

    init(kind: CardioSessionKind = .outdoorRun) {
        self.kindRawValue = kind.rawValue
        self.sourceRawValue = kind.isOutdoor ? CardioSessionSource.location.rawValue : CardioSessionSource.manual.rawValue
        self.title = kind.title
    }

    var kind: CardioSessionKind {
        get { CardioSessionKind(rawValue: kindRawValue) ?? .outdoorRun }
        set {
            kindRawValue = newValue.rawValue
            if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || CardioSessionKind.allCases.map(\.title).contains(title) {
                title = newValue.title
            }
        }
    }

    var statusValue: CardioSessionStatus {
        get { CardioSessionStatus(rawValue: status) ?? .active }
        set { status = newValue.rawValue }
    }

    var source: CardioSessionSource {
        get { CardioSessionSource(rawValue: sourceRawValue) ?? (kind.isOutdoor ? .location : .manual) }
        set { sourceRawValue = newValue.rawValue }
    }

    var displayTitle: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? kind.title : trimmedTitle
    }

    var sortedRoutePoints: [CardioRoutePoint] {
        (routePoints ?? []).sorted {
            if $0.timestamp == $1.timestamp { return $0.index < $1.index }
            return $0.timestamp < $1.timestamp
        }
    }

    var sortedTreadmillIntervals: [CardioTreadmillInterval] {
        (treadmillIntervals ?? []).sorted { $0.index < $1.index }
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

    func finish(at endDate: Date = .now) {
        endedAt = max(startedAt ?? endDate, endDate)
        statusValue = .done
        if kind.isManual {
            recalculateTreadmillDistance()
        } else {
            recalculateRouteDistance()
        }
    }

    func recalculateTreadmillDistance() {
        let intervals = sortedTreadmillIntervals
        let sessionEnd = endedAt ?? .now
        for (i, interval) in intervals.enumerated() {
            let nextStart = i + 1 < intervals.count ? intervals[i + 1].addedAt : sessionEnd
            let durationSeconds = max(0, nextStart.timeIntervalSince(interval.addedAt))
            interval.distanceMeters = (interval.speedKPH / 3.6) * durationSeconds
        }
        totalDistanceMeters = intervals.reduce(0) { $0 + $1.distanceMeters }
    }

    func intervalDuration(for interval: CardioTreadmillInterval) -> TimeInterval {
        let intervals = sortedTreadmillIntervals
        guard let idx = intervals.firstIndex(where: { $0.id == interval.id }) else { return 0 }
        let sessionEnd = endedAt ?? .now
        let nextStart = idx + 1 < intervals.count ? intervals[idx + 1].addedAt : sessionEnd
        return max(0, nextStart.timeIntervalSince(interval.addedAt))
    }

    func recalculateRouteDistance() {
        let points = sortedRoutePoints
        guard points.count > 1 else { return }

        totalDistanceMeters = zip(points, points.dropFirst()).reduce(0) { total, pair in
            total + Self.distanceMeters(
                fromLatitude: pair.0.latitude,
                longitude: pair.0.longitude,
                toLatitude: pair.1.latitude,
                longitude: pair.1.longitude
            )
        }
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
    var timestamp: Date = Date()
    var horizontalAccuracy: Double = 0
    var speedMetersPerSecond: Double?
    var session: CardioSession?

    init(index: Int, latitude: Double, longitude: Double, timestamp: Date, horizontalAccuracy: Double = 0, speedMetersPerSecond: Double? = nil, session: CardioSession? = nil) {
        self.index = index
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
        self.horizontalAccuracy = horizontalAccuracy
        self.speedMetersPerSecond = speedMetersPerSecond
        self.session = session
    }
}

@Model final class CardioTreadmillInterval {
    #Index<CardioTreadmillInterval>([\.index])

    var id: UUID = UUID()
    var index: Int = 0
    var speedKPH: Double = 0
    var inclinePercent: Double = 0
    var addedAt: Date = Date()
    var distanceMeters: Double = 0
    var session: CardioSession?

    init(index: Int, speedKPH: Double, inclinePercent: Double = 0, addedAt: Date = .now, session: CardioSession? = nil) {
        self.index = index
        self.speedKPH = max(0, speedKPH)
        self.inclinePercent = max(0, inclinePercent)
        self.addedAt = addedAt
        self.session = session
    }
}
