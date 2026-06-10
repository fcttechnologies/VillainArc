import CoreLocation
import SwiftUI
import UIKit

struct CardioOutdoorPermissionView: View {
    let type: CardioSessionType
    var showsLocation: Bool = true
    let onStart: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var routeRecorder = CardioRouteRecorder.shared

    private var locationStatus: CLAuthorizationStatus { routeRecorder.authorizationStatus }
    private var locationGranted: Bool { routeRecorder.canRecord }
    private var healthGranted: Bool { HealthAuthorizationManager.canWriteWorkouts }

    private var canStart: Bool { showsLocation ? locationGranted : true }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Before You Go")
                            .font(.title2.bold())
                        Text("Villain Arc needs the following to track your \(type.title.lowercased()).")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    permissionChecklist

                    if showsLocation && !locationGranted {
                        Text("Location access is required to record your route and calculate distance.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    dismiss()
                    onStart()
                } label: {
                    Label("Start \(type.title)", systemImage: type.systemImage)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.glassProminent)
                .disabled(!canStart)
                .padding()
            }
            .quickActionContentBottomInset()
            .appBackground()
            .navigationTitle(type.title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var permissionChecklist: some View {
        VStack(spacing: 0) {
            if showsLocation {
                PermissionRow(
                    title: "Location",
                    description: locationRowDescription,
                    systemImage: "location.fill",
                    isGranted: locationGranted,
                    position: showsLocation ? .top : .single
                ) {
                    if locationStatus == .notDetermined {
                        routeRecorder.requestAuthorization()
                    } else {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                }
            }

            PermissionRow(
                title: "Apple Health",
                description: healthRowDescription,
                systemImage: "heart.text.square",
                isGranted: healthGrantedFully,
                isOptional: true,
                position: showsLocation ? .bottom : .single
            ) {
                Task { _ = await HealthAuthorizationManager.requestAuthorization() }
            }
        }
    }

    private var locationRowDescription: String {
        switch locationStatus {
        case .notDetermined: return "Required — tap to allow"
        case .denied, .restricted: return "Required — open Settings to allow"
        case .authorizedAlways, .authorizedWhenInUse: return "Granted — route and distance tracking enabled"
        @unknown default: return "Required"
        }
    }

    private var healthGrantedFully: Bool {
        HealthAuthorizationManager.canWriteWorkouts
            && HealthAuthorizationManager.canWriteActiveEnergyBurned
            && HealthAuthorizationManager.canWriteWalkingRunningDistance
    }

    private var healthRowDescription: String {
        if healthGrantedFully {
            return "Granted — heart rate, distance, energy, and workout export enabled"
        } else if healthGranted {
            return "Partially granted — some metrics may not be recorded"
        } else if !HealthAuthorizationManager.isHealthDataAvailable {
            return "Not available on this device"
        } else {
            return "Optional — live heart rate, distance, active energy, and workout export"
        }
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
    }
}
