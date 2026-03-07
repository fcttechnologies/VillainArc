import SwiftUI

struct OnboardingView: View {
    @Bindable var manager: OnboardingManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var path: [UserProfileOnboardingStep] = []
    @State private var wasShowingProfileFlow = false

    var body: some View {
        Group {
            switch manager.state {
            case .profile:
                profileFlow
            case .finishing:
                finishingView
            default:
                bootstrapView
            }
        }
        .onChange(of: manager.state, initial: true) { oldState, newState in
            let wasProfile = isProfileState(oldState)
            let isProfile = isProfileState(newState)

            if isProfile && !wasProfile {
                syncProfilePathIfNeeded(force: true)
                return
            }

            if !isProfile {
                wasShowingProfileFlow = false
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            guard shouldRetryWhenBecomingActive else { return }
            Task { await manager.retry() }
        }
    }

    private var bootstrapView: some View {
        VStack(spacing: 40) {
            
            Text("Setting up Villain Arc")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top, 20)

            stateView(for: manager.state)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
            
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var profileFlow: some View {
        NavigationStack(path: $path) {
            ProfileNameStepView(manager: manager, path: $path)
                .navigationDestination(for: UserProfileOnboardingStep.self) { step in
                    switch step {
                    case .name:
                        ProfileNameStepView(manager: manager, path: $path)
                    case .birthday:
                        ProfileBirthdayStepView(manager: manager, path: $path)
                    case .height:
                        ProfileHeightStepView(manager: manager, path: $path)
                    }
                }
        }
    }

    private func isProfileState(_ state: OnboardingState) -> Bool {
        if case .profile = state {
            return true
        }
        return false
    }

    private func syncProfilePathIfNeeded(force: Bool) {
        guard case .profile = manager.state else { return }
        guard force || !wasShowingProfileFlow else { return }
        path = manager.profileStepPath()
        wasShowingProfileFlow = true
    }

    private var shouldRetryWhenBecomingActive: Bool {
        switch manager.state {
        case .noiCloud, .cloudKitUnavailable:
            return true
        default:
            return false
        }
    }

    private var finishingView: some View {
        OnboardingProgressStateView(title: "Wrapping Things Up", message: "Saving your profile and finishing setup...")
    }

    @ViewBuilder
    private func stateView(for state: OnboardingState) -> some View {
        switch state {
        case .launching:
            OnboardingProgressStateView(title: "Starting Up")

        case .checking:
            OnboardingProgressStateView(title: "Checking System Status...")

        case .noWiFi:
            VStack(spacing: 16) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 60))
                    .foregroundStyle(.red)

                Text("WiFi Required")
                    .font(.title2.bold())

                Text("VillainArc needs WiFi for first time setup to sync your workout data.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Spacer()
                
                Button {
                    Task { await manager.retry() }
                } label: {
                    Text("Retry")
                        .padding(.vertical, 8)
                        .fontWeight(.semibold)
                }
                .buttonSizing(.flexible)
                .buttonStyle(.glassProminent)
            }
            .padding()

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
                    Button {
                        Task { await manager.continueWithoutiCloud() }
                    } label: {
                        Text("Continue Without iCloud")
                            .padding(.vertical, 8)
                            .fontWeight(.semibold)
                    }
                    .buttonSizing(.flexible)
                    .buttonStyle(.glassProminent)

                    Button {
                        if let url = URL(string: "App-prefs:CASTLE") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("Enable iCloud in Settings")
                            .padding(.vertical, 8)
                            .fontWeight(.semibold)
                    }
                    .buttonSizing(.flexible)
                    .buttonStyle(.glass)
                }
            }

        case .cloudKitUnavailable:
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.icloud")
                    .font(.system(size: 60))
                    .foregroundStyle(.red)

                Text("Servers Unavailable")
                    .font(.title2.bold())

                Text("Unable to connect to iCloud right now. Please check your internet connection and try again.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Button {
                    Task { await manager.retry() }
                } label: {
                    Text("Retry")
                        .padding(.vertical, 8)
                        .fontWeight(.semibold)
                }
                .buttonSizing(.flexible)
                .buttonStyle(.glassProminent)
            }

        case .syncing:
            OnboardingProgressStateView(title: "Syncing Your Data", message: "Checking iCloud for your existing workout history and profile...")

        case .syncingSlowNetwork:
            OnboardingProgressStateView(title: "Still Syncing...", message: "This is taking longer than expected. Please wait while VillainArc finishes syncing.")

        case .seeding:
            OnboardingProgressStateView(title: "Updating Exercises", message: "Preparing your exercise catalog...")

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

                Button {
                    Task { await manager.retry() }
                } label: {
                    Text("Retry")
                        .padding(.vertical, 8)
                        .fontWeight(.semibold)
                }
                .buttonSizing(.flexible)
                .buttonStyle(.glassProminent)
            }

        case .profile, .finishing, .ready:
            EmptyView()
        }
    }
}

