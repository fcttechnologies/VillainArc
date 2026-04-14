import SwiftUI
import SwiftData

private enum OnboardingStep: Hashable {
    case healthPermissions
    case birthday
    case gender
    case height
}

private extension OnboardingStep {
    init?(profileStep: UserProfileOnboardingStep) {
        switch profileStep {
        case .name:
            return nil
        case .birthday:
            self = .birthday
        case .gender:
            self = .gender
        case .height:
            self = .height
        }
    }
}

private func profileNavigationPath(to step: UserProfileOnboardingStep) -> [OnboardingStep] {
    UserProfileOnboardingStep.navigationPath(to: step).compactMap(OnboardingStep.init(profileStep:))
}

struct OnboardingView: View {
    @Bindable var manager: OnboardingManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var path: [OnboardingStep] = []
    @State private var didSetInitialPath = false
    @ScaledMetric(relativeTo: .largeTitle) private var onboardingIconSize: CGFloat = 60

    var body: some View {
        Group {
            switch manager.state {
            case .profile:
                profileFlow
            case .healthPermissions:
                healthPermissionsView
            case .finishing:
                finishingView
            default:
                bootstrapView
            }
        }
        .onChange(of: manager.state, initial: true) { oldState, newState in
            if case .profile = newState {
                if !didSetInitialPath {
                    didSetInitialPath = true
                    guard case .profile(let step) = manager.state else { return }
                    if step == .name {
                        path = []
                    } else if manager.shouldInsertHealthPermissionsStep {
                        path = [.healthPermissions]
                    } else {
                        path = profileNavigationPath(to: step)
                    }
                }
            } else if case .profile = oldState {
                path = []
                didSetInitialPath = false
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            guard manager.state == .noiCloud || manager.state == .cloudKitAccountIssue || manager.state == .cloudKitUnavailable else { return }
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
                .navigationDestination(for: OnboardingStep.self) { step in
                    switch step {
                    case .healthPermissions:
                        OnboardingHealthPermissionStepView(manager: manager, path: $path)
                    case .birthday:
                        ProfileBirthdayStepView(manager: manager, path: $path)
                    case .gender:
                        ProfileGenderStepView(manager: manager, path: $path)
                    case .height:
                        ProfileHeightStepView(manager: manager, path: $path)
                    }
                }
        }
    }

    private var finishingView: some View {
        OnboardingProgressStateView(title: "Wrapping Things Up", message: "Saving your profile and finishing setup...")
    }

    private var healthPermissionsView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "heart.text.square.fill")
                .font(.system(size: onboardingIconSize))
                .accessibilityHidden(true)
                .symbolRenderingMode(.multicolor)
                .foregroundStyle(.red)

            Text("Connect to Health")
                .font(.title)
                .bold()

