import SwiftData
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

struct CardioTabView: View {
    @State private var router = AppRouter.shared
    @Query(CardioSession.recentCompleted(limit: 12)) private var recentSessions: [CardioSession]
    @Query(HealthWorkout.recentRunWalk(limit: 20)) private var recentRunWalkWorkouts: [HealthWorkout]
    @Query(AppSettings.single) private var appSettings: [AppSettings]
    @Environment(\.modelContext) private var context

    private var routeSessions: [CardioSession] {
        recentSessions.filter { session in
            guard session.kind.isOutdoor else { return false }
            return (session.routePoints?.count ?? 0) >= 2
        }
    }

    private var hasAnyCompletedOutdoorSession: Bool {
        recentSessions.contains { $0.kind.isOutdoor }
    }

    private var standaloneOutdoorWorkouts: [HealthWorkout] {
        recentRunWalkWorkouts.filter { $0.cardioSession == nil && $0.isIndoorWorkout == false }
    }

    private var mergedHistory: [CardioHistoryItem] {
        let sessions = recentSessions.map { CardioHistoryItem.session($0) }
        let hkWorkouts = standaloneOutdoorWorkouts.map { CardioHistoryItem.healthWorkout($0) }
        return (sessions + hkWorkouts).sorted { $0.date > $1.date }.prefix(16).map { $0 }
    }

    var body: some View {
        NavigationStack(path: Binding(get: { router.cardioTabPath }, set: { router.cardioTabPath = $0; router.noteNavigationStateChanged() })) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    CardioRouteMapView(sessions: Array(routeSessions.prefix(8)), showsUserLocation: true)
                        .frame(height: 430)
                        .blur(radius: routeSessions.isEmpty ? 6 : 0)
                        .overlay {
                            if routeSessions.isEmpty {
                                ContentUnavailableView {
                                    Label("No Routes Yet", systemImage: "map")
                                } description: {
                                    Text(hasAnyCompletedOutdoorSession ? "Your recent outdoor sessions didn't record a route. Start a new one with location enabled." : "Complete an outdoor run or walk to build your route map.")
                                }
                                .padding()
                                .foregroundStyle(.white)
                            }
                        }
                        .overlay(alignment: .topLeading) {
                            if !routeSessions.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Recent Routes")
                                        .font(.headline)
                                    Text("Last \(min(routeSessions.count, 8)) outdoor sessions")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(10)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .padding(12)
                            }
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
            .navigationDestination(for: AppRouter.Destination.self) { destination in
                switch destination {
                case .cardioSessionDetail(let session):
                    CardioSessionDetailView(session: session, showsCloseButton: false)
                case .healthWorkoutDetail(let workout):
                    HealthWorkoutDetailView(workout: workout)
                default:
                    EmptyView()
                }
            }
        }
        .id(router.cardioTabResetToken)
    }

    private var startCardioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Start Cardio")
                .font(.title3.bold())

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(CardioSessionKind.allCases, id: \.self) { kind in
                    let isFavorite = appSettings.first?.favoriteCardioKind == kind
                    Button {
                        if kind.isOutdoor {
                            router.requestOutdoorCardioSession(kind: kind)
                        } else {
                            router.requestManualCardioSession(kind: kind)
                        }
                        Task { await IntentDonations.donateStartCardioSession(kind: kind) }
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: kind.systemImage)
                                    .font(.title2)
                                Spacer()
                                if isFavorite {
                                    Image(systemName: "star.fill")
                                        .font(.caption)
                                        .foregroundStyle(.yellow)
                                }
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(kind.title)
                                    .font(.headline)
                                Text(kind.isOutdoor ? "GPS route" : (HealthAuthorizationManager.canWriteWorkouts ? "Apple Health workout" : "Manual intervals"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                    }
                    .buttonStyle(.plain)
                    .appSurfaceStyle(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityIdentifier(AccessibilityIdentifiers.cardioStart(kindRawValue: kind.rawValue))
                    .accessibilityLabel(Text("Start \(kind.title)"))
                    .accessibilityHint(Text(kind.isOutdoor ? "Starts an outdoor cardio session with GPS route recording." : "Starts a treadmill cardio session with manual interval entry."))
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
                                setFavorite(kind)
                            } label: {
                                Label("Set as Favorite", systemImage: "star")
                            }
                        }
                    }
                }
            }
        }
    }

    private func setFavorite(_ kind: CardioSessionKind?) {
        guard let settings = appSettings.first else { return }
        settings.favoriteCardioKind = kind
        saveContext(context: context)
    }

    private var recentHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Cardio")
                    .font(.title3.bold())
                Spacer()
                Text("\(mergedHistory.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(Array(mergedHistory.enumerated()), id: \.element.id) { index, item in
                    Group {
                        switch item {
                        case .session(let session):
                            Button {
                                router.push(to: .cardioSessionDetail(session))
                            } label: {
                                CardioSessionHistoryRow(session: session)
                            }
                            .buttonStyle(.plain)
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
                        }
                    }
                    .appGroupedStackRow(position: rowPosition(for: index, count: mergedHistory.count))
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
            Image(systemName: session.kind.systemImage)
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