private struct OnboardingProgressStateView: View {
    let title: LocalizedStringKey
    var message: LocalizedStringKey? = nil

    var body: some View {
        VStack(spacing: 16) {
            ProgressView(title)
                .controlSize(.large)

            if let message {
                Text(message)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ProfileNameStepView: View {
    @Bindable var manager: OnboardingManager
    @Binding var path: [UserProfileOnboardingStep]
    @State private var name: String

    init(manager: OnboardingManager, path: Binding<[UserProfileOnboardingStep]>) {
        self.manager = manager
        _path = path
        _name = State(initialValue: manager.profile?.name ?? "")
    }

    var body: some View {
        VStack {
            Spacer()
            
            TextField("Name", text: $name)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .font(.largeTitle)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button {
                Task {
                    guard await manager.saveName(name) else { return }
                    path = UserProfileOnboardingStep.navigationPath(to: .birthday)
                }
            } label: {
                Text("Continue")
                    .padding(.vertical, 8)
                    .fontWeight(.semibold)
            }
            .buttonSizing(.flexible)
            .buttonStyle(.glassProminent)
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
        .simultaneousGesture(
            TapGesture().onEnded {
                dismissKeyboard()
            }
        )
        .navigationTitle("What's your name?")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ProfileBirthdayStepView: View {
    @Bindable var manager: OnboardingManager
    @Binding var path: [UserProfileOnboardingStep]
    @State private var birthday: Date

    init(manager: OnboardingManager, path: Binding<[UserProfileOnboardingStep]>) {
        self.manager = manager
        _path = path
        let defaultBirthday = Calendar.current.date(byAdding: .year, value: -25, to: .now) ?? .now
        _birthday = State(initialValue: manager.profile?.birthday ?? defaultBirthday)
    }

    var body: some View {
        VStack {
            Spacer()

            DatePicker("Birthday", selection: $birthday, in: ...Date.now, displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
            
            Spacer()
            
            Button {
                Task {
                    guard await manager.saveBirthday(birthday) else { return }
                    path = UserProfileOnboardingStep.navigationPath(to: .height)
                }
            } label: {
                Text("Continue")
                    .padding(.vertical, 8)
                    .fontWeight(.semibold)
            }
            .buttonSizing(.flexible)
            .buttonStyle(.glassProminent)
        }
        .padding()
        .navigationTitle("When's your birthday?")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ProfileHeightStepView: View {
    @Bindable var manager: OnboardingManager
    @Binding var path: [UserProfileOnboardingStep]
    @State private var feet: Int
    @State private var inches: Double

    private static let feetOptions = Array(3...8)
    private static let inchOptions = stride(from: 0.0, through: 11.5, by: 0.5).map { $0 }

    init(manager: OnboardingManager, path: Binding<[UserProfileOnboardingStep]>) {
        self.manager = manager
        _path = path
        _feet = State(initialValue: manager.profile?.heightFeet ?? 5)
        _inches = State(initialValue: manager.profile?.heightInches ?? 10)
    }

    var body: some View {
        VStack {
            Spacer()
            
            HStack {
                Picker("Feet", selection: $feet) {
                    ForEach(Self.feetOptions, id: \.self) { option in
                        Text("\(option) ft").tag(option)
                    }
                }
                .pickerStyle(.wheel)

                Picker("Inches", selection: $inches) {
                    ForEach(Self.inchOptions, id: \.self) { option in
                        Text(inchesLabel(for: option)).tag(option)
                    }
                }
                .pickerStyle(.wheel)
            }
            .frame(maxWidth: .infinity)
            
            Spacer()
            
            Button {
                Task { await manager.saveHeight(feet: feet, inches: inches) }
            } label: {
                Text("Finish")
                    .padding(.vertical, 8)
                    .fontWeight(.semibold)
            }
            .buttonSizing(.flexible)
            .buttonStyle(.glassProminent)
        }
        .padding()
        .navigationTitle("What's your height?")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func inchesLabel(for value: Double) -> String {
        if value.rounded(.towardZero) == value {
            return "\(Int(value)) in"
        }
        return String(format: "%.1f in", value)
    }
}
