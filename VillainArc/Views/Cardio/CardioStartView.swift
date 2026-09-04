import FCTMetrics
import CoreLocation
import SwiftUI
import UIKit

/// The start screen for a cardio session. It lets the user choose how the session is recorded —
/// **Manual** (an app-tracked GPS route outdoors, or hand-logged machine intervals indoors) vs
/// **Apple Health** (the live HealthKit workout records everything, so nothing needs to be logged in
/// app) — and surfaces the permissions that choice needs. Apple Health is offered as a capture mode
/// only when workout write access is granted, and is the recommended default when available.
struct CardioStartView: View {
    let type: CardioSessionType
    /// Called with the chosen capture mode when the user taps Start.
    let onStart: (CardioCaptureMode) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var routeRecorder = CardioRouteRecorder.shared
    @State private var selectedMode: CardioCaptureMode
    // Bumped after an Apple Health auth request so the view re-reads the (non-observable) static
    // HealthKit authorization status — that's how the Apple Health capture option appears once the
    // user grants access from this screen.
    @State private var healthAuthToken = 0

    init(type: CardioSessionType, onStart: @escaping (CardioCaptureMode) -> Void) {
        self.type = type
        self.onStart = onStart
        let manual: CardioCaptureMode = type.isOutdoor ? .gpsRoute : .machineIntervals
        _selectedMode = State(initialValue: HealthAuthorizationManager.canWriteWorkouts ? .healthKitOnly : manual)
    }

    // The app-managed capture mode for this type: a GPS route outdoors, machine intervals indoors.
    private var manualMode: CardioCaptureMode { type.isOutdoor ? .gpsRoute : .machineIntervals }

    // Apple Health is offered as a capture mode only when workout write access is already granted.
    private var appleHealthOffered: Bool {
        _ = healthAuthToken
        return HealthAuthorizationManager.canWriteWorkouts
    }

    // While Health exists on the device but workout write isn't granted yet, offer an optional
    // connect row: it both layers heart rate/energy onto a manual session and, once granted, reveals
    // the Apple Health capture option.
    private var showHealthConnectRow: Bool {
        _ = healthAuthToken
        return HealthAuthorizationManager.isHealthDataAvailable
            && !HealthAuthorizationManager.canWriteWorkouts
            && selectedMode != .healthKitOnly
    }

    private var locationGranted: Bool { routeRecorder.canRecord }

    // gpsRoute needs location; machineIntervals and healthKitOnly need nothing else to begin.
    private var canStart: Bool {
        switch selectedMode {
        case .gpsRoute: return locationGranted
        case .machineIntervals, .healthKitOnly: return true
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if appleHealthOffered {
                        captureModeSection
                    }

                    if hasRequirements {
                        requirementsSection
                    }
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    let mode = selectedMode
                    dismiss()
                    onStart(mode)
                } label: {
                    Label("Start \(type.title)", systemImage: type.systemImage)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.glassProminent)
                .disabled(!canStart)
                .padding()
                .accessibilityIdentifier(AccessibilityIdentifiers.cardioStartConfirm)
            }
            .quickActionContentBottomInset()
            .appBackground()
            .navigationTitle(type.title)
            .navigationBarTitleDisplayMode(.inline)
        }
        .diagScreen(VACrumb.cardioStart)
    }

    // MARK: Capture mode choice

    private var captureModeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How do you want to record this \(type.activity.title.lowercased())?")
                .font(.headline)

            VStack(spacing: 12) {
                CaptureModeCard(
                    title: "Apple Health",
                    description: "Heart rate, energy, distance, and route are recorded by Apple Health. Nothing to log — just go.",
                    systemImage: "heart.text.square",
                    isRecommended: true,
                    isSelected: selectedMode == .healthKitOnly
                ) { selectedMode = .healthKitOnly }

                CaptureModeCard(
                    title: manualModeTitle,
                    description: manualModeDescription,
                    systemImage: type.isOutdoor ? "location.fill" : "speedometer",
                    isRecommended: false,
                    isSelected: selectedMode == manualMode
                ) { selectedMode = manualMode }
            }
        }
    }

    private var manualModeTitle: String { type.isOutdoor ? "Track Route" : "Log Intervals" }

    private var manualModeDescription: String {
        type.isOutdoor
            ? "Villain Arc records your GPS route and distance as you go."
            : "Log speed and incline intervals by hand to build your distance."
    }

    // MARK: Requirements

    // gpsRoute always needs the location row; the optional Apple Health connect row appears while
    // Health is available but not yet granted.
    private var hasRequirements: Bool { selectedMode == .gpsRoute || showHealthConnectRow }

    private var requirementsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Permissions")
                .font(.headline)

            VStack(spacing: 0) {
                if selectedMode == .gpsRoute {
                    PermissionRow(
                        title: "Location",
                        description: locationRowDescription,
                        systemImage: "location.fill",
                        isGranted: locationGranted,
                        position: showHealthConnectRow ? .top : .single
                    ) {
                        if routeRecorder.authorizationStatus == .notDetermined {
                            routeRecorder.requestAuthorization()
                        } else {
                            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                            UIApplication.shared.open(url)
                        }
                    }
                }

                if showHealthConnectRow {
                    PermissionRow(
                        title: "Apple Health",
                        description: healthRowDescription,
                        systemImage: "heart.text.square",
                        isGranted: false,
                        isOptional: true,
                        position: selectedMode == .gpsRoute ? .bottom : .single
                    ) {
                        Task {
                            _ = await HealthAuthorizationManager.requestAuthorization()
                            healthAuthToken += 1
                        }
                    }
                }
            }

            if selectedMode == .gpsRoute && !locationGranted {
                Text("Location access is required to record your route and calculate distance.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var locationRowDescription: String {
        switch routeRecorder.authorizationStatus {
        case .notDetermined: return "Required — tap to allow"
        case .denied, .restricted: return "Required — open Settings to allow"
        case .authorizedAlways, .authorizedWhenInUse: return "Granted — route and distance tracking enabled"
        @unknown default: return "Required"
        }
    }

    private var healthRowDescription: String {
        if !HealthAuthorizationManager.isHealthDataAvailable {
            return "Not available on this device"
        }
        return "Optional — adds live heart rate, energy, and an Apple Health workout"
    }
}

private struct CaptureModeCard: View {
    let title: String
    let description: String
    let systemImage: String
    let isRecommended: Bool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.headline)
                        if isRecommended {
                            Text("Recommended")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.green.opacity(0.15), in: Capsule())
                        }
                    }
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .appSurfaceStyle(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier(AccessibilityIdentifiers.cardioCaptureModeCard(title))
    }
}

private struct PermissionRow: View {
    let title: String
    let description: String
    let systemImage: String
    let isGranted: Bool
    var isOptional: Bool = false
    let position: AppGroupedListRowPosition
    let action: () -> Void

    var body: some View {
        Button(action: isGranted ? {} : action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(isGranted ? .green : (isOptional ? .secondary : .orange))
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.headline)
                        if isOptional {
                            Text("Optional")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.secondary.opacity(0.15), in: Capsule())
                        }
                    }
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: isGranted ? "checkmark.circle.fill" : "chevron.right")
                    .foregroundStyle(isGranted ? .green : .secondary)
                    .font(isGranted ? .title3 : .caption.weight(.semibold))
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .disabled(isGranted)
        .appGroupedStackRow(position: position)
        .accessibilityIdentifier(AccessibilityIdentifiers.cardioStartPermissionRow(title))
    }
}
