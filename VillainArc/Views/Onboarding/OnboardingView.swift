import CoreLocation
import FCTAccount
import SwiftData
import SwiftUI

private func normalizedOnboardingImperialHeightComponents(from centimeters: Double) -> (feet: Int, inches: Int) {
    let roundedTotalInches = Int((centimeters / 2.54).rounded())
    let feet = roundedTotalInches / 12
    let inches = roundedTotalInches % 12
    return (feet, inches)
}

private enum OnboardingStep: Hashable {
    case healthPermissions
    case locationPermissions
    case birthday
    case gender
    case height
    case fitnessLevel
    case trainingGoal
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
        case .fitnessLevel:
            self = .fitnessLevel
        case .trainingGoal:
            self = .trainingGoal
        }
    }
}

// The onboarding sheet sizes itself to the step currently on screen by measuring
// that step's natural content height at runtime — Dynamic Type and localization
// aware — instead of using hardcoded detent fractions.
private extension View {
    /// Reports the receiver's natural height into the manager so the sheet's detent
    /// can follow it. `chrome` accounts for surrounding sheet / navigation-bar space
    /// the measured content itself doesn't include.
    func reportsOnboardingHeight(to manager: OnboardingManager, chrome: CGFloat) -> some View {
        onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
            guard height > 0 else { return }
            manager.sheetHeight = height + chrome
        }
    }
}

// Sheet chrome added on top of the measured content height.
private enum OnboardingChrome {
    /// A pushed profile / permission step (inline navigation bar + sheet top inset).
    static let navStep: CGFloat = 100
    /// A root state shown without a navigation bar (bootstrap, finishing, health).
    static let plain: CGFloat = 56
}

struct OnboardingView: View {
    @Bindable var manager: OnboardingManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var path: [OnboardingStep] = []
    @ScaledMetric(relativeTo: .largeTitle) private var onboardingIconSize: CGFloat = 60

    var body: some View {
        Group {
            switch manager.state {
            case .profile:
                profileFlow
            case .healthPermissions:
                healthPermissionsView
            case .account:
                accountStepView
            case .finishing:
                finishingView
            default:
                bootstrapView
            }
        }
        .onChange(of: manager.state, initial: true) { oldState, newState in
            if case .profile = oldState, case .profile = newState {
                return
            }

            if case .profile = oldState {
                path = []
            }
        }
        .presentationDetents([.height(max(280, manager.sheetHeight))])
        .animation(.easeInOut(duration: 0.25), value: manager.sheetHeight)
    }

