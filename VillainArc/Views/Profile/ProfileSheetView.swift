import AVFoundation
import MuscleMap
import SwiftUI
import SwiftData
import UIKit

private struct ProfileCompletionDay: Identifiable {
    let date: Date
    let workoutCompleted: Bool
    let sleepGoalCompleted: Bool
    let stepsGoalCompleted: Bool
    let hydrationGoalCompleted: Bool

    var id: Date { date }
    var completionCount: Int {
        [workoutCompleted, sleepGoalCompleted, stepsGoalCompleted, hydrationGoalCompleted].filter { $0 }.count
    }
}

private extension Muscle {
    var profileMuscleMapMuscles: [MuscleMap.Muscle] {
        switch self {
        case .chest: return [.chest]
        case .back: return [.upperBack, .lowerBack]
        case .shoulders: return [.deltoids]
        case .biceps: return [.biceps]
        case .triceps: return [.triceps]
        case .abs: return [.abs]
        case .glutes: return [.gluteal]
        case .quads: return [.quadriceps]
        case .hamstrings: return [.hamstring]
        case .calves: return [.calves]
        case .forearms: return [.forearm]
        case .adductors: return [.adductors]
        case .abductors: return []
        case .upperChest: return [.upperChest]
        case .lowerChest: return [.lowerChest]
        case .midChest: return [.chest]
        case .lats: return [.upperBack]
        case .lowerBack: return [.lowerBack]
        case .upperTraps: return [.upperTrapezius]
        case .lowerTraps: return [.lowerTrapezius]
        case .midTraps: return [.trapezius]
        case .rhomboids: return [.rhomboids]
        case .frontDelt: return [.frontDeltoid]
        case .sideDelt: return [.deltoids]
        case .rearDelt: return [.rearDeltoid]
        case .rotatorCuff: return [.rotatorCuff]
        case .longHeadBiceps, .shortHeadBiceps, .brachialis: return [.biceps]
        case .longHeadTriceps, .lateralHeadTriceps, .medialHeadTriceps: return [.triceps]
        case .wrists: return [.forearm]
        case .upperAbs: return [.upperAbs]
        case .lowerAbs: return [.lowerAbs]
        case .obliques: return [.obliques]
        }
    }
}

private enum ProfileImagePickerSource: String, Identifiable {
    case photoLibrary
    case camera

    var id: String { rawValue }

    var uiKitSourceType: UIImagePickerController.SourceType {
        switch self {
        case .photoLibrary:
            return .photoLibrary
        case .camera:
            return .camera
        }
    }
}

struct ProfileSheetLauncherButton: View {
    @Query(UserProfile.single) private var profiles: [UserProfile]
    @State private var router = AppRouter.shared

    let accessibilityIdentifier: String

    var body: some View {
        Button {
            router.presentAppSheet(.profile)
            Task { await IntentDonations.donateOpenProfile() }
        } label: {
            ProfileAvatarBadge(displayName: profiles.first?.trimmedName, imageData: profiles.first?.profileImageData, size: 40)
        }
        .buttonStyle(.plain)
        .buttonBorderShape(.circle)
        .accessibilityLabel(AccessibilityText.profileLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(AccessibilityText.profileHint)
        .accessibilityIdentifier(accessibilityIdentifier)
        .padding(.trailing, 6)
    }

    private var accessibilityValue: String {
        if let profile = profiles.first, !profile.trimmedName.isEmpty {
            return profile.trimmedName
        }
        return String(localized: "Not set")
    }
}
struct ProfileSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(UserProfile.single) private var profiles: [UserProfile]
    @Query(TrainingGoal.active) private var activeTrainingGoals: [TrainingGoal]
    @Query(AppSettings.single) private var appSettings: [AppSettings]
    @Query(WorkoutSession.completedSession) private var completedWorkouts: [WorkoutSession]
    @Query(CardioSession.history) private var completedCardioSessions: [CardioSession]
    @Query(HealthSleepNight.history) private var sleepNights: [HealthSleepNight]
    @Query(HealthStepsDistance.history) private var stepsEntries: [HealthStepsDistance]
    @Query(HydrationDay.history) private var hydrationDays: [HydrationDay]
    @Query(SleepGoal.history) private var sleepGoals: [SleepGoal]
    @Query(StepsGoal.history) private var stepsGoals: [StepsGoal]

