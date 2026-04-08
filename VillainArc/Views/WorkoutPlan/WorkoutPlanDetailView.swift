import SwiftUI
import SwiftData
import AppIntents
import CoreSpotlight

struct WorkoutPlanDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(WorkoutSplit.active) private var activeSplits: [WorkoutSplit]
    @Query private var completedSessions: [WorkoutSession]
    @Bindable var plan: WorkoutPlan
    @Query(AppSettings.single) private var appSettings: [AppSettings]
    private let router = AppRouter.shared

    private var weightUnit: WeightUnit { appSettings.first?.weightUnit ?? .lbs }
    private let onSelect: (() -> Void)?
    private let showsUseOnly: Bool

    @State private var showDeleteWorkoutPlanConfirmation = false
    @State private var showSuggestionsSheet = false
    @State private var suggestionsInitialTab: WorkoutPlanSuggestionsSheet.Tab = .toReview
    @State private var focusedSuggestionExerciseID: UUID?

    init(plan: WorkoutPlan, showsUseOnly: Bool = false, onSelect: (() -> Void)? = nil) {
        self.plan = plan
        self.showsUseOnly = showsUseOnly
        self.onSelect = onSelect
        _completedSessions = Query(WorkoutSession.completedSessions(forWorkoutPlanID: plan.id))
    }

    private var isTodaysActiveSplitPlan: Bool {
        guard let activeSplit = activeSplits.first else { return false }
        let resolution = SplitScheduleResolver.resolve(activeSplit, context: context, syncProgress: false)
        guard !resolution.isPaused, let todaysPlan = resolution.workoutPlan else { return false }
        return todaysPlan.id == plan.id
    }

    private var toReviewSuggestionSections: [ExerciseSuggestionSection] {
        groupSuggestions(pendingSuggestionEvents(for: plan, in: context))
    }

    private var awaitingOutcomeSuggestionSections: [ExerciseSuggestionSection] {
        groupSuggestions(pendingOutcomeSuggestionEvents(for: plan, in: context))
    }

    private var hasSuggestionsSheetContent: Bool {
        !toReviewSuggestionSections.isEmpty || !awaitingOutcomeSuggestionSections.isEmpty
    }

    private var averageDurationText: String? {
        let durations = completedSessions.map(\.totalDuration).filter { $0 > 0 }
        guard !durations.isEmpty else { return nil }
        return secondsToTimeWithHours(Int((durations.reduce(0, +) / Double(durations.count)).rounded()))
    }

    private var averageActiveEnergyText: String? {
        let activeEnergies = completedSessions.compactMap { $0.healthWorkout?.activeEnergyBurned }
        guard !activeEnergies.isEmpty else { return nil }
        return "\(Int((activeEnergies.reduce(0, +) / Double(activeEnergies.count)).rounded())) cal"
    }

    private var averageTotalEnergyText: String? {
        let totalEnergies = completedSessions.compactMap { $0.healthWorkout?.totalEnergyBurned }
        guard !totalEnergies.isEmpty else { return nil }
        return "\(Int((totalEnergies.reduce(0, +) / Double(totalEnergies.count)).rounded())) cal"
    }

    private var summaryItems: [SummaryStatItem] {
        var items = [SummaryStatItem(title: "Exercises", value: "\(plan.totalExercises)"), SummaryStatItem(title: "Sets", value: "\(plan.totalSets)")]
        if plan.totalVolume > 0 { items.append(SummaryStatItem(title: "Total Volume", value: formattedWeightText(plan.totalVolume, unit: weightUnit, fractionDigits: 0...1))) }
        if let averageDurationText { items.append(SummaryStatItem(title: "Avg Duration", value: averageDurationText)) }
        if let averageActiveEnergyText { items.append(SummaryStatItem(title: "Avg Active Energy", value: averageActiveEnergyText)) }
        if let averageTotalEnergyText { items.append(SummaryStatItem(title: "Avg Total Energy", value: averageTotalEnergyText)) }
        return items
    }

    private var muscleDistributionSlices: [MuscleDistributionSlice] {
        MuscleDistributionCalculator.slices(for: plan)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                summarySection

                if !plan.notes.isEmpty {
                    notesSection
                }

                if !muscleDistributionSlices.isEmpty {
                    muscleDistributionSection
                }

                exercisesSection
            }
            .fontDesign(.rounded)
            .padding(.horizontal)
            .padding(.vertical, 20)
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanDetailList)
        .navigationTitle(plan.title)
        .navigationSubtitle(Text(plan.musclesTargeted()))
        .toolbarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSuggestionsSheet) {
            WorkoutPlanSuggestionsSheet(plan: plan, initialTab: suggestionsInitialTab, initialFocusedExerciseID: focusedSuggestionExerciseID)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if hasSuggestionsSheetContent && onSelect == nil {
                    Button {
                        openSuggestionsSheet(tab: toReviewSuggestionSections.isEmpty ? .awaitingOutcome : .toReview, focusedExerciseID: nil)
                    } label: {
                        Image(systemName: "sparkles")
                            .accessibilityHidden(true)
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanDetailSuggestionsButton)
                    .accessibilityLabel(AccessibilityText.workoutPlanDetailSuggestionsLabel)
                    .accessibilityHint(AccessibilityText.workoutPlanDetailSuggestionsHint)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if let onSelect {
                    Button("Select") {
                        Haptics.selection()
                        onSelect()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanDetailSelectButton)
                    .accessibilityHint(AccessibilityText.workoutPlanDetailSelectHint)
                } else if !showsUseOnly {
                    Menu("Options", systemImage: "ellipsis") {
                        Button("Edit Plan", systemImage: "pencil") {
                            router.editWorkoutPlan(plan)
                        }
                        .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanDetailEditButton)
                        .accessibilityHint(AccessibilityText.workoutPlanDetailEditHint)

                        Button("Delete Workout Plan", systemImage: "trash", role: .destructive) {
                            showDeleteWorkoutPlanConfirmation = true
                        }
                        .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanDetailDeleteButton)
                        .accessibilityHint(AccessibilityText.workoutPlanDetailDeleteHint)
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanDetailOptionsMenu)
                    .accessibilityHint(AccessibilityText.workoutPlanDetailOptionsMenuHint)
                    .confirmationDialog("Delete Workout Plan?", isPresented: $showDeleteWorkoutPlanConfirmation) {
                        Button("Delete", role: .destructive) {
                            deleteWorkoutPlan()
                        }
                        .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanDetailConfirmDeleteButton)
                    } message: {
                        Text("Are you sure you want to delete this workout plan?")
                    }
                }
            }
            ToolbarItem(placement: .bottomBar) {
                Button(plan.favorite ? "Undo" : "Favorite", systemImage: plan.favorite ? "star.fill" : "star.slash.fill") {
                    Haptics.selection()
                    plan.favorite.toggle()
                    saveContext(context: context)
                    Task { await IntentDonations.donateToggleWorkoutPlanFavorite(workoutPlan: plan) }
                }
                .tint(plan.favorite ? .yellow : .primary)
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanDetailFavoriteButton)
                .accessibilityLabel(AccessibilityText.workoutPlanDetailFavoriteLabel(isFavorite: plan.favorite))
                .accessibilityHint(AccessibilityText.workoutPlanDetailFavoriteHint)
            }
            ToolbarSpacer(.flexible, placement: .bottomBar)
            ToolbarItem(placement: .bottomBar) {
                if onSelect == nil {
                    Button("Start Workout", systemImage: "figure.strengthtraining.traditional") {
                        router.startWorkoutSession(from: plan)
                        Task {
                            await IntentDonations.donateStartWorkoutWithPlan(workoutPlan: plan)
                            if isTodaysActiveSplitPlan {
                                await IntentDonations.donateStartTodaysWorkout()
                            }
                        }
                        dismiss()
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanDetailStartWorkoutButton)
                    .accessibilityHint(AccessibilityText.workoutPlanDetailStartWorkoutHint)
                }
            }
        }
        .userActivity("com.villainarc.workoutPlan.view", element: plan) { plan, activity in
            activity.title = plan.title
            activity.isEligibleForSearch = true
            activity.isEligibleForPrediction = true
            activity.persistentIdentifier = NSUserActivityPersistentIdentifier(SpotlightIndexer.workoutPlanIdentifier(for: plan.id))
            let attributeSet = activity.contentAttributeSet ?? CSSearchableItemAttributeSet(contentType: .item)
            attributeSet.relatedUniqueIdentifier = SpotlightIndexer.workoutPlanIdentifier(for: plan.id)
            activity.contentAttributeSet = attributeSet
            let entity = WorkoutPlanEntity(workoutPlan: plan)
            activity.appEntityIdentifier = .init(for: entity)
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Summary")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12, alignment: .top)], spacing: 12) {
                ForEach(summaryItems) { item in
                    SummaryStatCard(title: item.title, text: item.value)
                }
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Plan Notes")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text(plan.notes)
                    .multilineTextAlignment(.leading)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanDetailNotesText)
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

            ForEach(plan.sortedExercises) { exercise in
                WorkoutPlanDetailExerciseCard(exercise: exercise, weightUnit: weightUnit, pendingCount: pendingSuggestionCount(for: exercise), showsPendingCount: onSelect == nil, onOpenSuggestions: { openSuggestionsSheet(tab: .toReview, focusedExerciseID: exercise.id) })
            }
        }
    }

    private func deleteWorkoutPlan() {
        Haptics.selection()
        let deletedPlan = plan
        let linkedSplits = SpotlightIndexer.linkedWorkoutSplits(for: plan)
        SpotlightIndexer.deleteWorkoutPlan(id: plan.id)
        plan.deleteWithSuggestionCleanup(context: context)
        saveContext(context: context)
        SpotlightIndexer.index(workoutSplits: linkedSplits)
        Task { await IntentDonations.donateDeleteWorkoutPlan(workoutPlan: deletedPlan) }
        dismiss()
    }

    private func pendingSuggestionCount(for exercise: ExercisePrescription) -> Int? {
        let count = toReviewSuggestionSections.first(where: { $0.exercisePrescription.id == exercise.id })?.groups.count ?? 0
        return count > 0 ? count : nil
    }

    private func openSuggestionsSheet(tab: WorkoutPlanSuggestionsSheet.Tab, focusedExerciseID: UUID?) {
        suggestionsInitialTab = tab
        focusedSuggestionExerciseID = focusedExerciseID
        showSuggestionsSheet = true
    }
}