    private var bootstrapView: some View {
        VStack(spacing: 40) {
            Text("Setting up Villain Arc")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top, 20)
            
            Spacer()
            
            stateView(for: manager.state)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var profileFlow: some View {
        NavigationStack(path: $path) {
            profileRootView
                .navigationDestination(for: OnboardingStep.self) { step in
                    switch step {
                    case .healthPermissions:
                        OnboardingHealthPermissionStepView(manager: manager, path: $path)
                    case .locationPermissions:
                        OnboardingLocationPermissionStepView(manager: manager, path: $path)
                    case .birthday:
                        ProfileBirthdayStepView(manager: manager, path: $path)
                    case .gender:
                        ProfileGenderStepView(manager: manager, path: $path)
                    case .height:
                        ProfileHeightStepView(manager: manager, path: $path)
                    case .fitnessLevel:
                        ProfileFitnessLevelStepView(manager: manager, path: $path)
                    case .trainingGoal:
                        ProfileTrainingGoalStepView(manager: manager, path: $path)
                    }
                }
        }
    }

    @ViewBuilder
    private var profileRootView: some View {
        if case .profile(let step) = manager.state {
            if step != .name && manager.shouldInsertHealthPermissionsStep {
                OnboardingHealthPermissionStepView(manager: manager, path: $path)
            } else {
                profileStepView(for: step)
            }
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func profileStepView(for step: UserProfileOnboardingStep) -> some View {
        switch step {
        case .name:
            ProfileNameStepView(manager: manager, path: $path)
        case .birthday:
            ProfileBirthdayStepView(manager: manager, path: $path)
        case .gender:
            ProfileGenderStepView(manager: manager, path: $path)
        case .height:
            ProfileHeightStepView(manager: manager, path: $path)
        case .fitnessLevel:
            ProfileFitnessLevelStepView(manager: manager, path: $path)
        case .trainingGoal:
            ProfileTrainingGoalStepView(manager: manager, path: $path)
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

        case .profile, .healthPermissions, .account, .finishing, .ready:
            EmptyView()
        }
    }

    /// The terminal onboarding step: the FCT account sign-in, hosted whole from `FCTAccount` with
    /// the required-account wording. Setup data is already saved locally at this point; signing in
    /// is what enrolls the device with the platform sync engine (and restores any existing account
    /// data in the background). `FCTOnboarding.AccountOnboardingFlow` packages the same terminal
    /// step behind the intro carousel; Villain Arc's onboarding is a multi-step setup flow rather
    /// than a carousel, so it hosts the sign-in surface directly, exactly as that flow does.
    private var accountStepView: some View {
        OnboardingAccountStepView(manager: manager)
    }

}

private struct OnboardingAccountStepView: View {
    @Bindable var manager: OnboardingManager

    var body: some View {
        Group {
            if let account = manager.account {
                AccountSignInView(controller: account, appearance: .accountRequired)
                    .onChange(of: account.state, initial: true) { _, newState in
                        guard case .signedIn = newState else { return }
                        manager.accountStepCompleted()
                    }
            } else {
                // No controller attached (previews, tests): nothing to sign in with, so don't
                // strand the sheet.
                OnboardingProgressStateView(title: "Finishing Setup")
                    .task { manager.accountStepCompleted() }
            }
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
            Spacer()
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
        .fixedSize(horizontal: false, vertical: true)
        .reportsOnboardingHeight(to: manager, chrome: OnboardingChrome.navStep)
        .navigationTitle("Apple Health")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func pushNextProfileStep() {
        path.append(.locationPermissions)
    }
}

private struct OnboardingLocationPermissionStepView: View {
    @Bindable var manager: OnboardingManager
    @Binding var path: [OnboardingStep]
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 60
    @State private var locationManager = CLLocationManager()

    var body: some View {
        VStack(spacing: 14) {
            Spacer()

            Image(systemName: "location.fill")
                .font(.system(size: iconSize))
                .accessibilityHidden(true)
                .foregroundStyle(.blue)

            Text("Location for Outdoor Runs")
                .font(.title)
                .bold()

            Text("Villain Arc uses your location to record GPS routes for outdoor runs, walks, and hikes. Your location is only used while a cardio session is active.")
                .multilineTextAlignment(.leading)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    locationManager.requestWhenInUseAuthorization()
                    pushNextStep()
                } label: {
                    Text("Continue")
                        .padding(.vertical, 8)
                        .fontWeight(.semibold)
                }
                .buttonSizing(.flexible)
                .buttonStyle(.glassProminent)
            }
        }
        .padding(.horizontal)
        .fixedSize(horizontal: false, vertical: true)
        .reportsOnboardingHeight(to: manager, chrome: OnboardingChrome.navStep)
        .navigationTitle("Location")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func pushNextStep() {
        guard let nextStep = manager.nextRequiredStep else { return }
        if let onboardingStep = OnboardingStep(profileStep: nextStep) {
            path.append(onboardingStep)
        }
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
        }
        .padding()
        .fixedSize(horizontal: false, vertical: true)
        .reportsOnboardingHeight(to: manager, chrome: OnboardingChrome.navStep)
        .simultaneousGesture(
            TapGesture().onEnded {
                dismissKeyboard()
            }
        )
        .navigationTitle("What's your name?")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
#if DEBUG
            DebugSkipOnboardingToolbarItem(manager: manager, path: $path)
#endif
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .confirm) {
                    Haptics.selection()
                    Task {
                        guard await manager.saveName(name) else { return }
                        if manager.shouldInsertHealthPermissionsStep {
                            path.append(.healthPermissions)
                        } else {
                            path.append(.locationPermissions)
                        }
                    }
                }
                .fontWeight(.semibold)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
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
        }
        .padding()
        .fixedSize(horizontal: false, vertical: true)
        .reportsOnboardingHeight(to: manager, chrome: OnboardingChrome.navStep)
        .navigationTitle("When's your birthday?")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
#if DEBUG
            DebugSkipOnboardingToolbarItem(manager: manager, path: $path)
#endif
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .confirm) {
                    Haptics.selection()
                    Task {
                        guard await manager.saveBirthday(birthday) else { return }
                        if let nextStep = manager.nextRequiredStep {
                            if let onboardingStep = OnboardingStep(profileStep: nextStep) {
                                path.append(onboardingStep)
                            }
                        }
                    }
                }
                .fontWeight(.semibold)
            }
        }
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
        }
        .padding()
        .fixedSize(horizontal: false, vertical: true)
        .reportsOnboardingHeight(to: manager, chrome: OnboardingChrome.navStep)
        .animation(reduceMotion ? nil : .bouncy, value: gender)
        .navigationTitle("What's your gender?")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
#if DEBUG
            DebugSkipOnboardingToolbarItem(manager: manager, path: $path)
