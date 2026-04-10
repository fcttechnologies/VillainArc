import Foundation
import HealthKit
import Observation
import WatchConnectivity

private final class WatchRuntimeReplyHandlerBox: @unchecked Sendable {
    nonisolated(unsafe) let reply: (Data) -> Void

    nonisolated init(_ reply: @escaping (Data) -> Void) {
        self.reply = reply
    }
}

private actor MirroredCommandContinuationStore {
    private var continuations: [UUID: CheckedContinuation<WatchWorkoutCommandResult, Never>] = [:]

    func insert(_ continuation: CheckedContinuation<WatchWorkoutCommandResult, Never>, for commandID: UUID) {
        continuations[commandID] = continuation
    }

    func resume(for commandID: UUID, with result: WatchWorkoutCommandResult) {
        guard let continuation = continuations.removeValue(forKey: commandID) else { return }
        continuation.resume(returning: result)
    }

    func take(for commandID: UUID) -> CheckedContinuation<WatchWorkoutCommandResult, Never>? {
        continuations.removeValue(forKey: commandID)
    }
}

@Observable
final class WatchWorkoutRuntimeCoordinator: NSObject {
    static let shared = WatchWorkoutRuntimeCoordinator()

    private enum HealthMetadataKey {
        static let workoutSessionID = "com.villainarc.workoutsession.id"
        static let workoutTitle = "Workout Title"
    }

    private(set) var activeSnapshot: ActiveWorkoutSnapshot?
    private(set) var latestHeartRate: Double?
    private(set) var activeEnergyBurned: Double?
    private(set) var restingEnergyBurned: Double?
    private(set) var isBusy = false
    private(set) var isPhoneReachable = false
    private(set) var healthAuthorizationState: WatchWorkoutAuthorizationState = .notDetermined
    var statusMessage: String?

    @ObservationIgnored private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil
    @ObservationIgnored private var didActivateConnectivity = false
    @ObservationIgnored private var localWorkoutSession: HKWorkoutSession?
    @ObservationIgnored private var localWorkoutBuilder: HKLiveWorkoutBuilder?
    @ObservationIgnored private let mirroredCommandContinuations = MirroredCommandContinuationStore()
    @ObservationIgnored private var pendingPhoneRequestedWorkoutStart = false

    private override init() {
        healthAuthorizationState = WatchHealthAuthorizationManager.currentAuthorizationState
        super.init()
    }

    var displayHeartRate: Double? {
        latestHeartRate ?? activeSnapshot?.latestHeartRate
    }

    var displayActiveEnergy: Double? {
        activeEnergyBurned ?? activeSnapshot?.activeEnergyBurned
    }

    var displayTotalEnergy: Double? {
        if let activeEnergyBurned, let restingEnergyBurned {
            return activeEnergyBurned + restingEnergyBurned
        }

        if let activeEnergy = activeSnapshot?.activeEnergyBurned, let restingEnergy = activeSnapshot?.restingEnergyBurned {
            return activeEnergy + restingEnergy
        }

        return nil
    }

    func activateIfNeeded() {
        guard let session, !didActivateConnectivity else { return }
        session.delegate = self
        session.activate()
        didActivateConnectivity = true
        isPhoneReachable = session.isReachable
        ingestApplicationContext(session.receivedApplicationContext)
    }

    func sceneDidBecomeActive() async {
        activateIfNeeded()
        healthAuthorizationState = WatchHealthAuthorizationManager.currentAuthorizationState
        await recoverLocalWorkoutIfNeeded()
        await attemptPhoneRequestedAutoStartIfNeeded()
    }

    func handleWorkoutLaunchRequest(_ workoutConfiguration: HKWorkoutConfiguration) async {
        _ = workoutConfiguration
        pendingPhoneRequestedWorkoutStart = true
        activateIfNeeded()
        await attemptPhoneRequestedAutoStartIfNeeded()
    }

    func clearStatusMessage() {
        statusMessage = nil
    }

    func startWorkout(planID: UUID) async {
        guard !isBusy else { return }
        guard activeSnapshot == nil else {
            statusMessage = "A workout is already in progress."
            return
        }
        isBusy = true
        defer { isBusy = false }

        let result = await sendCommand(.startPlannedWorkout(planID: planID), preferMirroredChannel: false)
        await handleCommandResult(result, autoStartMirroring: true)
    }

