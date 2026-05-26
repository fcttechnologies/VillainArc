import CoreLocation
import Observation
import SwiftData

@MainActor
@Observable final class CardioRouteRecorder: NSObject {
    static let shared = CardioRouteRecorder()

    private(set) var authorizationStatus: CLAuthorizationStatus = CLLocationManager().authorizationStatus
    private(set) var isRecording = false
    private(set) var lastErrorMessage: String?

    @ObservationIgnored private let locationManager = CLLocationManager()
    @ObservationIgnored private weak var context: ModelContext?
    @ObservationIgnored private var activeSessionID: UUID?

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.activityType = .fitness
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 8
        authorizationStatus = locationManager.authorizationStatus
    }

    var canRecord: Bool {
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        default:
            return false
        }
    }

    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    func startRecording(session: CardioSession, context: ModelContext) {
        guard session.kind.isOutdoor, session.statusValue == .active else { return }
        self.context = context
        activeSessionID = session.id
        lastErrorMessage = nil

        if authorizationStatus == .notDetermined {
            requestAuthorization()
        }

        guard canRecord else {
            isRecording = false
            return
        }

        locationManager.startUpdatingLocation()
        isRecording = true
    }

    func stopRecording(sessionID: UUID? = nil) {
        if let sessionID, activeSessionID != sessionID { return }
        locationManager.stopUpdatingLocation()
        isRecording = false
        activeSessionID = nil
        context = nil
    }

    private func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
        authorizationStatus = status
        guard let context, let activeSessionID else { return }
        guard let session = try? context.fetch(CardioSession.byID(activeSessionID)).first else { return }

        if canRecord {
            startRecording(session: session, context: context)
        } else {
            isRecording = false
        }
    }

    private func handleLocations(_ locations: [CLLocation]) {
        guard let context, let activeSessionID else { return }
        guard let session = try? context.fetch(CardioSession.byID(activeSessionID)).first else { return }
        guard session.statusValue == .active else {
            stopRecording(sessionID: activeSessionID)
            return
        }

        let usableLocations = locations.filter { location in
            location.horizontalAccuracy >= 0 && location.horizontalAccuracy <= 60
        }
        guard !usableLocations.isEmpty else { return }

        var nextIndex = (session.routePoints ?? []).map(\.index).max().map { $0 + 1 } ?? 0
        var latestPoint = session.sortedRoutePoints.last

        for location in usableLocations {
            if let latestPoint {
                let delta = CardioSession.distanceMeters(
                    fromLatitude: latestPoint.latitude,
                    longitude: latestPoint.longitude,
                    toLatitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
                guard delta >= 3 else { continue }
                session.totalDistanceMeters += delta
            }

            let point = CardioRoutePoint(
                index: nextIndex,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                timestamp: location.timestamp,
                horizontalAccuracy: location.horizontalAccuracy,
                speedMetersPerSecond: location.speed >= 0 ? location.speed : nil,
                session: session
            )
            context.insert(point)
            session.routePoints?.append(point)
            latestPoint = point
            nextIndex += 1
        }

        saveContext(context: context)
        CardioActivityManager.update(for: session)
    }
}

extension CardioRouteRecorder: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.handleAuthorizationChange(status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            self.handleLocations(locations)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        Task { @MainActor in
            self.lastErrorMessage = error.localizedDescription
            self.isRecording = false
        }
    }
}
