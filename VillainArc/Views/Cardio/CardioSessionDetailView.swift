import CoreLocation
import HealthKit
import MapKit
import SwiftData
import SwiftUI

struct CardioSessionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: CardioSession
    let showsCloseButton: Bool
    @Query(AppSettings.single) private var appSettings: [AppSettings]
    @State private var router = AppRouter.shared
    @State private var cameraPosition: MapCameraPosition = .automatic
    // Read-only location-auth check (never requests). An indoor/treadmill session detail must not
    // request location, so the live-location dot + camera are shown only when the user already
    // granted location for outdoor cardio.
    @State private var routeRecorder = CardioRouteRecorder.shared

    private var distanceUnit: DistanceUnit { appSettings.first?.distanceUnit ?? .systemDefault }
    private var energyUnit: EnergyUnit { appSettings.first?.energyUnit ?? .systemDefault }

    var body: some View {
        ZStack(alignment: .top) {
            mapLayer
                .ignoresSafeArea()

            LinearGradient(colors: [Color.black.opacity(0.35), Color.black.opacity(0.0)], startPoint: .top, endPoint: .center)
                .allowsHitTesting(false)
                .ignoresSafeArea()

            VStack {
                topControls
                    .padding(.horizontal)
                    .padding(.top, 8)
                Spacer()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: .constant(true)) {
            ScrollView {
                CardioMetricsSheet(session: session, distanceUnit: distanceUnit, energyUnit: energyUnit, onOpenHealthWorkout: openHealthHandler)
                    .padding(.top, 12)
            }
            .scrollBounceBehavior(.basedOnSize)
            .presentationDetents([.medium, .large])
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            .presentationDragIndicator(.hidden)
            .interactiveDismissDisabled(true)
            .presentationBackground(.regularMaterial)
        }
        .task(id: session.id) {
            updateInitialCameraPosition()
        }
    }

    private var topControls: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: showsCloseButton ? "xmark" : "chevron.left")
                    .font(.headline.weight(.semibold))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel(Text(showsCloseButton ? "Close" : "Back"))

            Spacer()

            ShareLink(item: shareableSummary) {
                Image(systemName: "square.and.arrow.up")
                    .font(.headline.weight(.semibold))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel(Text("Share session"))
        }
    }

    @ViewBuilder
    private var mapLayer: some View {
        if session.kind.isOutdoor {
            outdoorMap
        } else {
            indoorMap
        }
    }

    private var outdoorMap: some View {
        let coordinates = session.sortedRoutePoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        return Map(position: $cameraPosition, interactionModes: [.pan, .zoom, .rotate]) {
            if coordinates.count >= 2 {
                MapPolyline(coordinates: coordinates)
                    .stroke(Color.purple.gradient, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))

                if let start = coordinates.first {
                    Annotation("Start", coordinate: start) {
                        CardioRouteMarker(systemImage: "figure.run", tint: .green)
                    }
                    .annotationTitles(.hidden)
                }

                if let end = coordinates.last {
                    Annotation("Finish", coordinate: end) {
                        CardioRouteMarker(systemImage: "flag.checkered", tint: .red)
                    }
                    .annotationTitles(.hidden)
                }
            } else if let only = coordinates.first {
                Annotation("Location", coordinate: only) {
                    CardioRouteMarker(systemImage: "mappin", tint: .orange)
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard)
        .overlay(alignment: .center) {
            if session.sortedRoutePoints.isEmpty {
                Text("No route recorded")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule())
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 280)
            }
        }
    }

    private var indoorMap: some View {
        Map(position: $cameraPosition, interactionModes: [.pan, .zoom, .rotate]) {
            if let coordinate = sessionLocation {
                Annotation("Location", coordinate: coordinate) {
                    CardioRouteMarker(systemImage: "mappin", tint: .orange)
                }
                .annotationTitles(.hidden)
            } else if routeRecorder.canRecord {
                UserAnnotation()
            }
        }
        .mapStyle(.standard)
    }

    private var sessionLocation: CLLocationCoordinate2D? {
        if let point = session.sortedRoutePoints.first {
            return CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
        }
        return nil
    }

    private func updateInitialCameraPosition() {
        let coordinates = session.sortedRoutePoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        if coordinates.count >= 2 {
            cameraPosition = .region(region(for: coordinates))
        } else if let first = coordinates.first {
            cameraPosition = .region(MKCoordinateRegion(center: first, span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)))
        } else if session.kind.isManual, routeRecorder.canRecord {
            cameraPosition = .userLocation(fallback: .automatic)
        } else {
            cameraPosition = .automatic
        }
    }

    private func region(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)
        let minLat = latitudes.min() ?? 0
        let maxLat = latitudes.max() ?? 0
        let minLon = longitudes.min() ?? 0
        let maxLon = longitudes.max() ?? 0
        // Zoom out a little, and shift the center south so the route sits in the upper half,
        // clear of the medium metrics sheet covering the bottom.
        let latSpan = max((maxLat - minLat) * 1.9, 0.004)
        let lonSpan = max((maxLon - minLon) * 1.9, 0.004)
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2 - latSpan * 0.3, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(latitudeDelta: latSpan, longitudeDelta: lonSpan)
        return MKCoordinateRegion(center: center, span: span)
    }

    private var shareableSummary: String {
        let distance = formattedDistanceText(session.totalDistanceMeters, unit: distanceUnit)
        let duration = secondsToTimeWithHours(Int(session.duration.rounded()))
        if session.totalDistanceMeters > 0 {
            return "Just finished a \(session.kind.title.lowercased()): \(distance) in \(duration) with Villain Arc."
        } else {
            return "Just finished a \(session.kind.title.lowercased()): \(duration) with Villain Arc."
        }
    }

    private var openHealthHandler: (() -> Void)? {
        guard !showsCloseButton, session.healthWorkout != nil else { return nil }
        return openHealthWorkout
    }

    private func openHealthWorkout() {
        guard let workout = session.healthWorkout else { return }
        router.cardioTabPath.append(.healthWorkoutDetail(workout))
        router.noteNavigationStateChanged()
        Haptics.selection()
    }
}