    func toggleSet(sessionID: UUID, setID: UUID, desiredComplete: Bool) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }

        let result = await sendCommand(
            .toggleSet(sessionID: sessionID, setID: setID, desiredComplete: desiredComplete, commandID: UUID()),
            preferMirroredChannel: activeSnapshot?.healthCollectionMode == .watchMirrored
        )

        await handleCommandResult(result, autoStartMirroring: false)
    }

    func finishWorkout(sessionID: UUID) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }

        let result = await sendCommand(
            .finish(sessionID: sessionID, commandID: UUID()),
            preferMirroredChannel: activeSnapshot?.healthCollectionMode == .watchMirrored
        )

        await handleCommandResult(result, autoStartMirroring: false)
    }

    func cancelWorkout(sessionID: UUID) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }

        let result = await sendCommand(
            .cancel(sessionID: sessionID, commandID: UUID()),
            preferMirroredChannel: activeSnapshot?.healthCollectionMode == .watchMirrored
        )

        await handleCommandResult(result, autoStartMirroring: false)
    }

    func startMirroringForCurrentWorkout() async {
        guard let snapshot = activeSnapshot else { return }
        guard snapshot.status == .active else { return }
        _ = await startMirroring(for: snapshot)
    }

    private func handleCommandResult(_ result: WatchWorkoutCommandResult, autoStartMirroring: Bool) async {
        switch result {
        case .started(let snapshot):
            activeSnapshot = snapshot
            statusMessage = nil
            if autoStartMirroring {
                _ = await startMirroring(for: snapshot)
            }
        case .updated(let snapshot):
            activeSnapshot = snapshot
            statusMessage = nil

            if snapshot.status != .active {
                if localWorkoutSession != nil {
                    await finishLocalWorkoutIfNeeded(endedAt: Date())
                }
                activeSnapshot = nil
                statusMessage = "Finished on iPhone."
            }
        case .finishOnPhone(let reason):
            WatchPhoneHandoffCoordinator.openActiveWorkoutOnPhone()
            statusMessage = reason
        case .blocked(let reason), .failed(let reason):
            statusMessage = reason
        case .cancelled:
            await discardLocalWorkoutIfNeeded()
            activeSnapshot = nil
            statusMessage = "Workout cancelled."
        }
    }

    private func sendCommand(_ command: WatchWorkoutCommand, preferMirroredChannel: Bool) async -> WatchWorkoutCommandResult {
        if preferMirroredChannel, let mirroredResult = await sendCommandOverMirroredSession(command) {
            return mirroredResult
        }

        return await sendCommandOverWatchConnectivity(command)
    }

    private func sendCommandOverWatchConnectivity(_ command: WatchWorkoutCommand) async -> WatchWorkoutCommandResult {
        guard let session else {
            return .failed(reason: "Watch connectivity is unavailable.")
        }

        guard session.activationState == .activated, session.isReachable else {
            return .failed(reason: "Open Villain Arc on iPhone to continue.")
        }

        do {
            let encoded = try JSONEncoder().encode(command)

            return await withCheckedContinuation { continuation in
                session.sendMessageData(encoded) { replyData in
                    let result = (try? JSONDecoder().decode(WatchWorkoutCommandResult.self, from: replyData))
                        ?? .failed(reason: "Received an invalid response from iPhone.")
                    continuation.resume(returning: result)
                } errorHandler: { error in
                    continuation.resume(returning: .failed(reason: self.failureMessage(for: error)))
                }
            }
        } catch {
            return .failed(reason: "Unable to encode the watch command.")
        }
    }

    private func sendCommandOverMirroredSession(_ command: WatchWorkoutCommand) async -> WatchWorkoutCommandResult? {
        guard let localWorkoutSession, let commandID = command.commandID else { return nil }

        do {
            let encoded = try JSONEncoder().encode(MirroredWorkoutRemoteMessage.command(command))

            return await withCheckedContinuation { continuation in
                Task {
                    await mirroredCommandContinuations.insert(continuation, for: commandID)

                    do {
                        try await localWorkoutSession.sendToRemoteWorkoutSession(data: encoded)
                    } catch {
                        if let pending = await mirroredCommandContinuations.take(for: commandID) {
                            pending.resume(returning: .failed(reason: self.failureMessage(for: error)))
                        }
                    }
                }

                Task {
                    try? await Task.sleep(for: .seconds(10))
                    if let pending = await mirroredCommandContinuations.take(for: commandID) {
                        pending.resume(returning: .failed(reason: "iPhone did not respond in time."))
                    }
                }
            }
        } catch {
            return .failed(reason: "Unable to encode the mirrored workout command.")
        }
    }

    private func ingestApplicationContext(_ applicationContext: [String: Any]) {
        guard let data = applicationContext["watchRuntime"] as? Data else { return }
        ingestRuntimeContextData(data)
    }

    private func ingestRuntimeContextData(_ data: Data) {
        guard let context = try? JSONDecoder().decode(WatchRuntimeApplicationContext.self, from: data) else { return }
        activeSnapshot = context.activeSnapshot
        Task { @MainActor in
            await self.attemptPhoneRequestedAutoStartIfNeeded()
        }
    }

    private func processRuntimeEvent(_ event: PhoneToWatchRuntimeEvent) async {
        switch event {
        case .snapshot(let snapshot):
            activeSnapshot = snapshot
            if snapshot.healthCollectionMode == .watchMirrored, localWorkoutSession == nil {
                await recoverLocalWorkoutIfNeeded()
            }
        case .clearActiveWorkout:
            activeSnapshot = nil
        case .finishMirroredSession(let sessionID, let endedAt):
            guard matchesActiveSession(sessionID) else { return }
            await finishLocalWorkoutIfNeeded(endedAt: endedAt)
            activeSnapshot = nil
            statusMessage = "Workout finished on iPhone."
        case .discardMirroredSession(let sessionID):
            guard matchesActiveSession(sessionID) else { return }
            await discardLocalWorkoutIfNeeded()
            activeSnapshot = nil
            statusMessage = "Workout cancelled on iPhone."
        }
    }

    private func processMirroredMessage(_ message: MirroredWorkoutRemoteMessage) async {
        switch message {
        case .snapshot(let snapshot):
            activeSnapshot = snapshot
        case .commandResult(let commandID, let result):
            await mirroredCommandContinuations.resume(for: commandID, with: result)
        case .finishMirroredSession(let sessionID, let endedAt):
            guard matchesActiveSession(sessionID) else { return }
            await finishLocalWorkoutIfNeeded(endedAt: endedAt)
            activeSnapshot = nil
            statusMessage = "Workout finished on iPhone."
        case .discardMirroredSession(let sessionID):
            guard matchesActiveSession(sessionID) else { return }
            await discardLocalWorkoutIfNeeded()
            activeSnapshot = nil
            statusMessage = "Workout cancelled on iPhone."
        case .command:
            break
        }
    }

    private func attemptPhoneRequestedAutoStartIfNeeded() async {
        guard pendingPhoneRequestedWorkoutStart else { return }
        guard localWorkoutSession == nil else {
            pendingPhoneRequestedWorkoutStart = false
            return
        }
        guard let snapshot = activeSnapshot, snapshot.status == .active else { return }

        let didStart = await startMirroring(for: snapshot)
        if didStart || healthAuthorizationState == .denied || healthAuthorizationState == .unavailable {
            pendingPhoneRequestedWorkoutStart = false
        }
    }

    private func startMirroring(for snapshot: ActiveWorkoutSnapshot) async -> Bool {
        guard snapshot.status == .active else { return false }
        guard localWorkoutSession == nil else {
            return await confirmMirroring(for: snapshot)
        }

        healthAuthorizationState = await WatchHealthAuthorizationManager.requestAuthorizationIfNeeded()
        guard healthAuthorizationState == .authorized else {
            statusMessage = healthAuthorizationState.statusMessage
            return false
        }

        do {
            let configuration = HKWorkoutConfiguration()
            configuration.activityType = .traditionalStrengthTraining
            configuration.locationType = .indoor

            let workoutSession = try HKWorkoutSession(
                healthStore: WatchHealthAuthorizationManager.healthStore,
                configuration: configuration
            )
            let workoutBuilder = workoutSession.associatedWorkoutBuilder()
            workoutBuilder.delegate = self
            workoutSession.delegate = self
            workoutBuilder.dataSource = HKLiveWorkoutDataSource(
                healthStore: WatchHealthAuthorizationManager.healthStore,
                workoutConfiguration: configuration
            )

            localWorkoutSession = workoutSession
            localWorkoutBuilder = workoutBuilder
            resetLocalMetrics()

            workoutSession.startActivity(with: snapshot.startedAt)
            try await workoutBuilder.beginCollection(at: snapshot.startedAt)
            try await workoutBuilder.addMetadata([
                HealthMetadataKey.workoutSessionID: snapshot.sessionID.uuidString,
                HealthMetadataKey.workoutTitle: snapshot.title,
                HKMetadataKeyIndoorWorkout: true
            ])
            try await workoutSession.startMirroringToCompanionDevice()

            return await confirmMirroring(for: snapshot)
        } catch {
            await discardLocalWorkoutIfNeeded()
            statusMessage = "Unable to start live metrics on Apple Watch."
            print("Failed to start mirrored workout session on watch: \(error)")
            return false
        }
    }

    private func confirmMirroring(for snapshot: ActiveWorkoutSnapshot) async -> Bool {
        let result = await sendCommandOverWatchConnectivity(
            .activateMirroring(sessionID: snapshot.sessionID, commandID: UUID())
        )

        switch result {
        case .updated(let updatedSnapshot), .started(let updatedSnapshot):
            activeSnapshot = updatedSnapshot
            statusMessage = "Live metrics started."
            return true
        case .failed(let reason), .blocked(let reason), .finishOnPhone(let reason):
            await discardLocalWorkoutIfNeeded()
            statusMessage = reason
            return false
        case .cancelled:
            await discardLocalWorkoutIfNeeded()
            activeSnapshot = nil
            statusMessage = "Workout cancelled."
            return false
        }
    }

    private func recoverLocalWorkoutIfNeeded() async {
        guard localWorkoutSession == nil else { return }

        do {
            guard let recoveredSession = try await WatchHealthAuthorizationManager.healthStore.recoverActiveWorkoutSession() else {
                return
            }

            let recoveredBuilder = recoveredSession.associatedWorkoutBuilder()
            recoveredSession.delegate = self
            recoveredBuilder.delegate = self
            localWorkoutSession = recoveredSession
            localWorkoutBuilder = recoveredBuilder
            refreshLocalMetrics(from: recoveredBuilder, collectedTypes: [
                HealthKitCatalog.heartRateType,
                HealthKitCatalog.activeEnergyBurnedType,
                HealthKitCatalog.restingEnergyBurnedType
            ])
        } catch {
            print("Failed to recover active watch workout session: \(error)")
        }
    }

    private func finishLocalWorkoutIfNeeded(endedAt: Date) async {
        guard let localWorkoutSession, let localWorkoutBuilder else { return }

        let endDate = max(endedAt, activeSnapshot?.startedAt ?? endedAt)

        do {
            if localWorkoutSession.state != .ended && localWorkoutSession.state != .stopped {
                localWorkoutSession.stopActivity(with: endDate)
            }
            if localWorkoutSession.state != .ended {
                localWorkoutSession.end()
            }
            try await localWorkoutBuilder.endCollection(at: endDate)
            _ = try await localWorkoutBuilder.finishWorkout()
        } catch {
            print("Failed to finish local watch workout session: \(error)")
        }
        clearLocalWorkoutState()
    }

    private func discardLocalWorkoutIfNeeded() async {
        if let localWorkoutSession, localWorkoutSession.state != .ended {
            localWorkoutSession.end()
        }
        localWorkoutBuilder?.discardWorkout()
        clearLocalWorkoutState()
    }

    private func clearLocalWorkoutState() {
        localWorkoutSession = nil
        localWorkoutBuilder = nil
        resetLocalMetrics()
    }

    private func resetLocalMetrics() {
        latestHeartRate = nil
        activeEnergyBurned = nil
        restingEnergyBurned = nil
    }

    private func refreshLocalMetrics(from workoutBuilder: HKLiveWorkoutBuilder, collectedTypes: Set<HKSampleType>) {
        if collectedTypes.contains(HealthKitCatalog.heartRateType) {
            latestHeartRate = workoutBuilder.statistics(for: HealthKitCatalog.heartRateType)?
                .mostRecentQuantity()?
                .doubleValue(for: HealthKitCatalog.bpmUnit)
        }

        if collectedTypes.contains(HealthKitCatalog.activeEnergyBurnedType) {
            activeEnergyBurned = workoutBuilder.statistics(for: HealthKitCatalog.activeEnergyBurnedType)?
                .sumQuantity()?
                .doubleValue(for: HealthKitCatalog.kilocalorieUnit)
        }

        if collectedTypes.contains(HealthKitCatalog.restingEnergyBurnedType) {
            restingEnergyBurned = workoutBuilder.statistics(for: HealthKitCatalog.restingEnergyBurnedType)?
                .sumQuantity()?
                .doubleValue(for: HealthKitCatalog.kilocalorieUnit)
        }
    }

    private func matchesActiveSession(_ sessionID: UUID) -> Bool {
        activeSnapshot?.sessionID == sessionID || localSessionID() == sessionID
    }

    private func localSessionID() -> UUID? {
        guard let rawValue = localWorkoutBuilder?.metadata[HealthMetadataKey.workoutSessionID] as? String else {
            return nil
        }

        return UUID(uuidString: rawValue)
    }

    private func failureMessage(for error: any Error) -> String {
        let nsError = error as NSError
        if nsError.domain == WCErrorDomain {
            return "Open Villain Arc on iPhone to continue."
        }
        return nsError.localizedDescription
    }

    private func encodedReply(for requestData: Data) async -> Data? {
        let result: WatchWorkoutCommandResult

        do {
            let request = try JSONDecoder().decode(PhoneToWatchControlRequest.self, from: requestData)

            switch request {
            case .startMirroring(let snapshot):
                pendingPhoneRequestedWorkoutStart = true
                activeSnapshot = snapshot
                if await startMirroring(for: snapshot) {
                    pendingPhoneRequestedWorkoutStart = false
                    result = .updated(activeSnapshot ?? snapshot)
                } else {
                    result = .failed(reason: statusMessage ?? "Unable to start live metrics on Apple Watch.")
                }
            }
        } catch {
            result = .failed(reason: "Invalid request from iPhone.")
        }

        return try? JSONEncoder().encode(result)
    }
}

