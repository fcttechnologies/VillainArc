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
    /// SF Symbol for this route's marker — reflects run vs walk so the map distinguishes the two.
    let systemImage: String

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
    // Read-only location-auth check (never requests). The overview map shows the live-location dot
    // only when the user already granted location for outdoor cardio, so merely viewing the cardio
    // tab never triggers a location prompt. Location is requested solely by the outdoor-session start
    // flow (CardioStartView / CardioRouteRecorder).
    @State private var routeRecorder = CardioRouteRecorder.shared

    var body: some View {
        // With no routes for the selected range the map sits behind a "No Routes" overlay, so it
        // shouldn't pan/zoom/rotate under the message — only make it interactive when it has content.
        Map(position: $position, interactionModes: routes.isEmpty ? [] : [.pan, .zoom, .rotate]) {
            if routeRecorder.canRecord {
                UserAnnotation()
            }

            ForEach(Array(routes.enumerated()), id: \.element.id) { index, route in
                let color = routeColor(for: route, index: index)
                MapPolyline(coordinates: route.coordinates)
                    .stroke(color.gradient, style: StrokeStyle(lineWidth: route.isActive ? 6 : 4, lineCap: .round, lineJoin: .round))

                if let mid = route.midCoordinate {
                    Annotation(route.title, coordinate: mid) {
                        routeMarker(for: route, color: color)
                    }
                    .annotationTitles(.hidden)
                }
            }
        }
        .mapControls {
            MapCompass()
        }
        .ignoresSafeArea(edges: .top)
    }

    private static let routeColors: [Color] = [.blue, .orange, .purple, .pink, .teal, .indigo, .red, .cyan, .mint, .brown]

    private func routeColor(for route: CardioMapRoute, index: Int) -> Color {
        route.isActive ? .green : Self.routeColors[index % Self.routeColors.count]
    }

    private func routeMarker(for route: CardioMapRoute, color: Color) -> some View {
        Button {
            Haptics.selection()
            selectedRoute = route
        } label: {
            Image(systemName: route.systemImage)
                .font(.title3)
                .foregroundStyle(color)
                .padding(4)
                .background(.regularMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(route.title) route"))
        .accessibilityHint(Text("Shows distance, time, and pace, and lets you open the full session."))
        .accessibilityIdentifier(AccessibilityIdentifiers.cardioRouteMarker(route.id))
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
            .accessibilityIdentifier(AccessibilityIdentifiers.cardioRouteViewFullyButton)
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
