import SwiftUI
import SwiftData
import AppIntents
import CoreSpotlight

struct WorkoutDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    var router = AppRouter.shared
    let workout: WorkoutSession
    @Query(AppSettings.single) private var appSettings: [AppSettings]

    @State private var showDeleteWorkoutConfirmation: Bool = false
    @State private var showPreWorkoutContextSheet = false

    private var weightUnit: WeightUnit { appSettings.first?.weightUnit ?? .lbs }
    private var energyUnit: EnergyUnit { appSettings.first?.energyUnit ?? .systemDefault }

    private var preWorkoutContext: PreWorkoutContext? { workout.preWorkoutContext }
    private var hasPreWorkoutFeeling: Bool {
        guard let feeling = preWorkoutContext?.feeling else { return false }
        return feeling != .notSet
    }
    private var hasPreWorkoutDrink: Bool { preWorkoutContext?.tookPreWorkout == true }

    private var preWorkoutToolbarIdentifier: String? {
        if hasPreWorkoutFeeling { return AccessibilityIdentifiers.workoutDetailPreWorkoutContextButton }
        if hasPreWorkoutDrink { return AccessibilityIdentifiers.workoutDetailPreWorkoutDrinkButton }
        return nil
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                if workout.healthWorkout != nil { WorkoutLinkedHealthDetailSection(workout: workout, weightUnit: weightUnit, energyUnit: energyUnit) }

                WorkoutSessionDetailContent(workout: workout, weightUnit: weightUnit)
            }
            .fontDesign(.rounded)
            .padding(.horizontal)
            .padding(.vertical, 20)
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.workoutDetailList)
        .navigationTitle(workout.title)
        .navigationSubtitle(Text(formattedDateRange(start: workout.startedAt, end: workout.endedAt, includeTime: true)))
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu("Options", systemImage: "ellipsis") {
                    if let linkedPlan = workout.workoutPlan {
                        Button("Open Workout Plan", systemImage: "arrowshape.turn.up.right") {
                            openWorkoutPlan(linkedPlan)
                        }
                        .accessibilityIdentifier(AccessibilityIdentifiers.workoutDetailOpenWorkoutPlanButton)
                        .accessibilityHint(AccessibilityText.workoutDetailOpenWorkoutPlanHint)
                    } else {
                        Button("Save as Workout Plan", systemImage: "list.clipboard") {
                            saveWorkoutAsPlan()
                        }
                        .accessibilityIdentifier(AccessibilityIdentifiers.workoutDetailSaveWorkoutPlanButton)
                        .accessibilityHint(AccessibilityText.workoutDetailSaveWorkoutPlanHint)
                    }
                    Button("Delete Workout", systemImage: "trash", role: .destructive) {
                        showDeleteWorkoutConfirmation = true
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutDetailDeleteButton)
                    .accessibilityHint(AccessibilityText.workoutDetailDeleteHint)
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutDetailOptionsMenu)
                .accessibilityHint(AccessibilityText.workoutDetailOptionsMenuHint)
                .confirmationDialog("Delete Workout", isPresented: $showDeleteWorkoutConfirmation) {
                    Button("Delete", role: .destructive) {
                        deleteWorkout()
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutDetailConfirmDeleteButton)
                } message: {
                    Text("Are you sure you want to delete this workout?")
                }
            }
            ToolbarItemGroup(placement: .bottomBar) {
                if let preWorkoutToolbarIdentifier {
                    Button {
                        showPreWorkoutContextSheet = true
                    } label: {
                        preWorkoutToolbarIcon
                    }
                    .accessibilityIdentifier(preWorkoutToolbarIdentifier)
                    .accessibilityLabel(AccessibilityText.workoutDetailPreWorkoutContextLabel)
                    .accessibilityValue(preWorkoutAccessibilityValue)
                    .accessibilityHint(AccessibilityText.workoutDetailPreWorkoutContextHint)
                }
            }
        }
        .sheet(isPresented: $showPreWorkoutContextSheet) {
            NavigationStack {
                List {
                    if hasPreWorkoutFeeling, let preWorkoutContext {
                        LabeledContent("Felt", value: preWorkoutContext.feeling.displayName)
                    }
                    if hasPreWorkoutDrink {
                        LabeledContent("Took pre workout", value: "Yes")
                    }
                }
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                .navigationTitle("Pre Workout Context")
                .toolbarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .close) {
                            showPreWorkoutContextSheet = false
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
        .userActivity("com.villainarc.workoutSession.view", element: workout) { session, activity in
            activity.title = session.title
            activity.isEligibleForSearch = true
            activity.isEligibleForPrediction = true
            activity.persistentIdentifier = NSUserActivityPersistentIdentifier(SpotlightIndexer.workoutSessionIdentifier(for: session.id))
            let attributeSet = activity.contentAttributeSet ?? CSSearchableItemAttributeSet(contentType: .item)
            attributeSet.relatedUniqueIdentifier = SpotlightIndexer.workoutSessionIdentifier(for: session.id)
            activity.contentAttributeSet = attributeSet
            let entity = WorkoutSessionEntity(workoutSession: session)
            activity.appEntityIdentifier = .init(for: entity)
        }
    }

    private func deleteWorkout() {
        Haptics.selection()
        let deletedWorkout = workout
        WorkoutDeletionCoordinator.deleteCompletedWorkouts([workout], context: context, settings: appSettings.first)

        Task { await IntentDonations.donateDeleteWorkout(workout: deletedWorkout) }

        dismiss()
    }

    private func saveWorkoutAsPlan() {
        guard workout.workoutPlan == nil else { return }
        router.createWorkoutPlan(from: workout)
    }

    private func openWorkoutPlan(_ plan: WorkoutPlan) {
        Haptics.selection()
        router.popToRoot()
        router.navigate(to: .workoutPlanDetail(plan, false))
        Task { await IntentDonations.donateOpenWorkoutPlan(workoutPlan: plan) }
    }

    private var preWorkoutAccessibilityValue: String {
        var parts: [String] = []

        if hasPreWorkoutFeeling, let feeling = preWorkoutContext?.feeling.displayName {
            parts.append(feeling)
        }
        if hasPreWorkoutDrink { parts.append("Pre workout taken") }

        return parts.joined(separator: ". ")
    }

    @ViewBuilder
    private var preWorkoutToolbarIcon: some View {
        if hasPreWorkoutFeeling, let preWorkoutContext {
            Text(preWorkoutContext.feeling.emoji)
                .font(.title)
                .frame(width: 28, height: 28)
        } else if hasPreWorkoutDrink {
            Image(systemName: "bolt.fill")
                .foregroundStyle(.yellow)
                .accessibilityHidden(true)
        }
    }
}

