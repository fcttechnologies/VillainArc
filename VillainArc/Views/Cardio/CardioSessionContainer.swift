import FCTMetrics
import Combine
import CoreLocation
import MapKit
import SwiftData
import SwiftUI
import UIKit

struct CardioSessionContainer: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var session: CardioSession

    var body: some View {
        Group {
            switch session.statusValue {
            case .active:
                CardioActiveSessionView(session: session)
                    .transition(.sessionAdvance(reduceMotion: reduceMotion))
            case .done:
                NavigationStack {
                    if !session.usesRoute, let workout = session.healthWorkout {
                        HealthWorkoutDetailView(workout: workout, showsCloseButton: true, cardioSession: session)
                    } else {
                        CardioSessionDetailView(session: session, showsCloseButton: true)
                    }
                }
                .transition(.sessionAdvance(reduceMotion: reduceMotion))
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: session.statusValue)
    }
}

struct CardioActiveSessionView: View {
    @Bindable var session: CardioSession

    @Environment(\.modelContext) private var context
    @Query(AppSettings.single) private var appSettings: [AppSettings]
    @State private var router = AppRouter.shared
    @State private var routeRecorder = CardioRouteRecorder.shared
    @State private var healthCoordinator = CardioHealthWorkoutCoordinator.shared
    @State private var speedKPH = 8.0
    @State private var speedText = "8.0"
    @State private var inclinePercent = 0.0
    @State private var inclineText = "0.0"
    @State private var liveTreadmillDistance: Double = 0
    @FocusState private var speedFocused: Bool
    @FocusState private var inclineFocused: Bool
    private let liveTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var showCancelConfirmation = false
    @State private var showFinishConfirmation = false
    @State private var showDeleteOnlyIntervalAlert = false
    @State private var showEffortPrompt = false
    @State private var pendingEffort = 0
    @State private var countdownValue: Int? = nil

    private var distanceUnit: DistanceUnit { appSettings.first?.distanceUnit ?? .systemDefault }
    private var energyUnit: EnergyUnit { appSettings.first?.energyUnit ?? .systemDefault }
    private var speedUnit: SpeedUnit { appSettings.first?.speedUnit ?? .systemDefault }
    private var shouldPromptForPostWorkoutEffort: Bool { appSettings.first?.promptForPostWorkoutEffort ?? false }

    private var isActiveHealthSession: Bool { healthCoordinator.activeCardioSessionID == session.id }

    // One distance source per capture mode (the pace-bug fix): the grid, the Live Activity, and the
    // finished detail all read this same value so their pace never disagrees.
    private var liveSessionDistance: Double {
        session.resolvedDistanceMeters(healthKitDistance: isActiveHealthSession ? healthCoordinator.distanceMeters : nil)
    }