struct CardioMetricsSheet: View {
    let session: CardioSession
    let distanceUnit: DistanceUnit
    let energyUnit: EnergyUnit
    let onOpenHealthWorkout: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerRow

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(metricItems) { item in
                    MetricTile(title: item.title, value: item.value, systemImage: item.systemImage, tint: item.tint, subCaption: item.subCaption)
                }
            }

            if session.healthWorkout != nil, let onOpenHealthWorkout {
                Button {
                    onOpenHealthWorkout()
                } label: {
                    HStack {
                        Label("View in Health", systemImage: "heart.text.square")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("cardio_detail_open_health_workout")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(kindTint.gradient)
                        .frame(width: 44, height: 44)
                    Image(systemName: session.kind.systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.displayTitle)
                        .font(.title3.bold())
                        .fontDesign(.rounded)
                        .lineLimit(1)
                    if let startedAt = session.startedAt {
                        Text(startedAt.formatted(.dateTime.weekday(.wide).month().day().year().hour().minute()))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var kindTint: Color {
        switch session.kind {
        case .outdoorRun, .treadmillRun: return .orange
        case .outdoorWalk, .treadmillWalk: return .blue
        }
    }

    private struct MetricItem: Identifiable {
        let id: String
        let title: String
        let value: String
        let systemImage: String
        let tint: Color
        let subCaption: String?
    }

    private var metricItems: [MetricItem] {
        var items: [MetricItem] = []
        items.append(MetricItem(id: "duration", title: "Duration", value: secondsToTimeWithHours(Int(session.duration.rounded())), systemImage: "clock", tint: .secondary, subCaption: nil))

        if session.totalDistanceMeters > 0 {
            items.append(MetricItem(id: "distance", title: "Distance", value: formattedDistanceText(session.totalDistanceMeters, unit: distanceUnit), systemImage: "point.topleft.down.curvedto.point.bottomright.up", tint: .secondary, subCaption: nil))
        }

        if let activeEnergy = session.healthWorkout?.activeEnergyBurned {
            items.append(MetricItem(id: "activeEnergy", title: "Active Energy", value: formattedEnergyText(activeEnergy, unit: energyUnit), systemImage: "flame", tint: .orange, subCaption: nil))
        }

        if let totalEnergy = session.healthWorkout?.totalEnergyBurned {
            items.append(MetricItem(id: "totalEnergy", title: "Total Energy", value: formattedEnergyText(totalEnergy, unit: energyUnit), systemImage: "flame.fill", tint: .orange, subCaption: nil))
        }

        if let pace = formattedPaceText(duration: session.duration, distanceMeters: session.totalDistanceMeters, distanceUnit: distanceUnit) {
            items.append(MetricItem(id: "pace", title: "Average Pace", value: pace, systemImage: "speedometer", tint: .secondary, subCaption: nil))
        }

        if let avgHR = session.healthWorkout?.averageHeartRateBPM {
            items.append(MetricItem(id: "avgHR", title: "Average Heart Rate", value: formattedHeartRateText(avgHR), systemImage: "heart", tint: .red, subCaption: nil))
        }

        if let maxHR = session.healthWorkout?.maximumHeartRateBPM {
            items.append(MetricItem(id: "maxHR", title: "Max Heart Rate", value: formattedHeartRateText(maxHR), systemImage: "bolt.heart", tint: .red, subCaption: nil))
        }

        return items
    }

}

/// A circular map marker badge with an SF Symbol icon, used for cardio route start/finish/location points.
struct CardioRouteMarker: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.gradient)
                .frame(width: 28, height: 28)
                .overlay(Circle().stroke(.white, lineWidth: 2))
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            Image(systemName: systemImage)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
        }
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        if let session = previewSession() {
            CardioSessionDetailView(session: session, showsCloseButton: false)
        } else {
            Text("No session")
        }
    }
}

@MainActor
private func previewSession() -> CardioSession? {
    let context = SharedModelContainer.container.mainContext
    let descriptor = CardioSession.recentCompleted(limit: 1)
    return try? context.fetch(descriptor).first
}
