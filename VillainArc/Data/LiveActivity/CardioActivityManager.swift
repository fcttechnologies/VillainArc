import ActivityKit
import Foundation
import SwiftData

enum CardioActivityManager {
    private static var lastDeliveredActivityID: String?
    private static var lastDeliveredState: CardioActivityAttributes.ContentState?

    private static var liveActivitiesEnabled: Bool {
        let context = SharedModelContainer.container.mainContext
        return (try? context.fetch(AppSettings.single).first)?.liveActivitiesEnabled ?? true
    }

    static func start(session: CardioSession) {
        guard liveActivitiesEnabled else {
            endAllActivities()
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        endAllActivities()
        requestActivity(for: session)
    }

    // Rebuild the cardio Live Activity from scratch for an in-progress session
    // (Settings "Restart Live Activity"). start() already ends any existing activity
    // and requests a fresh one at the session's original startedAt, so restart is its
    // alias — kept for call-site parity with WorkoutActivityManager.restart(workout:).
    static func restart(session: CardioSession) {
        start(session: session)
    }

    static func restoreIfNeeded(session: CardioSession) {
        guard liveActivitiesEnabled else {
            endAllActivities()
            return
        }
        if currentActivity != nil {
            update(for: session)
        } else {
            start(session: session)
        }
    }

    static func update(for session: CardioSession? = nil) {
        guard liveActivitiesEnabled else {
            endAllActivities()
            return
        }
        guard let activity = currentActivity else { return }
        guard let session = resolveSession(for: session) else {
            endAllActivities()
            return
        }

        let state = normalizedContentState(for: contentState(for: session))
        guard shouldDeliver(state, toActivityID: activity.id) else { return }

        recordDeliveredState(state, forActivityID: activity.id)
        let activityID = activity.id
        Task { await updateActivity(id: activityID, state: state) }
    }

    static func end() { endAllActivities() }

    private static var currentActivity: Activity<CardioActivityAttributes>? { Activity<CardioActivityAttributes>.activities.first }

    private static func requestActivity(for session: CardioSession) {
        resetTrackedActivityState()
        let attributes = CardioActivityAttributes(startDate: session.startedAt ?? .now, kindTitle: session.typeTitle, isOutdoor: session.isOutdoor, captureModeRawValue: session.captureMode.rawValue)
        let state = normalizedContentState(for: contentState(for: session))

        do {
            let activity = try Activity.request(attributes: attributes, content: .init(state: state, staleDate: nil), pushType: nil)
            recordDeliveredState(state, forActivityID: activity.id)
        } catch {
            AppLog.error("Failed to start cardio Live Activity", error: error)
        }
    }

    private static func contentState(for session: CardioSession) -> CardioActivityAttributes.ContentState {
        let healthCoordinator = CardioHealthWorkoutCoordinator.shared
        let isActiveSession = healthCoordinator.activeCardioSessionID == session.id
        // One distance source per capture mode (the pace-bug fix): never mix the manual-interval
        // distance with the Watch's HealthKit estimate, which produced a different pace in the Live
        // Activity than the in-app view.
        let distance = session.resolvedDistanceMeters(healthKitDistance: isActiveSession ? healthCoordinator.distanceMeters : nil)
        let paceSecondsPerKilometer = distance > 0 ? (session.duration / distance) * 1_000 : nil

        return .init(
            title: session.displayTitle,
            distanceMeters: distance,
            paceSecondsPerKilometer: paceSecondsPerKilometer,
            liveHeartRateBPM: isActiveSession ? healthCoordinator.latestHeartRate : session.healthWorkout?.averageHeartRateBPM,
            activeEnergyBurned: isActiveSession ? healthCoordinator.activeEnergyBurned : session.healthWorkout?.activeEnergyBurned,
            routePointCount: session.routePoints?.count ?? 0,
            treadmillIntervalCount: session.machineIntervals?.count ?? 0,
            statusText: statusText(for: session)
        )
    }

    private static func statusText(for session: CardioSession) -> String {
        switch session.captureMode {
        case .gpsRoute: return "Route recording"
        case .machineIntervals: return "Manual intervals"
        case .healthKitOnly: return "Apple Health"
        }
    }

    private static func normalizedContentState(for state: CardioActivityAttributes.ContentState) -> CardioActivityAttributes.ContentState {
        var normalizedState = state
        normalizedState.distanceMeters = Double(Int(state.distanceMeters.rounded()))
        normalizedState.paceSecondsPerKilometer = state.paceSecondsPerKilometer.map { Double(Int($0.rounded())) }
        normalizedState.liveHeartRateBPM = state.liveHeartRateBPM.map { Double(Int($0.rounded())) }
        normalizedState.activeEnergyBurned = state.activeEnergyBurned.map { Double(Int($0.rounded())) }
        return normalizedState
    }

    private static func resolveSession(for session: CardioSession?) -> CardioSession? {
        if let session { return session }
        let context = SharedModelContainer.container.mainContext
        return try? context.fetch(CardioSession.incomplete).first
    }

    private static func shouldDeliver(_ state: CardioActivityAttributes.ContentState, toActivityID activityID: String) -> Bool {
        guard lastDeliveredActivityID == activityID else { return true }
        return lastDeliveredState != state
    }

    private static func recordDeliveredState(_ state: CardioActivityAttributes.ContentState, forActivityID activityID: String) {
        lastDeliveredActivityID = activityID
        lastDeliveredState = state
    }

    private static func resetTrackedActivityState() {
        lastDeliveredActivityID = nil
        lastDeliveredState = nil
    }

    private static func endAllActivities() {
        resetTrackedActivityState()
        let cardioActivityIDs = Activity<CardioActivityAttributes>.activities.map(\.id)
        let workoutActivityIDs = Activity<WorkoutActivityAttributes>.activities.map(\.id)
        Task {
            await endCardioActivities(ids: cardioActivityIDs)
            await endWorkoutActivities(ids: workoutActivityIDs)
        }
    }

    nonisolated private static func updateActivity(id: String, state: CardioActivityAttributes.ContentState) async {
        guard let activity = Activity<CardioActivityAttributes>.activities.first(where: { $0.id == id }) else { return }
        await activity.update(.init(state: state, staleDate: nil))
    }

    nonisolated private static func endCardioActivities(ids: [String]) async {
        for id in ids {
            guard let activity = Activity<CardioActivityAttributes>.activities.first(where: { $0.id == id }) else { continue }
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    nonisolated private static func endWorkoutActivities(ids: [String]) async {
        for id in ids {
            guard let activity = Activity<WorkoutActivityAttributes>.activities.first(where: { $0.id == id }) else { continue }
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
