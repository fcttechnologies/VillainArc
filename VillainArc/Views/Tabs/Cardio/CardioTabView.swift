import AppIntents
import CoreLocation
import SwiftData
import FCTMetrics
import SwiftUI
import HealthKit

private enum CardioHistoryItem: Identifiable {
    case session(CardioSession)
    case healthWorkout(HealthWorkout)

    var id: UUID {
        switch self {
        case .session(let s): return s.id
        case .healthWorkout(let hw): return hw.healthWorkoutUUID
        }
    }

    var date: Date {
        switch self {
        case .session(let s): return s.startedAt ?? .distantPast
        case .healthWorkout(let hw): return hw.startDate
        }
    }
}

private enum CardioRouteRange: String, CaseIterable, Identifiable {
    case day, week, month, sixMonths

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: return "Day"
        case .week: return "Week"
        case .month: return "Month"
        case .sixMonths: return "6M"
        }
    }

    var startDate: Date {
        let cal = Calendar.autoupdatingCurrent
        switch self {
        case .day: return cal.date(byAdding: .day, value: -1, to: .now) ?? .distantPast
        case .week: return cal.date(byAdding: .day, value: -7, to: .now) ?? .distantPast
        case .month: return cal.date(byAdding: .month, value: -1, to: .now) ?? .distantPast
        case .sixMonths: return cal.date(byAdding: .month, value: -6, to: .now) ?? .distantPast
        }
    }
}

struct CardioTabView: View {
    @State private var router = AppRouter.shared
    @State private var routeLoader = CardioHealthRouteLoader()
    // Persisted in UserDefaults so the chosen range survives relaunch. CardioRouteRange is
    // String-backed (RawRepresentable), which @AppStorage stores directly.
    @AppStorage("cardio_route_range") private var routeRange: CardioRouteRange = .month
    @Query(CardioSession.recentCompleted(limit: 12)) private var recentSessions: [CardioSession]
    @Query(HealthWorkout.recentRunWalk(limit: 20)) private var recentRunWalkWorkouts: [HealthWorkout]
    @Query(AppSettings.single) private var appSettings: [AppSettings]
    @Environment(\.modelContext) private var context

    private var distanceUnit: DistanceUnit { appSettings.first?.distanceUnit ?? .systemDefault }

    private var routeSessions: [CardioSession] {
        recentSessions.filter { session in
            guard session.isOutdoor else { return false }
            return (session.routePoints?.count ?? 0) >= 2
        }
    }

    private var hasAnyCompletedOutdoorSession: Bool {
        recentSessions.contains { $0.isOutdoor }
    }

    /// Apple Health run/walk workouts not already linked to an app session, outdoor only — these are
    /// the ones with a route to draw on the map.
    private var standaloneOutdoorWorkouts: [HealthWorkout] {
        recentRunWalkWorkouts.filter { $0.cardioSession == nil && $0.isIndoorWorkout == false }
    }

    /// App-owned outdoor routes plus cached Apple Health outdoor routes, newest first, capped so the
    /// map never draws more than ~10 overlapping routes at once.
    private var mapRoutes: [CardioMapRoute] {
        var result: [CardioMapRoute] = []

        for session in routeSessions {
            let coordinates = session.sortedRoutePoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            guard coordinates.count >= 2 else { continue }
            result.append(CardioMapRoute(
                id: "session-\(session.id.uuidString)",
                coordinates: coordinates,
                isActive: session.statusValue == .active,
                title: session.displayTitle,
                distanceMeters: session.totalDistanceMeters,
                duration: session.duration,
                date: session.startedAt ?? .distantPast,
                target: .appSession(session),
                systemImage: session.systemImage
            ))
        }

        for workout in standaloneOutdoorWorkouts {
            guard let coordinates = routeLoader.routesByWorkoutID[workout.healthWorkoutUUID], coordinates.count >= 2 else { continue }
            result.append(CardioMapRoute(
                id: "health-\(workout.healthWorkoutUUID.uuidString)",
                coordinates: coordinates,
                isActive: false,
                title: workout.activityTypeDisplayName,
                distanceMeters: workout.totalDistance ?? 0,
                duration: workout.duration,
                date: workout.startDate,
                target: .healthWorkout(workout),
                systemImage: workout.activityType == .running ? "figure.run" : "figure.walk"
            ))
        }

        let cutoff = routeRange.startDate
        return Array(result.filter { $0.date >= cutoff }.sorted { $0.date > $1.date }.prefix(10))
    }

