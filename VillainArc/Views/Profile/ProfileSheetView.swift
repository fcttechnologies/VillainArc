import FCTAccountProfile
import SwiftUI
import SwiftData

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

/// One cell of the heatmap grid. Every column is a full Sun–Sat week, so the current (partial) week
/// renders all 7 cells: days within the 6-month window carry their completion data, days after today
/// render as visible-but-uncolored `.future` cells, and days before the window are `.blank` (clear).
private enum ProfileHeatmapCell {
    case day(ProfileCompletionDay)
    case future
    case blank
}

struct ProfileSheetLauncherButton: View {
    @Query private var accountProfileFields: [AccountProfileField]
    @State private var router = AppRouter.shared
    @State private var sync = VASync.shared

    let accessibilityIdentifier: String

    var body: some View {
        Button {
            router.presentAppSheet(.profile)
            Task { await IntentDonations.donateOpenProfile() }
        } label: {
            AccountFace(diameter: 40, avatars: sync.avatars)
        }
        .buttonStyle(.plain)
        .buttonBorderShape(.circle)
        .accessibilityLabel(AccessibilityText.profileLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(AccessibilityText.profileHint)
        .accessibilityIdentifier(accessibilityIdentifier)
        .padding(.trailing, 6)
    }

    /// The account's name, or `nil` for the monogram's fallback glyph.
    private var accountName: String? {
        let name = AccountProfileField.displayName(from: accountProfileFields)
        return name.isEmpty ? nil : name
    }

    private var accessibilityValue: String {
        accountName ?? String(localized: "Not set")
    }
}

/// The account's avatar wherever Villain Arc draws a person: `AccountAvatar` once the account's
/// blob store exists, and a neutral circle of the same size for the moments before it does — a
/// launch that has not started the engine yet, and the update after a sign-out. The size is held
/// either way so the toolbar does not jump.
private struct AccountFace: View {
    let diameter: CGFloat
    let avatars: AccountBlobStore?