private struct WorkoutPlanDetailExerciseCard: View {
    let exercise: ExercisePrescription
    let weightUnit: WeightUnit
    let pendingCount: Int?
    let showsPendingCount: Bool
    let onOpenSuggestions: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(exercise.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    if let repRange = exercise.repRange, repRange.activeMode != .notSet {
                        Text(repRange.displayText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if showsPendingCount, let pendingCount {
                    Button(action: onOpenSuggestions) {
                        Text("\(pendingCount)")
                            .bold()
                            .padding(1)
                    }
                    .buttonBorderShape(.circle)
                    .buttonStyle(.glass)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanDetailSuggestionCount(exercise))
                    .accessibilityLabel(AccessibilityText.workoutPlanDetailSuggestionCountLabel(count: pendingCount))
                }
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanDetailExerciseHeader(exercise))

            if !exercise.notes.isEmpty {
                Text(exercise.notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanDetailExerciseNotes(exercise))
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
                        WorkoutPlanDetailSetIndicator(set: set)
                            .gridColumnAlignment(.leading)
                        Spacer()
                        Text(set.targetReps > 0 ? "\(set.targetReps)" : "-")
                            .gridColumnAlignment(set.targetReps > 0 ? .leading : .center)
                        Spacer()
                        Text(set.targetWeight > 0 ? formattedWeightText(set.targetWeight, unit: weightUnit) : "-")
                            .gridColumnAlignment(set.targetWeight > 0 ? .leading : .center)
                        Spacer()
                        Text(set.targetRest > 0 ? secondsToTime(set.targetRest) : "-")
                            .gridColumnAlignment(set.targetRest > 0 ? .leading : .center)
                    }
                    .font(.body)
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanDetailSet(exercise, set: set))
                    .accessibilityLabel(AccessibilityText.exerciseSetLabel(for: set))
                    .accessibilityValue(AccessibilityText.exerciseSetValue(for: set, unit: weightUnit))
                }
            }
        }
        .padding(16)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanDetailExercise(exercise))
    }
}

private struct WorkoutPlanDetailSetIndicator: View {
    let set: SetPrescription

    var body: some View {
        Text(set.type == .working ? String(set.index + 1) : set.type.shortLabel)
            .foregroundStyle(set.type.tintColor)
            .overlay(alignment: .topTrailing) {
                if let visibleTargetRPE = set.visibleTargetRPE {
                    RPEBadge(value: visibleTargetRPE, style: .target)
                        .offset(x: 7, y: -7)
                }
            }
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        WorkoutPlanDetailView(plan: sampleCompletedPlan())
    }
}