    private func openRouteDetail(_ route: CardioMapRoute) {
        switch route.target {
        case .appSession(let session):
            router.push(to: .cardioSessionDetail(session))
        case .healthWorkout(let workout):
            router.cardioTabPath.append(.healthWorkoutDetail(workout))
            router.noteNavigationStateChanged()
            Haptics.selection()
        }
    }

    private var mergedHistory: [CardioHistoryItem] {
        let sessions = recentSessions.filter(\.usesRoute).map { CardioHistoryItem.session($0) }
        let hkWorkouts = standaloneOutdoorWorkouts.map { CardioHistoryItem.healthWorkout($0) }
        return (sessions + hkWorkouts).sorted { $0.date > $1.date }.prefix(16).map { $0 }
    }

    var body: some View {
        NavigationStack(path: Binding(get: { router.cardioTabPath }, set: { router.cardioTabPath = $0; router.noteNavigationStateChanged() })) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    let routes = mapRoutes
                    CardioRoutesMapView(routes: routes, distanceUnit: distanceUnit, onViewFully: openRouteDetail)
                        .frame(height: 430)
                        .blur(radius: routes.isEmpty ? 6 : 0)
                        .overlay {
                            if routes.isEmpty {
                                ContentUnavailableView {
                                    Label("No Routes Yet", systemImage: "map")
                                } description: {
                                    Text(hasAnyCompletedOutdoorSession ? "Your recent outdoor sessions didn't record a route. Start a new one with location enabled." : "Complete an outdoor run or walk to build your route map.")
                                }
                                .padding()
                                .foregroundStyle(.white)
                            }
                        }
                        .task(id: standaloneOutdoorWorkouts.map(\.healthWorkoutUUID)) {
                            await routeLoader.load(workouts: standaloneOutdoorWorkouts)
                        }

                    VStack(alignment: .leading, spacing: 16) {
                        startCardioSection

                        if mergedHistory.isEmpty {
                            ContentUnavailableView("No Cardio Yet", systemImage: "figure.run", description: Text("Outdoor routes and treadmill sessions will show up here."))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                        } else {
                            recentHistorySection
                        }
                    }
                    .padding()
                }
            }
            .quickActionContentBottomInset()
            .appBackground()
            .scrollIndicators(.hidden)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Route Range", selection: $routeRange) {
                            ForEach(CardioRouteRange.allCases) { range in
                                Text(range.title).tag(range)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(routeRange.title)
                            Image(systemName: "chevron.down")
                                .font(.caption2.weight(.bold))
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                    .accessibilityLabel(Text("Route time range"))
                    .accessibilityValue(Text(routeRange.title))
                    .accessibilityHint(Text("Filters the route map by time range."))
                    .accessibilityIdentifier(AccessibilityIdentifiers.cardioRouteRangeMenu)
                }
            }
            .navigationDestination(for: AppRouter.Destination.self) { destination in
                switch destination {
                case .cardioSessionDetail(let session):
                    if !session.usesRoute, let workout = session.healthWorkout {
                        HealthWorkoutDetailView(workout: workout)
                    } else {
                        CardioSessionDetailView(session: session, showsCloseButton: false)
                    }
                case .healthWorkoutDetail(let workout):
                    HealthWorkoutDetailView(workout: workout)
                default:
                    EmptyView()
                }
            }
        }
        .id(router.cardioTabResetToken)
        .diagScreen(VACrumb.cardioTab)
    }

    private var startCardioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Start Cardio")
                .font(.title3.bold())

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(CardioSessionType.presets) { type in
                    let isFavorite = appSettings.first?.favoriteCardioType == type
                    Button {
                        router.requestCardioSession(type: type)
                        Task { await IntentDonations.donateStartCardioSession(type: type) }
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: type.systemImage)
                                    .font(.title2)
                                Spacer()
                                if isFavorite {
                                    Image(systemName: "star.fill")
                                        .font(.caption)
                                        .foregroundStyle(.yellow)
                                }
                            }
                            Text(type.title)
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                    }
                    .buttonStyle(.plain)
                    .appSurfaceStyle(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityIdentifier(AccessibilityIdentifiers.cardioStart(kindRawValue: type.rawValue))
                    .accessibilityLabel(Text("Start \(type.title)"))
                    .accessibilityHint(Text(type.isOutdoor ? "Starts an outdoor cardio session with GPS route recording." : "Starts a treadmill cardio session with manual interval entry."))
                    .accessibilityAddTraits(isFavorite ? [.isButton] : [.isButton])
                    .contextMenu {
                        if isFavorite {
                            Button(role: .destructive) {
                                setFavorite(nil)
                            } label: {
                                Label("Remove Favorite", systemImage: "star.slash")
                            }
                        } else {
                            Button {
                                setFavorite(type)
                            } label: {
                                Label("Set as Favorite", systemImage: "star")
                            }
                        }
                    }
                }
            }
        }
    }

    private func setFavorite(_ type: CardioSessionType?) {
        guard let settings = appSettings.first else { return }
        settings.favoriteCardioType = type
        saveContext(context: context)
    }

    private var recentCardio: [CardioHistoryItem] {
        Array(mergedHistory.prefix(5))
    }

    private func openAllCardioHistory() {
        Haptics.selection()
        router.pendingWorkoutHistoryFilterID = WorkoutsListView.cardioFilterRequestID
        router.navigate(to: .workoutSessionsList)
    }

    private var recentHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Cardio")
                    .font(.title3.bold())
                Spacer()
                Button("View All") {
                    openAllCardioHistory()
                }
                .font(.subheadline.weight(.semibold))
                .accessibilityHint(Text("Opens all cardio history filtered to your cardio workouts."))
                .accessibilityIdentifier(AccessibilityIdentifiers.cardioViewAllHistoryButton)
            }

            VStack(spacing: 0) {
                ForEach(Array(recentCardio.enumerated()), id: \.element.id) { index, item in
                    Group {
                        switch item {
                        case .session(let session):
                            Button {
                                router.push(to: AppRouter.detailDestination(for: session))
                            } label: {
                                CardioSessionHistoryRow(session: session)
                            }
                            .buttonStyle(.plain)
                            .villainArcAppEntityIdentifier(CardioSessionEntity.self, id: session.id)
                            .accessibilityIdentifier(AccessibilityIdentifiers.cardioHistoryRow(sessionID: session.id.uuidString))
                        case .healthWorkout(let hw):
                            Button {
                                router.cardioTabPath.append(.healthWorkoutDetail(hw))
                                router.noteNavigationStateChanged()
                                Haptics.selection()
                            } label: {
                                CardioHealthWorkoutHistoryRow(workout: hw)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier(AccessibilityIdentifiers.cardioHealthWorkoutHistoryRow(uuid: hw.healthWorkoutUUID.uuidString))
                        }
                    }
                    .appGroupedStackRow(position: rowPosition(for: index, count: recentCardio.count))
                }
            }
        }
    }
}

