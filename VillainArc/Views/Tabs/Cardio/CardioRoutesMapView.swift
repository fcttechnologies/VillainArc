import CoreLocation
import Foundation
import HealthKit
import MapKit
import Observation
import SwiftUI

/// A single route drawn on the cardio tab map. It can come from an app-owned `CardioSession` or
/// from a standalone outdoor Apple Health workout; tapping it opens the matching detail view.
struct CardioMapRoute: Identifiable {
    enum Target {
        case appSession(CardioSession)
        case healthWorkout(HealthWorkout)
    }

    let id: String
    let coordinates: [CLLocationCoordinate2D]
    let isActive: Bool
    let title: String
    let distanceMeters: Double
    let duration: TimeInterval
    let date: Date
    let target: Target

    var midCoordinate: CLLocationCoordinate2D? {
        guard !coordinates.isEmpty else { return nil }
        return coordinates[coordinates.count / 2]
    }
}

/// Loads and caches the outdoor route geometry for standalone Apple Health workouts (roughly the
/// last 10) so they can be drawn on the cardio map alongside app sessions. Built to mirror the
/// per-workout route query in `HealthWorkoutDetailLoader`, just batched across workouts.
@Observable final class CardioHealthRouteLoader {
    private let healthStore = HealthAuthorizationManager.healthStore
    private(set) var routesByWorkoutID: [UUID: [CLLocationCoordinate2D]] = [:]
    @ObservationIgnored private var requestedIDs: Set<UUID> = []

    func load(workouts: [HealthWorkout], maxWorkouts: Int = 10) async {
        guard HealthAuthorizationManager.isHealthDataAvailable else { return }
        for workout in workouts.prefix(maxWorkouts) {
            let id = workout.healthWorkoutUUID
            guard requestedIDs.insert(id).inserted else { continue }
            guard workout.isAvailableInHealthKit else { continue }
            do {
                let coordinates = try await loadRoute(workoutUUID: id)
                if coordinates.count >= 2 {
                    routesByWorkoutID[id] = coordinates
                }
            } catch {
                AppLog.error("Failed to load cardio map route for Health workout \(id)", error: error)
            }
        }
    }

    private func loadRoute(workoutUUID: UUID) async throws -> [CLLocationCoordinate2D] {
        let workoutPredicate = NSPredicate(format: "%K == %@", HKPredicateKeyPathUUID, workoutUUID as NSUUID)
        let workoutDescriptor = HKSampleQueryDescriptor(predicates: [.workout(workoutPredicate)], sortDescriptors: [], limit: 1)
        guard let workout = try await workoutDescriptor.result(for: healthStore).first else { return [] }

        let routePredicate = HKQuery.predicateForObjects(from: workout)
        let routeDescriptor = HKSampleQueryDescriptor(predicates: [.workoutRoute(routePredicate)], sortDescriptors: [SortDescriptor(\.startDate, order: .forward)], limit: HKObjectQueryNoLimit)
        let routes = try await routeDescriptor.result(for: healthStore)
        guard !routes.isEmpty else { return [] }

        var coordinates: [CLLocationCoordinate2D] = []
        for route in routes {
            let routeQuery = HKWorkoutRouteQueryDescriptor(route)
            for try await location in routeQuery.results(for: healthStore) {
                let coordinate = location.coordinate
                guard CLLocationCoordinate2DIsValid(coordinate) else { continue }
                if let last = coordinates.last, abs(last.latitude - coordinate.latitude) < 0.000_001, abs(last.longitude - coordinate.longitude) < 0.000_001 { continue }
                coordinates.append(coordinate)
            }
        }
        return downsampled(coordinates, maxPoints: 400)
    }

    private func downsampled(_ coordinates: [CLLocationCoordinate2D], maxPoints: Int) -> [CLLocationCoordinate2D] {
        guard coordinates.count > maxPoints, maxPoints > 1 else { return coordinates }
        let stride = Double(coordinates.count - 1) / Double(maxPoints - 1)
        return (0..<maxPoints).compactMap { index in
            let pointIndex = Int((Double(index) * stride).rounded())
            return coordinates.indices.contains(pointIndex) ? coordinates[pointIndex] : nil
        }
    }
}

struct CardioRoutesMapView: View {
    let routes: [CardioMapRoute]
    let distanceUnit: DistanceUnit
    let onViewFully: (CardioMapRoute) -> Void

    @State private var position: MapCameraPosition = .automatic
    @State private var selectedRoute: CardioMapRoute?

    var body: some View {
        Map(position: $position) {
            UserAnnotation()

            ForEach(routes) { route in
                MapPolyline(coordinates: route.coordinates)
                    .stroke(route.isActive ? .green : .blue, lineWidth: route.isActive ? 5 : 3)

                if let mid = route.midCoordinate {
                    Annotation(route.title, coordinate: mid) {
                        routeMarker(for: route)
                    }
                    .annotationTitles(.hidden)
                }
            }
        }
        .mapControls {
            MapCompass()
        }
    }

    private func routeMarker(for route: CardioMapRoute) -> some View {
        Button {
            Haptics.selection()
            selectedRoute = route
        } label: {
            Image(systemName: route.isActive ? "figure.run.circle.fill" : "mappin.circle.fill")
                .font(.title3)
                .foregroundStyle(route.isActive ? .green : .blue)
                .padding(4)
                .background(.regularMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(route.title) route"))
        .accessibilityHint(Text("Shows distance, time, and pace, and lets you open the full session."))
        .popover(item: Binding(get: { selectedRoute?.id == route.id ? selectedRoute : nil }, set: { selectedRoute = $0 })) { route in
            CardioRoutePopover(route: route, distanceUnit: distanceUnit) {
                selectedRoute = nil
                onViewFully(route)
            }
            .presentationCompactAdaptation(.popover)
        }
    }
}

private struct CardioRoutePopover: View {
    let route: CardioMapRoute
    let distanceUnit: DistanceUnit
    let onViewFully: () -> Void

    private var paceText: String {
        formattedPaceText(duration: route.duration, distanceMeters: route.distanceMeters, distanceUnit: distanceUnit) ?? "-"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(route.title)
                    .font(.headline)
                Text(route.date, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                routeStat(title: "Distance", value: formattedDistanceText(route.distanceMeters, unit: distanceUnit))
                routeStat(title: "Time", value: secondsToTimeWithHours(Int(route.duration.rounded())))
                routeStat(title: "Pace", value: paceText)
            }

            Button {
                onViewFully()
            } label: {
                Label("View Fully", systemImage: "arrow.up.forward.square")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
        }
        .padding(16)
        .frame(minWidth: 260)
    }

    private func routeStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
    }
}