    var body: some View {
        if let avatars {
            AccountAvatar(diameter: diameter, avatars: avatars)
        } else {
            Circle()
                .fill(.quaternary)
                .frame(width: diameter, height: diameter)
        }
    }
}
struct ProfileSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var accountProfileFields: [AccountProfileField]
    @Query(UserProfile.single) private var profiles: [UserProfile]
    @Query(TrainingGoal.active) private var activeTrainingGoals: [TrainingGoal]
    @Query(AppSettings.single) private var appSettings: [AppSettings]
    @Query(WorkoutSession.completedSession) private var completedWorkouts: [WorkoutSession]
    @Query(CardioSession.history) private var completedCardioSessions: [CardioSession]
    @Query(HealthWorkout.history) private var completedHealthWorkouts: [HealthWorkout]
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
    @State private var showGenderEditor = false
    @State private var showHeightEditor = false
    @State private var showFitnessLevelEditor = false
    @State private var showTrainingGoalEditor = false
    @State private var sync = VASync.shared
    private var profile: UserProfile? { profiles.first }
    private var activeTrainingGoal: TrainingGoal? { activeTrainingGoals.first }
    private var heightUnit: HeightUnit { appSettings.first?.heightUnit ?? .imperial }
    private var weightUnit: WeightUnit { appSettings.first?.weightUnit ?? .lbs }

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
                        MuscleDistributionCard()
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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if showsCloseButton {
                        Button(role: .close) {
                            Haptics.selection()
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
                presentInitialSettingsDestinationIfNeeded()
            }
        }
        // Soft scroll-edge fade in the sheet presentation context (the root TabView modifier only
        // covers this view when it's the Profile tab). Inert on the iOS 26 SDK (see ContentView).
        .scrollEdgeEffectStyle(.soft, for: .all)
    }

    private func presentInitialSettingsDestinationIfNeeded() {
        guard !didApplyInitialSettingsDestination else { return }
        didApplyInitialSettingsDestination = true
        guard let initialSettingsDestination else { return }
        settingsDestination = initialSettingsDestination
        showAppSettings = true
    }

    /// The account's face and name. Both are edited in Settings' `AccountProfileSection`, which is
    /// the one place in the fleet either is changed, so this shows them and offers nothing.
    private var profileSummary: some View {
        VStack(spacing: 8) {
            AccountFace(diameter: 96, avatars: sync.avatars)
                .accessibilityIdentifier(AccessibilityIdentifiers.profileSheetAvatar)

            Text(effectiveDisplayName)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .accessibilityIdentifier(AccessibilityIdentifiers.profileSheetName)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var detailsCard: some View {
        VStack(spacing: 0) {
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
            .accessibilityIdentifier(AccessibilityIdentifiers.profileSheetGenderRow)

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
            .accessibilityIdentifier(AccessibilityIdentifiers.profileSheetHeightRow)

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

    private var workoutHeatmapCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Complete Days")
                .font(.headline)

            profileHeatmapGrid
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
        let columns = max(weeks.count, 1)
        let spacing: CGFloat = 3
        let today = Calendar.autoupdatingCurrent.startOfDay(for: .now)
        // A fixed (non-scrolling) 7×~26 grid that fits the card width: oldest week on the left,
        // current week as the rightmost (full 7-cell) column. The cell size is derived from the
        // available width so all ~26 columns are always visible at once.
        return GeometryReader { geometry in
            let cellSize = max(0, min(
                (geometry.size.width - spacing * CGFloat(columns - 1)) / CGFloat(columns),
                (geometry.size.height - spacing * 6) / 7
            ))
            HStack(alignment: .top, spacing: spacing) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    VStack(spacing: spacing) {
                        ForEach(0..<7, id: \.self) { dayOfWeek in
                            heatmapCellView(dayOfWeek < week.count ? week[dayOfWeek] : .blank, size: cellSize, today: today)
                        }
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
        }
        .aspectRatio(CGFloat(columns) / 7, contentMode: .fit)
    }

    @ViewBuilder
    private func heatmapCellView(_ cell: ProfileHeatmapCell, size: CGFloat, today: Date) -> some View {
        let isToday: Bool = {
            if case .day(let day) = cell { return day.date == today }
            return false
        }()
        RoundedRectangle(cornerRadius: 2)
            .fill(heatmapCellColor(cell))
            .frame(width: size, height: size)
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(Color.primary, lineWidth: 1.5)
                }
            }
            .accessibilityLabel(heatmapCellAccessibilityLabel(cell))
            .accessibilityValue(heatmapCellAccessibilityValue(cell))
            .accessibilityHidden(heatmapCellIsDecorative(cell))
    }

    private func heatmapCellColor(_ cell: ProfileHeatmapCell) -> Color {
        switch cell {
        case .day(let day): return completionHeatmapColor(for: day.completionCount)
        case .future: return completionHeatmapColor(for: 0) // present but uncolored
        case .blank: return Color.clear // before the 6-month window
        }
    }

    private func heatmapCellAccessibilityLabel(_ cell: ProfileHeatmapCell) -> String {
        if case .day(let day) = cell {
            return day.date.formatted(date: .abbreviated, time: .omitted)
        }
        return ""
    }

    private func heatmapCellAccessibilityValue(_ cell: ProfileHeatmapCell) -> String {
        if case .day(let day) = cell {
            return completionAccessibilityValue(for: day)
        }
        return ""
    }

    private func heatmapCellIsDecorative(_ cell: ProfileHeatmapCell) -> Bool {
        if case .day = cell { return false }
        return true
    }

    /// The account's name, or `nil` for the monogram's fallback glyph.
    private var accountName: String? {
        let name = AccountProfileField.displayName(from: accountProfileFields)
        return name.isEmpty ? nil : name
    }

    private var effectiveDisplayName: String {
        accountName ?? String(localized: "Your Profile")
    }

    /// Age is the **account's** birthday, read once per launch. "Not Available" while that read
    /// has not answered — which only happens before the account onboarding completes.
    private var ageText: String {
        guard let years = AccountBirthday.shared.age() else {
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

    private var profileCompletionDays: [ProfileCompletionDay] {
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: .now)
        let windowStart = profileHeatmapWindowStart
        let dayCount = (calendar.dateComponents([.day], from: windowStart, to: today).day ?? 0) + 1
        let workoutDays = completedTrainingDays(calendar: calendar)
        let sleepByDay = Dictionary(uniqueKeysWithValues: sleepNights.map { (calendar.startOfDay(for: $0.displayWakeDay), $0) })
        let stepsByDay = Dictionary(uniqueKeysWithValues: stepsEntries.map { (calendar.startOfDay(for: $0.date), $0) })
        let hydrationByDay = Dictionary(uniqueKeysWithValues: hydrationDays.map { (calendar.startOfDay(for: $0.date), $0) })

        // Oldest day first (the aligned Sunday window start) through today, so the grid's leftmost
        // column is a full Sun–Sat week and only the current, in-progress week is partial.
        return (0..<dayCount).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: windowStart) else { return nil }
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

    private let profileHeatmapWeekCount = 26

    /// First day of the heatmap window: the Sunday `profileHeatmapWeekCount - 1` weeks before the
    /// Sunday of the current week. Aligning to Sunday (weekday 1, matching the grid's Sun-top rows)
    /// makes every column a full Sun–Sat week except the current, still-in-progress one.
    private var profileHeatmapWindowStart: Date {
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: .now)
        let weekdayIndex = calendar.component(.weekday, from: today) - 1 // 0=Sun…6=Sat
        let startOfThisWeek = calendar.date(byAdding: .day, value: -weekdayIndex, to: today) ?? today
        return calendar.date(byAdding: .day, value: -7 * (profileHeatmapWeekCount - 1), to: startOfThisWeek) ?? startOfThisWeek
    }

    private var profileHeatmapWeeks: [[ProfileHeatmapCell]] {
        let calendar = Calendar.autoupdatingCurrent
        let days = profileCompletionDays
        guard let windowStart = days.first?.date, let today = days.last?.date else { return [] }
        let completionByDay = Dictionary(uniqueKeysWithValues: days.map { ($0.date, $0) })

        // GitHub-style layout: Sunday is the top row (index 0), Saturday the bottom (index 6), so
        // every column is a full 7-cell week. The grid spans from the Sunday of the window-start's
        // week through the Saturday of the current week — that's why the current week always shows
        // all 7 cells, with not-yet-occurred days rendered as visible-but-uncolored `.future` cells.
        let leadingPad = calendar.component(.weekday, from: windowStart) - 1 // 1=Sun…7=Sat
        let trailingPad = 7 - calendar.component(.weekday, from: today)
        guard let gridStart = calendar.date(byAdding: .day, value: -leadingPad, to: windowStart) else { return [] }
        let totalCells = leadingPad + days.count + trailingPad

        var cells: [ProfileHeatmapCell] = []
        cells.reserveCapacity(totalCells)
        for offset in 0..<totalCells {
            guard let date = calendar.date(byAdding: .day, value: offset, to: gridStart) else { continue }
            if let day = completionByDay[date] {
                cells.append(.day(day))
            } else if date < windowStart {
                cells.append(.blank)
            } else {
                cells.append(.future)
            }
        }

        return stride(from: 0, to: cells.count, by: 7).map { weekStart in
            Array(cells[weekStart..<min(weekStart + 7, cells.count)])
        }
    }

    private var completeDaysCounterText: String {
        // Count must match the days the grid actually colors: any day with at least one completed
        // goal/workout (completionCount > 0), not only days where all four goals were met.
        let count = profileCompletionDays.filter { $0.completionCount > 0 }.count
        let prefix = count == 1 ? "1 complete day" : "\(count) complete days"
        return "\(prefix) in the last \(profileHeatmapWeekCount) weeks"
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
        let healthWorkoutDays = completedHealthWorkouts.map { calendar.startOfDay(for: $0.startDate) }
        return Set(strengthDays + cardioDays + healthWorkoutDays)
    }

    private var fitnessLevelText: String {
        profile?.fitnessLevel?.title ?? String(localized: "Not Set")
    }

    private var shouldShowFitnessLevelWarningIcon: Bool {
        guard let level = profile?.fitnessLevel, let setAt = profile?.fitnessLevelSetAt else { return false }
        return level.suggestedNextLevelIfReviewDue(lastSetAt: setAt) != nil
    }

}

#Preview(traits: .sampleData) {
    ProfileSheetView()
}