            Text("Villain Arc needs additional Apple Health permissions to enable new features it has added and future Health features as they roll out.")
                .multilineTextAlignment(.leading)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    Task { await manager.connectAppleHealth() }
                } label: {
                    Text("Connect to Apple Health")
                        .padding(.vertical, 8)
                        .fontWeight(.semibold)
                }
                .buttonSizing(.flexible)
                .buttonStyle(.glassProminent)
                .accessibilityHint(AccessibilityText.onboardingConnectHealthHint)

                Button {
                    manager.skipAppleHealth()
                } label: {
                    Text("Not Now")
                        .padding(.vertical, 8)
                        .fontWeight(.semibold)
                }
                .buttonSizing(.flexible)
                .buttonStyle(.glass)
                .accessibilityHint(AccessibilityText.onboardingSkipHealthHint)
            }
        }
        .padding(.horizontal)
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
                    .font(.system(size: onboardingIconSize))
                    .foregroundStyle(.red)
                    .accessibilityHidden(true)

                Text("WiFi Required")
                    .font(.title2.bold())

                Text("Villain Arc needs WiFi for first time setup to sync your workout data.")
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
                .accessibilityHint(AccessibilityText.onboardingRetryHint)
            }
            .padding()

        case .noiCloud:
            VStack(spacing: 16) {
                Image(systemName: "icloud.slash")
                    .font(.system(size: onboardingIconSize))
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)

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
                    .accessibilityHint(AccessibilityText.onboardingContinueWithoutiCloudHint)

                    Button {
                        guard let url = URL(string: "App-prefs:CASTLE") else { return }
                        UIApplication.shared.open(url)
                    } label: {
                        Text("Enable iCloud in Settings")
                            .padding(.vertical, 8)
                            .fontWeight(.semibold)
                    }
                    .buttonSizing(.flexible)
                    .buttonStyle(.glass)
                    .accessibilityHint(AccessibilityText.onboardingEnableICloudHint)
                }
            }

        case .cloudKitAccountIssue:
            VStack(spacing: 16) {
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: onboardingIconSize))
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)

                Text("Check Your iCloud Account")
                    .font(.title2.bold())

                Text("Villain Arc couldn't access your iCloud account. Make sure you're signed in to iCloud and that CloudKit access isn't restricted.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                VStack(spacing: 12) {
                    Button {
                        Task { await manager.retry() }
                    } label: {
                        Text("Retry")
                            .padding(.vertical, 8)
                            .fontWeight(.semibold)
                    }
                    .buttonSizing(.flexible)
                    .buttonStyle(.glassProminent)
                    .accessibilityHint(AccessibilityText.onboardingRetryHint)

                    Button {
                        guard let url = URL(string: "App-prefs:CASTLE") else { return }
                        UIApplication.shared.open(url)
                    } label: {
                        Text("Open iCloud Settings")
                            .padding(.vertical, 8)
                            .fontWeight(.semibold)
                    }
                    .buttonSizing(.flexible)
                    .buttonStyle(.glass)
                    .accessibilityHint(AccessibilityText.onboardingEnableICloudHint)
                }
            }

        case .cloudKitUnavailable:
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.icloud")
                    .font(.system(size: onboardingIconSize))
                    .foregroundStyle(.red)
                    .accessibilityHidden(true)

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
                .accessibilityHint(AccessibilityText.onboardingRetryHint)
            }

        case .syncing:
            OnboardingProgressStateView(title: "Syncing Your Data", message: "Checking iCloud for your existing workout history and profile...")

        case .syncingSlowNetwork:
            OnboardingProgressStateView(title: "Still Syncing...", message: "This is taking longer than expected. Villain Arc will keep waiting for iCloud sync to finish before continuing.")

        case .seeding:
            OnboardingProgressStateView(title: "Updating Exercises", message: "Preparing your exercise catalog...")

        case .error(let message):
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: onboardingIconSize))
                    .foregroundStyle(.red)
                    .accessibilityHidden(true)

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
                .accessibilityHint(AccessibilityText.onboardingRetryHint)
            }

        case .profile, .healthPermissions, .finishing, .ready:
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

private struct OnboardingHealthPermissionStepView: View {
    @Bindable var manager: OnboardingManager
    @Binding var path: [OnboardingStep]
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 60
    @State private var hasAuthorized = false
    @State private var isConnecting = false

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: iconSize))
                .accessibilityHidden(true)
                .symbolRenderingMode(.multicolor)
                .foregroundStyle(.red)

            Text("Connect to Health")
                .font(.title)
                .bold()

            Text("Villain Arc can export your completed workouts to Apple Health as well as read other workout metrics to improve suggestions and make the overall app richer.")
                .multilineTextAlignment(.leading)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
            
            Spacer()

            VStack(spacing: 12) {
                if hasAuthorized {
                    Button {
                        pushNextProfileStep()
                    } label: {
                        Text("Continue")
                            .padding(.vertical, 8)
                            .fontWeight(.semibold)
                    }
                    .buttonSizing(.flexible)
                    .buttonStyle(.glassProminent)
                } else {
                    Button {
                        isConnecting = true
                        Task {
                            await manager.connectAppleHealthDuringOnboarding()
                            hasAuthorized = HealthAuthorizationManager.currentAuthorizationState.isAuthorized
                            isConnecting = false
                            pushNextProfileStep()
                        }
                    } label: {
                        Text("Connect to Apple Health")
                            .padding(.vertical, 8)
                            .fontWeight(.semibold)
                    }
                    .buttonSizing(.flexible)
                    .buttonStyle(.glassProminent)
                    .disabled(isConnecting)
                    .accessibilityHint(AccessibilityText.onboardingConnectHealthHint)

                    Button {
                        manager.skipAppleHealthDuringOnboarding()
                        pushNextProfileStep()
                    } label: {
                        Text("Not Now")
                            .padding(.vertical, 8)
                            .fontWeight(.semibold)
                    }
                    .buttonSizing(.flexible)
                    .buttonStyle(.glass)
                    .disabled(isConnecting)
                    .accessibilityHint(AccessibilityText.onboardingSkipHealthHint)
                }
            }
        }
        .padding(.horizontal)
        .navigationTitle("Apple Health")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func pushNextProfileStep() {
        guard let nextStep = manager.profile?.firstMissingStep else { return }
        path = [.healthPermissions] + profileNavigationPath(to: nextStep)
    }
}

private struct ProfileNameStepView: View {
    @Bindable var manager: OnboardingManager
    @Binding var path: [OnboardingStep]
    @State private var name: String

