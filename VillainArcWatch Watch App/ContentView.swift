import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Query(AppSettings.single) private var appSettings: [AppSettings]
    @Query(UserProfile.single) private var userProfiles: [UserProfile]
    @Query(Exercise.catalogExercises) private var catalogExercises: [Exercise]
    @Query(WorkoutSession.incomplete) private var incompleteSessions: [WorkoutSession]
    @State private var runtimeCoordinator = WatchWorkoutRuntimeCoordinator.shared

    private var liveSessionFallback: WorkoutSession? {
        incompleteSessions.first { session in
            switch session.statusValue {
            case .pending, .active:
                true
            case .summary, .done:
                false
            }
        }
    }

    private var setupState: WatchSetupGuard.State {
        if !appSettings.isEmpty,
           let profile = userProfiles.first,
           profile.firstMissingStep == nil,
           !catalogExercises.isEmpty {
            return .ready
        }

        let hasPartialData = !appSettings.isEmpty || !userProfiles.isEmpty || !catalogExercises.isEmpty
        return hasPartialData ? .syncingFromPhone : .requiresPhoneSetup
    }

    var body: some View {
        NavigationStack {
            switch setupState {
            case .syncingFromPhone:
                placeholderScreen(
                    systemImage: "arrow.triangle.2.circlepath.icloud",
                    title: "Syncing from iPhone...",
                    message: "Villain Arc is waiting for your workout data and setup to finish syncing."
                )
            case .requiresPhoneSetup:
                placeholderScreen(
                    systemImage: "iphone",
                    title: "Complete Setup on iPhone",
                    message: "Open Villain Arc on your iPhone and finish setup first."
                )
            case .ready:
                if runtimeCoordinator.activeSnapshot != nil || liveSessionFallback != nil {
                    WatchLiveWorkoutView(
                        snapshot: runtimeCoordinator.activeSnapshot,
                        fallbackSession: liveSessionFallback,
                        runtimeCoordinator: runtimeCoordinator
                    )
                } else {
                    WatchHomeView(runtimeCoordinator: runtimeCoordinator)
                }
            }
        }
        .task {
            runtimeCoordinator.activateIfNeeded()
            await runtimeCoordinator.sceneDidBecomeActive()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await runtimeCoordinator.sceneDidBecomeActive()
            }
        }
    }

    @ViewBuilder
    private func placeholderScreen(systemImage: String, title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .imageScale(.large)
                .font(.title2)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Continue on iPhone") {
                WatchPhoneHandoffCoordinator.openAppOnPhone()
            }
            .frame(minHeight: 44)
        }
        .padding()
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ContentView()
        .modelContainer(WatchSharedModelContainer.container)
}