    // A machineIntervals session can't be saved with no distance (no intervals logged). healthKitOnly
    // is exempt — HealthKit provides the distance even with nothing logged in-app.
    private var canFinish: Bool {
        guard session.usesMachineIntervals else { return true }
        return session.startedAt != nil && !session.sortedMachineIntervals.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // The active view is shaped by the capture mode: gpsRoute → live route map;
                    // machineIntervals → interval entry; healthKitOnly → live metrics only.
                    if session.usesRoute {
                        CardioRouteMapView(sessions: [session], showsUserLocation: true, showsUserLocationButton: false, defaultsToUserLocation: true)
                            .frame(height: 380)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        CardioMetricGrid(session: session, distanceUnit: distanceUnit, energyUnit: energyUnit, liveHeartRate: isActiveHealthSession ? healthCoordinator.latestHeartRate : nil, liveEnergy: isActiveHealthSession ? healthCoordinator.activeEnergyBurned : nil, liveDistance: liveSessionDistance)

                        if shouldShowHealthAccessCard {
                            healthAccessCard
                        }

                        // machineIntervals sessions log distance through manual intervals, whether or
                        // not Apple Health is connected. Health (when available) layers on heart rate
                        // and energy; it does not replace the interval entry, which is the only way a
                        // treadmill session starts.
                        if session.usesMachineIntervals {
                            treadmillIntervalSection
                        }
                    }
                    .padding()
                }
                .simultaneousGesture(TapGesture().onEnded { dismissKeyboard() })
            }
            .scrollDismissesKeyboard(.interactively)
            .appBackground()
            .navigationTitle(session.displayTitle)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", systemImage: "xmark", role: .cancel) {
                        showCancelConfirmation = true
                    }
                    .confirmationDialog("Cancel cardio session?", isPresented: $showCancelConfirmation, titleVisibility: .visible) {
                        Button("Cancel Cardio Session", role: .destructive) { router.cancelCardioSession(session) }
                        Button("Keep Going", role: .cancel) {}
                    } message: {
                        Text("This deletes the active cardio session and stops route and Health recording.")
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.cardioActiveCancel)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Finish", systemImage: "checkmark", role: .confirm) {
                        handleFinishTapped()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canFinish)
                    .confirmationDialog("Finish cardio session?", isPresented: $showFinishConfirmation, titleVisibility: .visible) {
                        Button("Finish Cardio Session", role: .confirm) { finishSession() }
                        Button("Keep Going", role: .cancel) {}
                    } message: {
                        Text("Villain Arc will save the cardio session and any Health metrics or route data captured so far.")
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.cardioActiveFinish)
                }
            }
            .task {
                await startWithCountdown()
            }
            .onAppear {
                speedText = fixedOneDecimal(speedUnit.fromKPH(speedKPH))
                inclineText = fixedOneDecimal(inclinePercent)
            }
            .onChange(of: speedFocused) { _, focused in
                if !focused { commitSpeedText() }
            }
            .onChange(of: inclineFocused) { _, focused in
                if !focused { commitInclineText() }
            }
            .onReceive(liveTimer) { _ in
                guard session.usesMachineIntervals, session.startedAt != nil else { return }
                updateLiveTreadmillDistance()
                // Keep the Live Activity's interval distance/pace growing in step with the in-app
                // grid so the two never disagree (the contentState reads the same live source).
                CardioActivityManager.update(for: session)
            }
            .sheet(isPresented: $showEffortPrompt) {
                WorkoutEffortPromptView(
                    selectedEffort: $pendingEffort,
                    onClose: { showEffortPrompt = false },
                    onSkip: {
                        showEffortPrompt = false
                        finishSession()
                    },
                    onConfirm: {
                        Diag.breadcrumb(VACrumb.effortRecorded)
                        session.postEffort = pendingEffort
                        showEffortPrompt = false
                        finishSession()
                    }
                )
            }
        }
        .overlay {
            if let count = countdownValue {
                CardioCountdownOverlay(value: count, type: CardioSessionType(activity: session.activity, environment: session.environment))
            }
        }
        // Soft scroll-edge fade for this separate presentation context — ContentView's root
        // modifier doesn't reach full-screen covers. Inert on the iOS 26 SDK (see ContentView).
        .scrollEdgeEffectStyle(.soft, for: .all)
        .diagScreen(VACrumb.cardioSession)
    }

    private var shouldShowHealthAccessCard: Bool {
        guard HealthAuthorizationManager.isHealthDataAvailable else { return false }
        return !HealthAuthorizationManager.canWriteWorkouts
            || !HealthAuthorizationManager.canWriteActiveEnergyBurned
            || !HealthAuthorizationManager.canWriteWalkingRunningDistance
    }

    private var healthAccessCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Apple Health Metrics", systemImage: "heart.text.square")
                .font(.headline)
            Text("Connect Apple Health to capture live heart rate, energy, and Health workout records when your device supports it.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                openHealthSettings()
            } label: {
                Label("Connect Apple Health", systemImage: "heart.text.square")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .accessibilityIdentifier(AccessibilityIdentifiers.cardioConnectAppleHealthButton)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .appSurfaceStyle(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// Apple Health write access can't be re-requested in-app once the user has answered the system
    /// prompt, so when access is missing we send them to Settings → the app's Health section to
    /// grant it manually.
    private func openHealthSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private var treadmillIntervalSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Treadmill Intervals", systemImage: "speedometer")
                    .font(.title3.bold())
                Spacer()
                Text("\(session.sortedMachineIntervals.count)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 4) {
                        Text("Speed")
                        Text("(\(speedUnit.unitLabel))")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                    Spacer()
                    TextField("0.0", text: $speedText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($speedFocused)
                        .frame(width: 70)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .foregroundStyle(speedFocused ? Color.primary : Color.blue)
                        .accessibilityIdentifier(AccessibilityIdentifiers.cardioTreadmillSpeedField)
                }
                .padding(.vertical, 12)
                .appGroupedStackRow(position: .top)

                HStack {
                    HStack(spacing: 4) {
                        Text("Incline")
                        Text("(%)")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                    Spacer()
                    TextField("0.0", text: $inclineText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($inclineFocused)
                        .frame(width: 70)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .foregroundStyle(inclineFocused ? Color.primary : Color.blue)
                        .accessibilityIdentifier(AccessibilityIdentifiers.cardioTreadmillInclineField)
                }
                .padding(.vertical, 12)
                .appGroupedStackRow(position: .bottom)
            }

            Button {
                addTreadmillInterval()
            } label: {
                Label("Add Interval", systemImage: "plus")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .padding(.vertical, 5)
            }
            .tint(.blue)
            .buttonStyle(.glass)
            .buttonSizing(.flexible)
            .accessibilityIdentifier(AccessibilityIdentifiers.cardioTreadmillIntervalAdd)

            if !displayedIntervals.isEmpty {
                List {
                    ForEach(displayedIntervals) { interval in
                        CardioMachineIntervalRow(
                            interval: interval,
                            timingText: intervalTimingText(for: interval),
                            isActive: isActiveInterval(interval),
                            distanceUnit: distanceUnit,
                            speedUnit: speedUnit
                        )
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            // Only the most recent (active) interval can be removed; older ones are
                            // locked in once a newer interval starts.
                            if isActiveInterval(interval) {
                                Button(role: .destructive) {
                                    requestDeleteLatestInterval()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .accessibilityIdentifier(AccessibilityIdentifiers.cardioTreadmillIntervalDeleteButton)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)
                .frame(height: CGFloat(displayedIntervals.count) * 72)
            }
        }
        .alert("Cancel Cardio Session?", isPresented: $showDeleteOnlyIntervalAlert) {
            Button("Cancel Session", role: .destructive) { router.cancelCardioSession(session) }
                .accessibilityIdentifier(AccessibilityIdentifiers.cardioCancelSessionConfirmButton)
            Button("Keep Going", role: .cancel) {}
                .accessibilityIdentifier(AccessibilityIdentifiers.cardioCancelSessionKeepGoingButton)
        } message: {
            Text("Deleting your only interval will cancel this cardio session.")
        }
    }

    /// Newest interval first. The newest interval is the "active" one — it's still accumulating time
    /// and distance until the next interval is added or the session finishes.
    private var displayedIntervals: [CardioMachineInterval] {
        session.sortedMachineIntervals.reversed()
    }

    private func isActiveInterval(_ interval: CardioMachineInterval) -> Bool {
        interval.id == session.sortedMachineIntervals.last?.id
    }

    /// The active interval shows its live elapsed time; older intervals show the fixed window they
    /// occupied, expressed relative to the running workout clock (e.g. "2:00 – 5:30").
    private func intervalTimingText(for interval: CardioMachineInterval) -> String {
        if isActiveInterval(interval) {
            return secondsToTime(Int(session.intervalDuration(for: interval).rounded()))
        }
        guard let start = session.startedAt else {
            return secondsToTime(Int(session.intervalDuration(for: interval).rounded()))
        }
        let intervals = session.sortedMachineIntervals
        guard let index = intervals.firstIndex(where: { $0.id == interval.id }) else { return "" }
        let from = max(0, interval.addedAt.timeIntervalSince(start))
        let to = index + 1 < intervals.count ? max(0, intervals[index + 1].addedAt.timeIntervalSince(start)) : from
        return "\(secondsToTime(Int(from.rounded()))) – \(secondsToTime(Int(to.rounded())))"
    }

    private func requestDeleteLatestInterval() {
        guard let latest = session.sortedMachineIntervals.last else { return }
        if session.sortedMachineIntervals.count == 1 {
            showDeleteOnlyIntervalAlert = true
        } else {
            deleteTreadmillInterval(latest)
        }
    }

    private func commitSpeedText() {
        if let val = Double(speedText), val > 0 {
            let rounded = speedUnit.clampedTreadmillInput(val)
            speedKPH = speedUnit.toKPH(rounded)
        }
        speedText = fixedOneDecimal(speedUnit.fromKPH(speedKPH))
    }

    private func commitInclineText() {
        if let val = Double(inclineText), val >= 0 {
            let rounded = (min(15.0, max(0, val)) * 2).rounded() / 2
            inclinePercent = rounded
        }
        inclineText = fixedOneDecimal(inclinePercent)
    }

    private func addTreadmillInterval() {
        // Flush any value still being typed before reading it: the speed/incline fields only commit
        // on focus loss, so tapping "Add Interval" while a field is focused would otherwise log the
        // stale @State speed (e.g. the 8.0 km/h default = 5 mph = a 12 min/mile "run") instead of
        // the value shown on screen. This guarantees what the user sees is what gets logged.
        commitSpeedText()
        commitInclineText()
        let count = (session.machineIntervals ?? []).count
        if count == 0 {
            session.startedAt = .now
            saveContext(context: context)
            CardioActivityManager.start(session: session)
            Task { await healthCoordinator.beginActiveCollection(for: session) }
        }
        let addedAt: Date = count == 0 ? (session.startedAt ?? .now) : .now
        Diag.breadcrumb(VACrumb.cardioIntervalAdded)
        let interval = CardioMachineInterval(index: count, speedKPH: speedKPH, inclinePercent: inclinePercent, addedAt: addedAt, session: session)
        context.insert(interval)
        session.machineIntervals?.append(interval)
        session.recalculateMachineDistance()
        updateLiveTreadmillDistance()
        saveContext(context: context)
        CardioActivityManager.update(for: session)
    }

    private func updateLiveTreadmillDistance() {
        let intervals = session.sortedMachineIntervals
        guard !intervals.isEmpty else { liveTreadmillDistance = 0; return }
        let now = Date.now
        var total = 0.0
        for (i, interval) in intervals.enumerated() {
            let nextStart = i + 1 < intervals.count ? intervals[i + 1].addedAt : now
            let dur = max(0, nextStart.timeIntervalSince(interval.addedAt))
            total += ((interval.speedKPH ?? 0) / 3.6) * dur
        }
        liveTreadmillDistance = total
    }

    private func deleteTreadmillInterval(_ interval: CardioMachineInterval) {
        session.machineIntervals?.removeAll { $0.id == interval.id }
        context.delete(interval)
        for (index, interval) in session.sortedMachineIntervals.enumerated() {
            interval.index = index
        }
        session.recalculateMachineDistance()
        saveContext(context: context)
        CardioActivityManager.update(for: session)
    }

    private func startWithCountdown() async {
        // Already started — returning from background, an app relaunch (e.g. a
        // TestFlight update mid-session), or a resume-bar tap. Re-attach the live
        // HealthKit workout builder so heart-rate/energy collection resumes:
        // ensureRunning() first recovers the still-active HKWorkoutSession from
        // HealthKit and falls back to restarting collection at the original start.
        // Without this the coordinator stops tracking the session and every live
        // metric (Live Activity + in-app grid) reads nil after a relaunch.
        if session.startedAt != nil {
            CardioActivityManager.restoreIfNeeded(session: session)
            await healthCoordinator.ensureRunning(for: session)
            if session.usesRoute {
                routeRecorder.startRecording(session: session, context: context)
            }
            return
        }

        // machineIntervals: no countdown — the session doesn't start until the first interval is added
        if session.usesMachineIntervals {
            Task { await healthCoordinator.prepareForSession(session) }
            return
        }

        // gpsRoute / healthKitOnly: warm up sensors, show the 3-2-1 countdown, then start. Only a
        // gpsRoute session records a GPS route; healthKitOnly relies entirely on the live HealthKit
        // workout builder for distance, heart rate, and energy.
        Task { await healthCoordinator.prepareForSession(session) }
        for i in stride(from: 3, through: 1, by: -1) {
            await MainActor.run { countdownValue = i }
            do {
                try await Task.sleep(nanoseconds: 1_000_000_000)
            } catch {
                // The hosting `.task` was cancelled (view dismissed mid-countdown).
                // Swallowing this used to rush through the countdown and start the
                // session — Live Activity, HealthKit collection and all — on a view
                // that was already gone. Abort instead; the session never started.
                await MainActor.run { countdownValue = nil }
                return
            }
        }
        await MainActor.run { countdownValue = nil }
        guard !Task.isCancelled else { return }

        session.startedAt = .now
        saveContext(context: context)
        CardioActivityManager.start(session: session)
        if session.usesRoute {
            routeRecorder.startRecording(session: session, context: context)
        }
        await healthCoordinator.beginActiveCollection(for: session)
    }

    private func handleFinishTapped() {
        // Mirror the strength flow: when effort prompting is on, the effort dial's
        // Finish button is the confirmation (skip → finish without a score); otherwise
        // fall back to the finish confirmation dialog.
        if shouldPromptForPostWorkoutEffort {
            pendingEffort = 0
            showEffortPrompt = true
        } else {
            showFinishConfirmation = true
        }
    }

    private func finishSession() {
        router.finishCardioSession(session)
    }
}

struct CardioRouteMapView: View {
    let sessions: [CardioSession]
    let showsUserLocation: Bool
    var showsUserLocationButton: Bool = true
    var defaultsToUserLocation: Bool = false
    @State private var position: MapCameraPosition = .automatic

    init(sessions: [CardioSession], showsUserLocation: Bool, showsUserLocationButton: Bool = true, defaultsToUserLocation: Bool = false) {
        self.sessions = sessions
        self.showsUserLocation = showsUserLocation
        self.showsUserLocationButton = showsUserLocationButton
        self.defaultsToUserLocation = defaultsToUserLocation
        _position = State(initialValue: defaultsToUserLocation ? .userLocation(fallback: .automatic) : .automatic)
    }

    private var routeSessions: [CardioSession] {
        sessions.filter { $0.sortedRoutePoints.count > 1 }
    }

    var body: some View {
        Map(position: $position) {
            if showsUserLocation {
                UserAnnotation()
            }
            ForEach(routeSessions) { session in
                MapPolyline(coordinates: session.sortedRoutePoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) })
                    .stroke(session.statusValue == .active ? .green : .blue, lineWidth: session.statusValue == .active ? 5 : 3)
            }
        }
        .mapControls {
            if showsUserLocationButton {
                MapUserLocationButton()
            }
            MapCompass()
        }
        .mapControlVisibility(showsUserLocationButton ? .visible : .hidden)
        .overlay {
            if routeSessions.isEmpty {
                ContentUnavailableView("No Route Yet", systemImage: "map", description: Text(showsUserLocation ? "Location points will appear here as the session records." : "This session does not have saved route points."))
                    .padding()
            }
        }
    }
}

private struct CardioMetricGrid: View {
    let session: CardioSession
    let distanceUnit: DistanceUnit
    let energyUnit: EnergyUnit
    var liveHeartRate: Double? = nil
    var liveEnergy: Double? = nil
    var liveDistance: Double? = nil

    private var heartRate: Double? { liveHeartRate ?? session.healthWorkout?.averageHeartRateBPM }
    private var energy: Double? { liveEnergy ?? session.healthWorkout?.activeEnergyBurned }
    private var displayDistance: Double { liveDistance ?? session.totalDistanceMeters }

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricTile(title: "Time", value: session.statusValue == .active ? "" : secondsToTimeWithHours(Int(session.duration.rounded())), systemImage: "timer") {
                if session.statusValue == .active {
                    if let startedAt = session.startedAt {
                        Text(startedAt, style: .timer)
                            .monospacedDigit()
                    } else {
                        Text("0:00")
                            .monospacedDigit()
                    }
                }
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.cardioMetricTile("Time"))
            MetricTile(title: "Distance", value: formattedDistanceText(displayDistance, unit: distanceUnit), systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                .accessibilityIdentifier(AccessibilityIdentifiers.cardioMetricTile("Distance"))
            MetricTile(title: "Pace", value: formattedPaceText(duration: session.duration, distanceMeters: displayDistance, distanceUnit: distanceUnit) ?? "-", systemImage: "speedometer")
                .accessibilityIdentifier(AccessibilityIdentifiers.cardioMetricTile("Pace"))
            MetricTile(title: "Heart", value: heartRate.map { formattedHeartRateText($0) } ?? "-", systemImage: "heart.fill")
                .accessibilityIdentifier(AccessibilityIdentifiers.cardioMetricTile("Heart"))
            MetricTile(title: "Energy", value: energy.map { formattedEnergyText($0, unit: energyUnit) } ?? "-", systemImage: "flame.fill")
                .accessibilityIdentifier(AccessibilityIdentifiers.cardioMetricTile("Energy"))
            MetricTile(title: "Source", value: sourceText, systemImage: "waveform.path.ecg")
                .accessibilityIdentifier(AccessibilityIdentifiers.cardioMetricTile("Source"))
        }
    }

    private var sourceText: String {
        switch session.source {
        case .location: return "Location"
        case .manual: return "Manual"
        case .appleHealth: return "Health"
        }
    }
}

private struct CardioMachineIntervalRow: View {
    let interval: CardioMachineInterval
    let timingText: String
    let isActive: Bool
    let distanceUnit: DistanceUnit
    let speedUnit: SpeedUnit

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(speedUnit.display(interval.speedKPH ?? 0))
                        .font(.headline)
                    if isActive {
                        Text("Active")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.green)
                    }
                }
                Text("\(timingText) · \((interval.inclinePercent ?? 0).formatted(.number.precision(.fractionLength(0...1))))% incline")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(formattedDistanceText(interval.distanceMeters, unit: distanceUnit))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct CardioCountdownOverlay: View {
    let value: Int
    let type: CardioSessionType

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Get Ready")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)

                // Deliberately fixed: 120 points is already larger than any accessibility size
                // asks for, and scaling a single digit from there runs it past the width of the
                // narrowest phone the app ships to.
                Text("\(value)")
                    .font(.system(size: 120, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.easeInOut(duration: 0.3), value: value)

                Label(type.title, systemImage: type.systemImage)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .transition(.opacity)
    }
}