    private let initialSettingsDestination: AppSettingsDestination?
    private let showsCloseButton: Bool

    @State private var showAppSettings = false
    @State private var settingsDestination: AppSettingsDestination?
    @State private var didApplyInitialSettingsDestination = false
    @State private var showBirthdayEditor = false
    @State private var showGenderEditor = false
    @State private var showHeightEditor = false
    @State private var showFitnessLevelEditor = false
    @State private var showTrainingGoalEditor = false
    @State private var showPhotoOptions = false
    @State private var showCameraAccessAlert = false
    @State private var selectedProfileImage: UIImage?
    @State private var presentedImagePickerSource: ProfileImagePickerSource?
    @State private var editableName = ""
    @FocusState private var isNameFieldFocused: Bool

    private var profile: UserProfile? { profiles.first }
    private var activeTrainingGoal: TrainingGoal? { activeTrainingGoals.first }
    private var heightUnit: HeightUnit { appSettings.first?.heightUnit ?? .imperial }
    private var weightUnit: WeightUnit { appSettings.first?.weightUnit ?? .lbs }
    private let defaultProfileName = String(localized: "Your Name")

    init(initialSettingsDestination: AppSettingsDestination? = nil, showsCloseButton: Bool = true) {
        self.initialSettingsDestination = initialSettingsDestination
        self.showsCloseButton = showsCloseButton
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 50) {
                    VStack(spacing: 28) {
                        profileSummary
                        trainingSummaryCard
                        if !profileMuscleDistributionSlices.isEmpty {
                            profileMuscleDistributionCard
                        }
                        workoutHeatmapCard
                        detailsCard
                    }
                }
                .padding(.horizontal)
            }
            .quickActionContentBottomInset()
            .scrollIndicators(.hidden)
            .appBackground()
            .sheet(isPresented: $showAppSettings) {
                AppSettingsView(initialDestination: settingsDestination)
                    .presentationBackground(Color.sheetBg)
            }
            .sheet(isPresented: $showBirthdayEditor) {
                ProfileBirthdayEditorSheet(initialBirthday: resolvedBirthday) { birthday in
                    guard let profile else { return }
                    profile.birthday = birthday
                    saveContext(context: context)
                }
                .presentationDetents([.medium])
                .presentationBackground(Color.sheetBg)
            }
            .sheet(isPresented: $showGenderEditor) {
                ProfileGenderEditorSheet(initialSelection: profile?.gender ?? .notSet) { selectedGender in
                    guard let profile else { return }
                    profile.gender = selectedGender
                    saveContext(context: context)
                }
                .presentationDetents([.medium])
                .presentationBackground(Color.sheetBg)
            }
            .sheet(isPresented: $showHeightEditor) {
                ProfileHeightEditorSheet(initialHeightCm: profile?.heightCm, heightUnit: heightUnit) { selectedHeightCm in
                    guard let profile else { return }
                    profile.heightCm = selectedHeightCm
                    saveContext(context: context)
                }
                .presentationDetents([.medium])
                .presentationBackground(Color.sheetBg)
            }
            .sheet(isPresented: $showFitnessLevelEditor) {
                FitnessLevelEditorSheet(initialSelection: profile?.fitnessLevel, lastSetAt: profile?.fitnessLevelSetAt) { selectedLevel in
                    guard let profile else { return }
                    profile.fitnessLevel = selectedLevel
                    profile.fitnessLevelSetAt = .now
                    saveContext(context: context)
                }
                .presentationDetents([.fraction(0.8)])
                .presentationBackground(Color.sheetBg)
            }
            .sheet(isPresented: $showTrainingGoalEditor) {
                TrainingGoalEditorSheet(initialSelection: activeTrainingGoal?.kind) { selectedGoal in
                    do {
                        let didChange = try TrainingGoal.replaceActiveGoal(with: selectedGoal, context: context)
                        if didChange {
                            saveContext(context: context)
                        }
                    } catch {
                        AppLog.error("Failed to save training goal", error: error)
                    }
                }
                .presentationDetents([.fraction(0.8)])
                .presentationBackground(Color.sheetBg)
            }
            .sheet(item: $presentedImagePickerSource) { source in
                ProfileImagePicker(sourceType: source.uiKitSourceType, image: $selectedProfileImage)
                    .ignoresSafeArea()
            }
            .confirmationDialog("Update Profile Photo", isPresented: $showPhotoOptions, titleVisibility: .visible) {
                if canUseCamera() {
                    Button("Take Photo") {
                        Haptics.selection()
                        Task { await startCameraFlow() }
                    }
                }

                Button("Select Photo") {
                    Haptics.selection()
                    presentedImagePickerSource = .photoLibrary
                }

                if profile?.profileImageData != nil {
                    Button("Clear Photo", role: .destructive) {
                        Haptics.selection()
                        clearProfilePhoto()
                    }
                }
            }
            .alert("Camera Access Needed", isPresented: $showCameraAccessAlert) {
                Button("Open Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text("Allow camera access in Settings to take a profile photo.")
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if showsCloseButton {
                        Button(role: .close) {
                            Haptics.selection()
                            commitNameIfNeeded()
                            dismiss()
                        }
                        .accessibilityHint(AccessibilityText.closeButtonHint)
                        .accessibilityIdentifier(AccessibilityIdentifiers.profileSheetCloseButton)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") {
                        Haptics.selection()
                        settingsDestination = nil
                        showAppSettings = true
                        Task { await IntentDonations.donateOpenSettings() }
                    }
                    .accessibilityLabel(AccessibilityText.homeSettingsLabel)
                    .accessibilityHint(AccessibilityText.profileSheetSettingsHint)
                    .accessibilityIdentifier(AccessibilityIdentifiers.profileSheetSettingsButton)
                }
            }
            .onAppear {
                syncEditableName()
                presentInitialSettingsDestinationIfNeeded()
            }
            .onChange(of: profile?.persistentModelID) { _, _ in
                syncEditableName()
            }
            .onChange(of: isNameFieldFocused) { _, isFocused in
                if !isFocused {
                    commitNameIfNeeded()
                }
            }
            .onChange(of: editableName) { _, _ in
                guard profile != nil, isNameFieldFocused else { return }
                profile?.name = editableName
                scheduleSave(context: context)
            }
            .onChange(of: selectedProfileImage) { _, newImage in
                guard let newImage else { return }
                saveProfilePhoto(image: newImage)
                selectedProfileImage = nil
            }
            .onDisappear {
                commitNameIfNeeded()
            }
        }
    }

    private func presentInitialSettingsDestinationIfNeeded() {
        guard !didApplyInitialSettingsDestination else { return }
        didApplyInitialSettingsDestination = true
        guard let initialSettingsDestination else { return }
        settingsDestination = initialSettingsDestination
        showAppSettings = true
    }

    private var profileSummary: some View {
        VStack(spacing: 8) {
            ProfileAvatarBadge(displayName: trimmedEditableName, imageData: profile?.profileImageData, size: 96)
                .accessibilityIdentifier(AccessibilityIdentifiers.profileSheetAvatar)

            Text(effectiveDisplayName)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .accessibilityIdentifier(AccessibilityIdentifiers.profileSheetName)

            Button {
                Haptics.selection()
                showPhotoOptions = true
            } label: {
                Text("Edit photo")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(AccessibilityText.profileSheetEditPhotoLabel)
            .accessibilityValue(AccessibilityText.profileSheetEditPhotoValue(hasPhoto: profile?.profileImageData != nil))
            .accessibilityIdentifier(AccessibilityIdentifiers.profileSheetEditPhotoButton)
            .accessibilityHint(AccessibilityText.profileSheetEditPhotoHint)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var detailsCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Text("Name")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 16)

                TextField("Name", text: $editableName)
                    .font(.body)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($isNameFieldFocused)
                    .onSubmit {
                        commitNameIfNeeded()
                    }
                    .disabled(profile == nil)
                    .foregroundStyle(profile == nil ? .tertiary : .secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)

            Divider()
                .padding(.horizontal, 16)

            Button {
                guard profile != nil else { return }
                Haptics.selection()
                showBirthdayEditor = true
            } label: {
                ProfileEditorRowLabel(title: "Birthday", value: birthdayText)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.primary)
            .disabled(profile == nil)

            Divider()
                .padding(.horizontal, 16)

            ProfileDetailRow(title: "Age", value: ageText)

            Divider()
                .padding(.horizontal, 16)

            Button {
                guard profile != nil else { return }
                Haptics.selection()
                showGenderEditor = true
            } label: {
                ProfileEditorRowLabel(title: "Gender", value: genderText)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.primary)

            Divider()
                .padding(.horizontal, 16)

            Button {
                guard profile != nil else { return }
                Haptics.selection()
                showHeightEditor = true
            } label: {
                ProfileEditorRowLabel(title: "Height", value: heightText)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.primary)

            Divider()
                .padding(.horizontal, 16)

            Button {
                guard profile != nil else { return }
                Haptics.selection()
                showFitnessLevelEditor = true
            } label: {
                HStack(spacing: 3) {
                    Text("Fitness Level")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.7)

                    Spacer()

                    HStack(spacing: 3) {
                        if shouldShowFitnessLevelWarningIcon {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.yellow)
                                .accessibilityHidden(true)
                        }

                        Text(fitnessLevelText)
                            .foregroundStyle(.secondary)
                    }

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
                .lineLimit(1)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.primary)
            .accessibilityIdentifier(AccessibilityIdentifiers.profileSheetFitnessLevelRow)

            Divider()
                .padding(.horizontal, 16)

            Button {
                Haptics.selection()
                showTrainingGoalEditor = true
            } label: {
                ProfileEditorRowLabel(title: "Training Goal", value: trainingGoalText)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.primary)
            .accessibilityIdentifier(AccessibilityIdentifiers.profileSheetTrainingGoalRow)
        }
        .appCardStyle()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityIdentifiers.profileSheetDetailsCard)
    }

    private var trainingSummaryCard: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12, alignment: .top)], spacing: 12) {
            SummaryStatCard(title: "Workouts", text: "\(completedWorkouts.count)")
            SummaryStatCard(title: "This Week", text: "\(workoutsThisWeek)")
            SummaryStatCard(title: "Streak", text: currentStreakText)
            if totalTrainingVolume > 0 {
                SummaryStatCard(title: "Total Volume", text: formattedWeightText(totalTrainingVolume, unit: weightUnit, fractionDigits: 0...0))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("profileSheetTrainingSummaryCard")
    }

    private var profileMuscleDistributionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Muscle Distribution")
                .font(.headline)

            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    profileMuscleMapBodyView(side: .front)
                        .frame(maxWidth: .infinity)
                        .frame(height: 210)

                    profileMuscleMapBodyView(side: .back)
                        .frame(maxWidth: .infinity)
                        .frame(height: 210)
                }

                VStack(spacing: 10) {
                    ForEach(profileMuscleDistributionSlices.prefix(5)) { slice in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(profileMuscleColor(for: slice.percentage))
                                .frame(width: 10, height: 10)
                                .accessibilityHidden(true)

                            Text(slice.muscle.displayName)
                                .font(.subheadline.weight(.semibold))

                            Spacer()

                            Text((slice.percentage / 100).formatted(.percent.precision(.fractionLength(0))))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(16)
            .appCardStyle()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("profileSheetMuscleMapCard")
        }
    }

    private var workoutHeatmapCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Complete Days")
                    .font(.headline)
                Spacer()
                Text("Past 6 months")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                profileHeatmapGrid
                    .padding(.vertical, 2)
            }
            .padding(16)
            .appCardStyle()

            HStack(spacing: 6) {
                Text(completeDaysCounterText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("Less")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                HStack(spacing: 3) {
                    ForEach(0..<5, id: \.self) { count in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(completionHeatmapColor(for: count))
                            .frame(width: 12, height: 12)
                    }
                }
                .accessibilityHidden(true)

                Text("More")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
        }
    }

    private var profileHeatmapGrid: some View {
        let weeks = profileHeatmapWeeks
        return HStack(alignment: .top, spacing: 3) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                VStack(spacing: 3) {
                    ForEach(0..<7, id: \.self) { dayOfWeek in
                        if let day = week[dayOfWeek] {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(completionHeatmapColor(for: day.completionCount))
                                .frame(width: 12, height: 12)
                                .accessibilityLabel(day.date.formatted(date: .abbreviated, time: .omitted))
                                .accessibilityValue(completionAccessibilityValue(for: day))
                        } else {
                            Color.clear
                                .frame(width: 12, height: 12)
                                .accessibilityHidden(true)
                        }
                    }
                }
            }
        }
    }

    private var trimmedEditableName: String? {
        let trimmed = editableName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var effectiveDisplayName: String {
        guard let trimmedEditableName else {
            return String(localized: "Your Profile")
        }
        return trimmedEditableName
    }

    private var birthdayText: String {
        guard let birthday = profile?.birthday else {
            return String(localized: "Not Set")
        }
        return birthday.formatted(date: .long, time: .omitted)
    }

    private var ageText: String {
        guard let birthday = profile?.birthday,
              let years = Calendar.autoupdatingCurrent.dateComponents([.year], from: birthday, to: .now).year,
              years >= 0 else {
            return String(localized: "Not Available")
        }
        return String(localized: "\(years) years old")
    }

    private var genderText: String {
        guard let gender = profile?.gender, gender != .notSet else {
            return String(localized: "Not Set")
        }
        return gender.displayName
    }

    private var heightText: String {
        guard let heightCm = profile?.heightCm else {
            return String(localized: "Not Set")
        }

        switch heightUnit {
        case .imperial:
            let (feet, inches) = normalizedImperialHeightComponents(from: heightCm)
            return "\(feet) ft \(inches) in"
        case .cm:
            return "\(Int(heightCm.rounded())) cm"
        }
    }

    private var trainingGoalText: String {
        activeTrainingGoal?.kind.title ?? String(localized: "Not Set")
    }

    private var workoutsThisWeek: Int {
        guard let weekInterval = Calendar.autoupdatingCurrent.dateInterval(of: .weekOfYear, for: .now) else { return 0 }
        return completedWorkouts.filter { weekInterval.contains($0.startedAt) }.count
    }

    private var totalTrainingVolume: Double {
        completedWorkouts.reduce(0) { $0 + $1.totalVolume }
    }

    private var profileMuscleDistributionSlices: [MuscleDistributionSlice] {
        var totalsByMuscle: [Muscle: Double] = [:]

        for workout in completedWorkouts {
            for slice in MuscleDistributionCalculator.slices(for: workout) {
                totalsByMuscle[slice.muscle, default: 0] += slice.score
            }
        }

        let totalScore = totalsByMuscle.values.reduce(0, +)
        guard totalScore > 0 else { return [] }

        return totalsByMuscle
            .map { muscle, score in
                MuscleDistributionSlice(muscle: muscle, score: score, percentage: (score / totalScore) * 100)
            }
            .sorted {
                if $0.score == $1.score {
                    return $0.muscle.displayName < $1.muscle.displayName
                }
                return $0.score > $1.score
            }
    }

    private func profileMuscleMapBodyView(side: BodySide) -> BodyView {
        var view = BodyView(gender: .male, side: side)
        for slice in profileMuscleDistributionSlices {
            for mapMuscle in slice.muscle.profileMuscleMapMuscles {
                view = view.highlight(mapMuscle, color: profileMuscleColor(for: slice.percentage), opacity: profileMuscleOpacity(for: slice.percentage))
            }
        }
        return view
    }

    private func profileMuscleColor(for percentage: Double) -> Color {
        switch percentage {
        case 35...:
            return .red
        case 20..<35:
            return .orange
        case 10..<20:
            return .yellow
        default:
            return .blue
        }
    }

    private func profileMuscleOpacity(for percentage: Double) -> Double {
        min(max(percentage / 45, 0.28), 0.9)
    }

    private var profileCompletionDays: [ProfileCompletionDay] {
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: .now)
        let workoutDays = completedTrainingDays(calendar: calendar)
        let sleepByDay = Dictionary(uniqueKeysWithValues: sleepNights.map { (calendar.startOfDay(for: $0.displayWakeDay), $0) })
        let stepsByDay = Dictionary(uniqueKeysWithValues: stepsEntries.map { (calendar.startOfDay(for: $0.date), $0) })
        let hydrationByDay = Dictionary(uniqueKeysWithValues: hydrationDays.map { (calendar.startOfDay(for: $0.date), $0) })

        return (0..<profileHeatmapTotalDays).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let sleepNight = sleepByDay[day]
            let stepsEntry = stepsByDay[day]
            return ProfileCompletionDay(
                date: day,
                workoutCompleted: workoutDays.contains(day),
                sleepGoalCompleted: sleepGoalCompleted(on: day, sleepNight: sleepNight),
                stepsGoalCompleted: stepsGoalCompleted(on: day, stepsEntry: stepsEntry),
                hydrationGoalCompleted: hydrationByDay[day]?.goalCompleted == true
            )
        }
    }

    private let profileHeatmapTotalDays = 26 * 7

    private var profileHeatmapWeeks: [[ProfileCompletionDay?]] {
        let calendar = Calendar.autoupdatingCurrent
        let days = profileCompletionDays
        guard let firstDay = days.first else { return [] }

        let firstWeekday = calendar.component(.weekday, from: firstDay.date)
        let weekdayIndex = (firstWeekday + 5) % 7

        var allCells: [ProfileCompletionDay?] = Array(repeating: nil, count: weekdayIndex)
        allCells.append(contentsOf: days.map { Optional($0) })

        let weekCount = Int((Double(allCells.count) / 7).rounded(.up))
        let paddedCount = weekCount * 7
        if allCells.count < paddedCount {
            allCells.append(contentsOf: Array(repeating: nil, count: paddedCount - allCells.count))
        }

        return stride(from: 0, to: allCells.count, by: 7).map { weekStart in
            Array(allCells[weekStart..<min(weekStart + 7, allCells.count)])
        }
    }

    private var completeDaysCounterText: String {
        let count = profileCompletionDays.filter { $0.completionCount == 4 }.count
        let prefix = count == 1 ? "1 complete day" : "\(count) complete days"
        return "\(prefix) in the last 6 months"
    }

    private func sleepGoalCompleted(on day: Date, sleepNight: HealthSleepNight?) -> Bool {
        guard let goal = sleepGoals.first(where: { $0.contains(day: day) }),
              let sleepNight else { return false }
        return sleepNight.timeAsleep >= goal.targetSleepDuration
    }

    private func stepsGoalCompleted(on day: Date, stepsEntry: HealthStepsDistance?) -> Bool {
        guard let goal = stepsGoals.first(where: { $0.contains(day: day) }),
              let stepsEntry else { return false }
        return stepsEntry.stepCount >= goal.targetSteps
    }

    private func completionHeatmapColor(for count: Int) -> Color {
        switch count {
        case 0:
            return Color.secondary.opacity(0.15)
        case 1:
            return Color.red.opacity(0.3)
        case 2:
            return Color.red.opacity(0.55)
        case 3:
            return Color.red.opacity(0.8)
        default:
            return Color.red
        }
    }

    private func completionAccessibilityValue(for day: ProfileCompletionDay) -> String {
        guard day.completionCount > 0 else { return String(localized: "No goals completed") }
        var parts: [String] = []
        if day.workoutCompleted { parts.append(String(localized: "workout completed")) }
        if day.sleepGoalCompleted { parts.append(String(localized: "sleep goal completed")) }
        if day.stepsGoalCompleted { parts.append(String(localized: "steps goal completed")) }
        if day.hydrationGoalCompleted { parts.append(String(localized: "hydration goal completed")) }
        return parts.joined(separator: ", ")
    }

    private var currentStreakText: String {
        let days = currentWorkoutStreakDays
        return days == 1 ? "1 day" : "\(days) days"
    }

    private var currentWorkoutStreakDays: Int {
        let calendar = Calendar.autoupdatingCurrent
        let workoutDays = completedTrainingDays(calendar: calendar)
        guard !workoutDays.isEmpty else { return 0 }

        var day = calendar.startOfDay(for: .now)
        if !workoutDays.contains(day),
           let yesterday = calendar.date(byAdding: .day, value: -1, to: day),
           workoutDays.contains(yesterday) {
            day = yesterday
        }

        var streak = 0
        while workoutDays.contains(day) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previousDay
        }

        return streak
    }

    private func completedTrainingDays(calendar: Calendar) -> Set<Date> {
        let strengthDays = completedWorkouts.map { calendar.startOfDay(for: $0.startedAt) }
        let cardioDays = completedCardioSessions.compactMap { $0.startedAt }.map { calendar.startOfDay(for: $0) }
        return Set(strengthDays + cardioDays)
    }

    private var fitnessLevelText: String {
        profile?.fitnessLevel?.title ?? String(localized: "Not Set")
    }

    private var shouldShowFitnessLevelWarningIcon: Bool {
        guard let level = profile?.fitnessLevel, let setAt = profile?.fitnessLevelSetAt else { return false }
        return level.suggestedNextLevelIfReviewDue(lastSetAt: setAt) != nil
    }

    private var resolvedBirthday: Date {
        if let birthday = profile?.birthday {
            return birthday
        }

        return Calendar.autoupdatingCurrent.date(byAdding: .year, value: -18, to: .now) ?? .now
    }

    private func syncEditableName() {
        editableName = profile?.name ?? ""
    }

    private func commitNameIfNeeded() {
        guard let profile else { return }
        let normalizedName = normalizedCommittedName(from: editableName)
        editableName = normalizedName
        guard profile.name != normalizedName else { return }
        profile.name = normalizedName
        saveContext(context: context)
    }

    private func normalizedCommittedName(from rawName: String) -> String {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultProfileName : trimmed
    }

    private func startCameraFlow() async {
        guard canUseCamera() else { return }

        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            presentedImagePickerSource = .camera
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted {
                presentedImagePickerSource = .camera
            } else {
                showCameraAccessAlert = true
            }
        case .denied, .restricted:
            showCameraAccessAlert = true
        @unknown default:
            showCameraAccessAlert = true
        }
    }

    private func saveProfilePhoto(image: UIImage) {
        guard let data = processedProfileImageData(from: image) else { return }
        saveProfilePhoto(data: data)
    }

    private func saveProfilePhoto(data: Data?) {
        guard let profile else { return }
        profile.profileImageData = data
        saveContext(context: context)
    }

    private func clearProfilePhoto() {
        saveProfilePhoto(data: nil)
    }

}

#Preview(traits: .sampleData) {
    ProfileSheetView()
}