private struct WorkoutLinkedHealthDetailSection: View {
    let workout: WorkoutSession
    let weightUnit: WeightUnit
    let energyUnit: EnergyUnit
    @Query(AppSettings.single) private var appSettings: [AppSettings]
    @Query(UserProfile.single) private var userProfiles: [UserProfile]
    @State private var loader: HealthWorkoutDetailLoader

    init(workout: WorkoutSession, weightUnit: WeightUnit, energyUnit: EnergyUnit) {
        self.workout = workout
        self.weightUnit = weightUnit
        self.energyUnit = energyUnit
        _loader = State(initialValue: HealthWorkoutDetailLoader(workout: workout.healthWorkout!))
    }

    private var distanceUnit: DistanceUnit {
        appSettings.first?.distanceUnit ?? .systemDefault
    }

    private var estimatedMaxHeartRate: Double? {
        guard let birthday = userProfiles.first?.birthday else { return nil }
        let years = Calendar.current.dateComponents([.year], from: birthday, to: loader.summary.startDate).year ?? 0
        let age = max(1, years)
        return max(120, Double(220 - age))
    }

    private var workoutSummaryItems: [SummaryStatItem] {
        var items = [SummaryStatItem(title: "Exercises", value: "\(workout.totalExercises)"), SummaryStatItem(title: "Sets", value: "\(workout.totalSets)")]
        if workout.totalVolume > 0 { items.append(SummaryStatItem(title: "Volume", value: formattedWeightText(workout.totalVolume, unit: weightUnit, fractionDigits: 0...1))) }
        return items
    }

    private var effortCardModel: WorkoutEffortCardModel? {
        guard let summary = loader.effortSummary else { return nil }

        switch summary.source {
        case .actualScore, .estimatedScore:
            let roundedScore = max(1, min(Int(summary.value.rounded()), 10))
            return .init(title: workoutEffortTitle(roundedScore), description: workoutEffortDescription(roundedScore), valueText: summary.value.formatted(.number.precision(.fractionLength(0...1))), score: summary.value, caption: summary.source == .estimatedScore ? "Estimated from Apple Health" : nil)
        case .physicalEffort:
            return .init(title: "Physical Effort", description: "Average estimated physical effort was \(summary.value.formatted(.number.precision(.fractionLength(0...1)))) METs.", valueText: summary.value.formatted(.number.precision(.fractionLength(0...1))), score: nil, caption: "From Apple Health")
        }
    }

    var body: some View {
        HealthWorkoutDetailContent(loader: loader, distanceUnit: distanceUnit, energyUnit: energyUnit, estimatedMaxHeartRate: estimatedMaxHeartRate, extraSummaryItems: workoutSummaryItems, effortCardModel: effortCardModel)
        .task(id: workout.healthWorkout?.healthWorkoutUUID) {
            await loader.loadIfNeeded(distanceUnit: distanceUnit, estimatedMaxHeartRate: estimatedMaxHeartRate)
        }
    }
}

private struct WorkoutSessionDetailContent: View {
    let workout: WorkoutSession
    let weightUnit: WeightUnit

    private var muscleDistributionSlices: [MuscleDistributionSlice] {
        MuscleDistributionCalculator.slices(for: workout)
    }