    init(manager: OnboardingManager, path: Binding<[OnboardingStep]>) {
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
                .textContentType(.name)

            Spacer()

            Button {
                Task {
                    guard await manager.saveName(name) else { return }
                    if manager.shouldInsertHealthPermissionsStep {
                        path.append(.healthPermissions)
                    } else if let nextStep = manager.profile?.firstMissingStep {
                        path = profileNavigationPath(to: nextStep)
                    }
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
    @Binding var path: [OnboardingStep]
    @State private var birthday: Date

    init(manager: OnboardingManager, path: Binding<[OnboardingStep]>) {
        self.manager = manager
        _path = path
        let defaultBirthday = Calendar.current.date(byAdding: .year, value: -25, to: .now) ?? .now
        _birthday = State(initialValue: manager.prefetchedBirthday ?? manager.profile?.birthday ?? defaultBirthday)
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
                    if let nextStep = manager.profile?.firstMissingStep, let onboardingStep = OnboardingStep(profileStep: nextStep) {
                        path.append(onboardingStep)
                    }
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

private struct ProfileGenderStepView: View {
    @Bindable var manager: OnboardingManager
    @Binding var path: [OnboardingStep]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var gender: UserGender

    init(manager: OnboardingManager, path: Binding<[OnboardingStep]>) {
        self.manager = manager
        _path = path
        _gender = State(initialValue: manager.prefetchedGender ?? manager.profile?.gender ?? .notSet)
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 12) {
                ForEach(UserGender.selectableCases, id: \.self) { option in
                    if gender == option {
                        Button {
                            gender = option
                        } label: {
                            HStack {
                                Text(option.displayName)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, 8)
                            .fontWeight(.semibold)
                        }
                        .buttonSizing(.flexible)
                        .buttonStyle(.glassProminent)
                        .accessibilityHint(AccessibilityText.onboardingGenderOptionHint)
                        .accessibilityValue(AccessibilityText.onboardingGenderOptionValue(isSelected: true))
                        .accessibilityAddTraits(.isSelected)
                    } else {
                        Button {
                            gender = option
                        } label: {
                            HStack {
                                Text(option.displayName)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, 8)
                            .fontWeight(.semibold)
                        }
                        .buttonSizing(.flexible)
                        .buttonStyle(.glass)
                        .accessibilityHint(AccessibilityText.onboardingGenderOptionHint)
                        .accessibilityValue(AccessibilityText.onboardingGenderOptionValue(isSelected: false))
                    }
                }
            }

            Spacer()

            Button {
                Task {
                    guard await manager.saveGender(gender) else { return }
                    if let nextStep = manager.profile?.firstMissingStep, let onboardingStep = OnboardingStep(profileStep: nextStep) {
                        path.append(onboardingStep)
                    }
                }
            } label: {
                Text("Continue")
                    .padding(.vertical, 8)
                    .fontWeight(.semibold)
            }
            .buttonSizing(.flexible)
            .buttonStyle(.glassProminent)
            .disabled(gender == .notSet)
            .accessibilityHint(AccessibilityText.onboardingGenderContinueHint)
        }
        .padding()
        .animation(reduceMotion ? nil : .bouncy, value: gender)
        .navigationTitle("What's your gender?")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ProfileHeightStepView: View {
    @Bindable var manager: OnboardingManager
    @Binding var path: [OnboardingStep]
    @Query(AppSettings.single) private var appSettings: [AppSettings]

    @State private var cm: Double
    @State private var feet: Int
    @State private var inches: Double

    private static let feetOptions = Array(3...8)
    private static let inchOptions = stride(from: 0.0, through: 11.5, by: 0.5).map { $0 }
    private static let cmOptions = Array(100...250).map { Double($0) }

    init(manager: OnboardingManager, path: Binding<[OnboardingStep]>) {
        self.manager = manager
        _path = path
        let storedCm = manager.prefetchedHeightCm ?? manager.profile?.heightCm ?? 177.0
        _cm = State(initialValue: storedCm)
        let totalInches = storedCm / 2.54
        let f = max(3, min(8, Int(totalInches / 12)))
        let i = (totalInches.truncatingRemainder(dividingBy: 12) * 2).rounded() / 2
        _feet = State(initialValue: f)
        _inches = State(initialValue: min(i, 11.5))
    }

    private var heightUnit: HeightUnit { appSettings.first?.heightUnit ?? .imperial }

    var body: some View {
        VStack {
            Spacer()

            if heightUnit == .imperial {
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
            } else {
                Picker("Height (cm)", selection: $cm) {
                    ForEach(Self.cmOptions, id: \.self) { option in
                        Text("\(Int(option)) cm").tag(option)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
            }

            Spacer()

            Button {
                let saveCm = heightUnit == .imperial ? HeightUnit.imperial.toCm(feet: feet, inches: inches) : cm
                Task { await manager.saveHeight(cm: saveCm) }
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
