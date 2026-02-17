import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var manager: OnboardingManager?
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                // App Icon/Logo
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 80))
                    .foregroundStyle(.primary)

                Text("VillainArc")
                    .font(.largeTitle.bold())

                Spacer()

                // State-specific content
                if let manager {
                    stateView(for: manager.state, manager: manager)
                } else {
                    ProgressView()
                }

                Spacer()
            }
            .padding(40)
        }
        .task {
            if manager == nil {
                manager = OnboardingManager(modelContext: modelContext)
                await manager?.startOnboarding()
            }
        }
        .onChange(of: manager?.state) { _, newState in
            if newState == .ready {
                completeOnboarding()
            }
        }
    }

    @ViewBuilder
    private func stateView(for state: OnboardingState, manager: OnboardingManager) -> some View {
        switch state {
        case .checking:
            VStack(spacing: 16) {
                ProgressView()
                Text("Checking system status...")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

        case .noWiFi:
            VStack(spacing: 16) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 60))
                    .foregroundStyle(.red)

                Text("WiFi Required")
                    .font(.title2.bold())

                Text("VillainArc needs WiFi for first-time setup to sync your workout data.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Button("Retry") {
                    Task { await manager.retry() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

        case .noiCloud:
            VStack(spacing: 16) {
                Image(systemName: "icloud.slash")
                    .font(.system(size: 60))
                    .foregroundStyle(.orange)

                Text("iCloud Disabled")
                    .font(.title2.bold())

                Text("Your workout data won't sync across devices or be backed up if you delete the app.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                VStack(spacing: 12) {
                    Button("Continue Without iCloud") {
                        Task { await manager.continueWithoutiCloud() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button("Enable iCloud in Settings") {
                        if let url = URL(string: "App-prefs:CASTLE") {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }

        case .cloudKitUnavailable:
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.icloud")
                    .font(.system(size: 60))
                    .foregroundStyle(.red)

                Text("Servers Unavailable")
                    .font(.title2.bold())

                Text("Unable to connect to VillainArc servers. Please check your internet connection and try again.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Button("Retry") {
                    Task { await manager.retry() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

        case .syncing:
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)

                Text("Syncing Your Data")
                    .font(.title2.bold())

                Text("Downloading your workout history from iCloud...")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

        case .syncingSlowNetwork:
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)

                Text("Still Syncing...")
                    .font(.title2.bold())

                Text("This is taking longer than expected. Your network connection may be slow. Please wait while we sync your data.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

        case .seeding:
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)

                Text("Setting Up Exercises")
                    .font(.title2.bold())

                Text("Preparing your exercise catalog...")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

        case .ready:
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)

                Text("Ready to Go!")
                    .font(.title2.bold())

                Text("Your workout companion is all set up.")
                    .foregroundStyle(.secondary)
            }

        case .error(let message):
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 60))
                    .foregroundStyle(.red)

                Text("Setup Error")
                    .font(.title2.bold())

                Text(message)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Button("Retry") {
                    Task { await manager.retry() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    private func completeOnboarding() {
        withAnimation {
            hasCompletedOnboarding = true
        }
    }
}

#Preview {
    OnboardingView()
        .modelContainer(for: [Exercise.self], inMemory: true)
}