#endif
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .confirm) {
                    Haptics.selection()
                    Task {
                        guard await manager.saveGender(gender) else { return }
                        if let nextStep = manager.nextRequiredStep {
                            if let onboardingStep = OnboardingStep(profileStep: nextStep) {
                                path.append(onboardingStep)
                            }
                        }
                    }
                }
                .fontWeight(.semibold)
                .disabled(gender == .notSet)
                .accessibilityHint(AccessibilityText.onboardingGenderContinueHint)
            }
        }
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
    private static let inchOptions = Array(0...11).map(Double.init)
    private static let cmOptions = Array(100...250).map { Double($0) }

    init(manager: OnboardingManager, path: Binding<[OnboardingStep]>) {
        self.manager = manager
        _path = path
        let storedCm = manager.prefetchedHeightCm ?? manager.profile?.heightCm ?? 177.0
        _cm = State(initialValue: storedCm)
        let normalizedHeight = normalizedOnboardingImperialHeightComponents(from: storedCm)
        let f = max(3, min(8, normalizedHeight.feet))
        let i = Double(normalizedHeight.inches)
        _feet = State(initialValue: f)
        _inches = State(initialValue: i)
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
        }
        .padding()
        .fixedSize(horizontal: false, vertical: true)
        .reportsOnboardingHeight(to: manager, chrome: OnboardingChrome.navStep)
        .navigationTitle("What's your height?")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
#if DEBUG
            DebugSkipOnboardingToolbarItem(manager: manager, path: $path)
#endif
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .confirm) {
                    Haptics.selection()
                    let saveCm = heightUnit == .imperial ? HeightUnit.imperial.toCm(feet: feet, inches: inches) : cm
                    Task {
                        guard await manager.saveHeight(cm: saveCm) else { return }
                        if let nextStep = manager.nextRequiredStep {
                            if let onboardingStep = OnboardingStep(profileStep: nextStep) {
                                path.append(onboardingStep)
                            }
                        }
                    }
                }
                .fontWeight(.semibold)
            }
        }
    }

    private func inchesLabel(for value: Double) -> String {
        "\(Int(value)) in"
    }
}

private struct ProfileFitnessLevelStepView: View {
    @Bindable var manager: OnboardingManager
    @Binding var path: [OnboardingStep]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedLevel: FitnessLevel?

    init(manager: OnboardingManager, path: Binding<[OnboardingStep]>) {
        self.manager = manager
        _path = path
        _selectedLevel = State(initialValue: manager.profile?.fitnessLevel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(FitnessLevel.influenceDescription)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                FitnessLevelSelectionList(selection: $selectedLevel)
            }
            .padding()
            .reportsOnboardingHeight(to: manager, chrome: OnboardingChrome.navStep)
        }
        .scrollIndicators(.hidden)
        .animation(reduceMotion ? nil : .bouncy, value: selectedLevel)
        .navigationTitle("What's your fitness level?")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
#if DEBUG
            DebugSkipOnboardingToolbarItem(manager: manager, path: $path)
#endif
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .confirm) {
                    guard let selectedLevel else { return }
                    Haptics.selection()
                    Task {
                        guard await manager.saveFitnessLevel(selectedLevel) else { return }
                        if let nextStep = manager.nextRequiredStep, let onboardingStep = OnboardingStep(profileStep: nextStep) {
                            path.append(onboardingStep)
                        }
                    }
                }
                .fontWeight(.semibold)
                .disabled(selectedLevel == nil)
                .accessibilityHint(AccessibilityText.onboardingFitnessLevelContinueHint)
            }
        }
        .onAppear {
            selectedLevel = manager.profile?.fitnessLevel
        }
    }
}

private struct ProfileTrainingGoalStepView: View {
    @Bindable var manager: OnboardingManager
    @Binding var path: [OnboardingStep]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(TrainingGoal.active) private var activeGoals: [TrainingGoal]
    @State private var selectedGoal: TrainingGoalKind?

    init(manager: OnboardingManager, path: Binding<[OnboardingStep]>) {
        self.manager = manager
        _path = path
        _selectedGoal = State(initialValue: nil)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(TrainingGoalKind.influenceDescription)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                TrainingGoalSelectionList(selection: $selectedGoal)
            }
            .padding()
            .reportsOnboardingHeight(to: manager, chrome: OnboardingChrome.navStep)
        }
        .scrollIndicators(.hidden)
        .animation(reduceMotion ? nil : .bouncy, value: selectedGoal)
        .navigationTitle("How do you like to train?")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
#if DEBUG
            DebugSkipOnboardingToolbarItem(manager: manager, path: $path)
#endif
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .confirm) {
                    guard let selectedGoal else { return }
                    Haptics.selection()
                    Task {
                        guard await manager.saveTrainingGoal(selectedGoal) else { return }
                    }
                }
                .fontWeight(.semibold)
                .disabled(selectedGoal == nil)
                .accessibilityHint(AccessibilityText.onboardingTrainingGoalContinueHint)
            }
        }
        .onAppear {
            selectedGoal = activeGoals.first?.kind
        }
    }
}

#if DEBUG
private struct DebugSkipOnboardingToolbarItem: ToolbarContent {
    let manager: OnboardingManager
    @Binding var path: [OnboardingStep]

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Skip", systemImage: "forward.end.fill") {
                Haptics.selection()
                Task {
                    path.removeAll()
                    await manager.completeOnboardingWithDebugData()
                }
            }
            .fontWeight(.semibold)
        }
    }
}
#endif