private struct CardioHealthWorkoutHistoryRow: View {
    let workout: HealthWorkout
    @Query(AppSettings.single) private var appSettings: [AppSettings]

    private var distanceUnit: DistanceUnit { appSettings.first?.distanceUnit ?? .systemDefault }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: workout.activityType == .running ? "figure.run" : "figure.walk")
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(workout.activityTypeDisplayName)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(workout.startDate, format: .dateTime.month(.abbreviated).day().hour().minute())
                    Text("·")
                    Text("Apple Health")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                if let distance = workout.totalDistance, distance > 0 {
                    Text(formattedDistanceText(distance, unit: distanceUnit))
                        .font(.subheadline.weight(.semibold))
                }
                Text(secondsToTimeWithHours(Int(workout.duration.rounded())))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct CardioSessionHistoryRow: View {
    let session: CardioSession
    @Query(AppSettings.single) private var appSettings: [AppSettings]

    private var distanceUnit: DistanceUnit { appSettings.first?.distanceUnit ?? .systemDefault }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: session.systemImage)
                .font(.title3)
                .foregroundStyle(.green)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(session.displayTitle)
                    .font(.headline)
                    .lineLimit(1)
                if let startedAt = session.startedAt {
                    Text(startedAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(formattedDistanceText(session.totalDistanceMeters, unit: distanceUnit))
                    .font(.subheadline.weight(.semibold))
                Text(formattedPaceText(duration: session.duration, distanceMeters: session.totalDistanceMeters, distanceUnit: distanceUnit) ?? secondsToTimeWithHours(Int(session.duration.rounded())))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private func rowPosition(for index: Int, count: Int) -> AppGroupedListRowPosition {
    if count <= 1 { return .single }
    if index == 0 { return .top }
    if index == count - 1 { return .bottom }
    return .middle
}

#Preview(traits: .sampleData) {
    CardioTabView()
}
