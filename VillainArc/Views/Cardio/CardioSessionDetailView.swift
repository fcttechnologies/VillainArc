import AppIntents
import CoreLocation
import CoreSpotlight
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
    @State private var shareImage: Image?
    @State private var localHealthWorkout: HealthWorkout?

    private var distanceUnit: DistanceUnit { appSettings.first?.distanceUnit ?? .systemDefault }
    private var energyUnit: EnergyUnit { appSettings.first?.energyUnit ?? .systemDefault }

    var body: some View {
        // Only a session that recorded an app GPS route gets the immersive map. Non-route sessions
        // normally open directly in HealthWorkoutDetailView; this fallback still reads as a plain
        // scrolling detail when there is no mirrored Health workout yet.
        Group {
            if session.usesRoute {
                outdoorLayout
            } else {
                indoorLayout
            }
        }
        .userActivity("com.villainarc.cardioSession.view", element: session) { session, activity in
            activity.title = session.displayTitle
            activity.isEligibleForSearch = true
            activity.isEligibleForPrediction = true
            activity.persistentIdentifier = NSUserActivityPersistentIdentifier(SpotlightIndexer.cardioSessionIdentifier(for: session.id))
            let attributeSet = activity.contentAttributeSet ?? CSSearchableItemAttributeSet(contentType: .item)
            attributeSet.relatedUniqueIdentifier = SpotlightIndexer.cardioSessionIdentifier(for: session.id)
            activity.contentAttributeSet = attributeSet
            let entity = CardioSessionEntity(cardioSession: session)
            activity.appEntityIdentifier = .init(for: entity)
        }
    }

    // Outdoor (GPS) sessions keep the immersive route map, with the metrics in a bottom
    // card via a safe-area inset — not a blocking sheet. The old always-presented sheet
    // (interactiveDismissDisabled) sat over a pushed "View in Health" detail and never
    // dismissed; the inset lets that navigation read cleanly.
    private var outdoorLayout: some View {
        ZStack(alignment: .top) {
            outdoorMap
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
        .safeAreaInset(edge: .bottom) {
            ScrollView {
                CardioMetricsSheet(session: session, distanceUnit: distanceUnit, energyUnit: energyUnit, onOpenHealthWorkout: openHealthHandler)
                    .padding(.vertical, 12)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: 320)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .task(id: session.id) {
            updateInitialCameraPosition()
            renderShareCard()
        }
        .navigationDestination(isPresented: localHealthWorkoutPresented) {
            if let localHealthWorkout {
                HealthWorkoutDetailView(workout: localHealthWorkout)
            }
        }
    }

    // Indoor / non-GPS sessions have no map — a regular scrolling detail, the way a Health
    // workout reads. Only outdoor route sessions get a map.
    private var indoorLayout: some View {
        ScrollView {
            CardioMetricsSheet(session: session, distanceUnit: distanceUnit, energyUnit: energyUnit, onOpenHealthWorkout: openHealthHandler)
                .padding(.top, 12)
        }
        .scrollBounceBehavior(.basedOnSize)
        .appBackground()
        .navigationTitle(session.displayTitle)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            if showsCloseButton {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .accessibilityLabel(Text("Close"))
                        .accessibilityIdentifier(AccessibilityIdentifiers.cardioSessionDetailCloseButton)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                shareControl {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(Text("Share session"))
            }
        }
        .task(id: session.id) { renderShareCard() }
        .navigationDestination(isPresented: localHealthWorkoutPresented) {
            if let localHealthWorkout {
                HealthWorkoutDetailView(workout: localHealthWorkout)
            }
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
            .accessibilityIdentifier(AccessibilityIdentifiers.cardioSessionDetailBackButton)

            Spacer()

            shareControl {
                Image(systemName: "square.and.arrow.up")
                    .font(.headline.weight(.semibold))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel(Text("Share session"))
        }
    }

    /// Shares a rendered Strava-style summary card image once it's ready, falling back to a short
    /// text summary for the brief moment before the image renders (or if rendering fails).
    @ViewBuilder
    private func shareControl<Label: View>(@ViewBuilder label: () -> Label) -> some View {
        if let shareImage {
            ShareLink(item: shareImage, preview: SharePreview(session.displayTitle, image: shareImage), label: label)
                .accessibilityIdentifier(AccessibilityIdentifiers.cardioSessionDetailShareButton)
        } else {
            ShareLink(item: shareableSummary, label: label)
                .accessibilityIdentifier(AccessibilityIdentifiers.cardioSessionDetailShareButton)
        }
    }

    @MainActor
    private func renderShareCard() {
        let renderer = ImageRenderer(content: CardioShareCard(session: session, distanceUnit: distanceUnit, energyUnit: energyUnit))
        renderer.scale = 3
        if let uiImage = renderer.uiImage {
            shareImage = Image(uiImage: uiImage)
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

    private func updateInitialCameraPosition() {
        let coordinates = session.sortedRoutePoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        if coordinates.count >= 2 {
            cameraPosition = .region(region(for: coordinates))
        } else if let first = coordinates.first {
            cameraPosition = .region(MKCoordinateRegion(center: first, span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)))
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
            return "Just finished a \(session.typeTitle.lowercased()): \(distance) in \(duration) with Villain Arc."
        } else {
            return "Just finished a \(session.typeTitle.lowercased()): \(duration) with Villain Arc."
        }
    }

    private var openHealthHandler: (() -> Void)? {
        guard session.usesRoute, session.healthWorkout != nil else { return nil }
        return openHealthWorkout
    }

    private var localHealthWorkoutPresented: Binding<Bool> {
        Binding(
            get: { localHealthWorkout != nil },
            set: { isPresented in
                if !isPresented { localHealthWorkout = nil }
            }
        )
    }

    private func openHealthWorkout() {
        guard let workout = session.healthWorkout else { return }
        if showsCloseButton {
            localHealthWorkout = workout
            Haptics.selection()
            return
        }
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

            if (1...10).contains(session.postEffort) {
                WorkoutEffortCardView(model: .init(title: workoutEffortTitle(session.postEffort), description: workoutEffortDescription(session.postEffort), valueText: "\(session.postEffort)", score: Double(session.postEffort), caption: nil))
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
                    Image(systemName: session.systemImage)
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
        switch session.activity {
        case .run: return .orange
        case .walk: return .blue
        default: return .green
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