    private var summaryColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 130), spacing: 12, alignment: .top)]
    }

    private var durationText: String {
        let endDate = workout.endedAt ?? .now
        let totalSeconds = max(0, Int(endDate.timeIntervalSince(workout.startedAt).rounded()))
        return secondsToTimeWithHours(totalSeconds)
    }

    private var summaryItems: [(title: String, value: String)] {
        var items: [(String, String)] = [
            ("Exercises", "\(workout.totalExercises)"),
            ("Sets", "\(workout.totalSets)")
        ]

        if workout.totalVolume > 0 {
            items.append(("Volume", formattedWeightText(workout.totalVolume, unit: weightUnit, fractionDigits: 0...1)))
        }

        if workout.healthWorkout == nil {
            items.append(("Duration", durationText))
        }

        return items
    }

    private var effortCardModel: WorkoutEffortCardModel? {
        guard (1...10).contains(workout.postEffort) else { return nil }
        return .init(title: workoutEffortTitle(workout.postEffort), description: workoutEffortDescription(workout.postEffort), valueText: "\(workout.postEffort)", score: Double(workout.postEffort), caption: nil)
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 20) {
            if workout.healthWorkout == nil { workoutSection }

            if !workout.notes.isEmpty {
                notesSection
            }

            if !muscleDistributionSlices.isEmpty {
                muscleDistributionSection
            }

            exercisesSection
        }
    }

    private var workoutSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(workout.healthWorkout == nil ? "Summary" : "Workout")
                .font(.headline)

            LazyVGrid(columns: summaryColumns, spacing: 12) {
                ForEach(summaryItems, id: \.title) { item in
                    SummaryStatCard(title: item.title, text: item.value)
                }
            }

            if let effortCardModel {
                WorkoutEffortCardView(model: effortCardModel)
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutDetailEffortDisplay)
                    .accessibilityLabel(AccessibilityText.workoutDetailEffortLabel)
                    .accessibilityValue("\(workout.postEffort)/10. \(workoutEffortDescription(workout.postEffort))")
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workout Notes")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text(workout.notes)
                    .multilineTextAlignment(.leading)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutDetailNotesText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var muscleDistributionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Muscle Distribution")
                .font(.headline)

            MuscleDistributionView(slices: muscleDistributionSlices)
                .padding(16)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Exercises")
                .font(.headline)

            ForEach(workout.sortedExercises) { exercise in
                WorkoutDetailExerciseCard(exercise: exercise, weightUnit: weightUnit)
            }
        }
    }
}

struct SummaryStatItem: Identifiable {
    let title: String
    let value: String

    var id: String { "\(title)-\(value)" }
}

private struct WorkoutDetailExerciseCard: View {
    let exercise: ExercisePerformance
    let weightUnit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                Text(exercise.name)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                if let repRange = exercise.repRange {
                    Text(repRange.displayText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.workoutDetailExerciseHeader(exercise))

            if !exercise.notes.isEmpty {
                Text(exercise.notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutDetailExerciseNotes(exercise))
            }

            Divider()

            Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                GridRow {
                    Text("Set")
                    Spacer()
                    Text("Reps")
                    Spacer()
                    Text("Weight")
                    Spacer()
                    Text("Rest")
                }
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

                ForEach(exercise.sortedSets) { set in
                    GridRow {
                        WorkoutDetailSetIndicator(set: set)
                            .gridColumnAlignment(.leading)
                        Spacer()

                        Text(set.reps > 0 ? "\(set.reps)" : "-")
                            .gridColumnAlignment(set.reps > 0 ? .leading : .center)
                        Spacer()

                        Text(set.weight > 0 ? formattedWeightText(set.weight, unit: weightUnit) : "-")
                            .gridColumnAlignment(set.weight > 0 ? .leading : .center)
                        Spacer()

                        Text(set.effectiveRestSeconds > 0 ? secondsToTime(set.effectiveRestSeconds) : "-")
                            .gridColumnAlignment(set.effectiveRestSeconds > 0 ? .leading : .center)
                    }
                    .font(.body)
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutDetailSet(exercise, set: set))
                    .accessibilityLabel(AccessibilityText.exerciseSetLabel(for: set))
                    .accessibilityValue(AccessibilityText.exerciseSetValue(for: set, unit: weightUnit))
                }
            }
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityIdentifier(AccessibilityIdentifiers.workoutDetailExercise(exercise))
    }
}

private struct WorkoutDetailSetIndicator: View {
    let set: SetPerformance

    var body: some View {
        Text(set.type == .working ? String(set.index + 1) : set.type.shortLabel)
            .foregroundStyle(set.type.tintColor)
            .overlay(alignment: .topTrailing) {
                if let visibleRPE = set.visibleRPE {
                    RPEBadge(value: visibleRPE)
                        .offset(x: 7, y: -7)
                }
            }
    }
}

#Preview {
    NavigationStack {
        WorkoutDetailView(workout: sampleCompletedSession())
    }
    .sampleDataContainer()
}