extension WatchWorkoutRuntimeCoordinator: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        let isReachable = session.isReachable
        let runtimeData = session.receivedApplicationContext["watchRuntime"] as? Data
        Task { @MainActor in
            self.isPhoneReachable = isReachable
            if let runtimeData {
                self.ingestRuntimeContextData(runtimeData)
            }
            if let error {
                print("Watch WCSession activation failed: \(error)")
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let isReachable = session.isReachable
        Task { @MainActor in
            self.isPhoneReachable = isReachable
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let runtimeData = applicationContext["watchRuntime"] as? Data
        Task { @MainActor in
            if let runtimeData {
                self.ingestRuntimeContextData(runtimeData)
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        Task { @MainActor in
            guard let event = try? JSONDecoder().decode(PhoneToWatchRuntimeEvent.self, from: messageData) else { return }
            await self.processRuntimeEvent(event)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessageData messageData: Data, replyHandler: @escaping (Data) -> Void) {
        let replyBox = WatchRuntimeReplyHandlerBox(replyHandler)
        Task { @MainActor in
            if let reply = await self.encodedReply(for: messageData) {
                replyBox.reply(reply)
            }
        }
    }
}

extension WatchWorkoutRuntimeCoordinator: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor in
            if toState == .ended {
                self.clearLocalWorkoutState()
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: any Error) {
        Task { @MainActor in
            print("Watch mirrored workout session failed: \(error)")
            self.clearLocalWorkoutState()
            self.statusMessage = "Live metrics stopped on Apple Watch."
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didReceiveDataFromRemoteWorkoutSession data: [Data]) {
        Task { @MainActor in
            for payload in data {
                guard let message = try? JSONDecoder().decode(MirroredWorkoutRemoteMessage.self, from: payload) else { continue }
                await self.processMirroredMessage(message)
            }
        }
    }
}

extension WatchWorkoutRuntimeCoordinator: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        Task { @MainActor in
            self.refreshLocalMetrics(from: workoutBuilder, collectedTypes: collectedTypes)
        }
    }
}
