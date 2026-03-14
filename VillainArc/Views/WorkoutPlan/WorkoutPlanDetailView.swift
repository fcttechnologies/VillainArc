import SwiftUI
import SwiftData
import AppIntents
import CoreSpotlight

struct WorkoutPlanDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var splits: [WorkoutSplit]
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
    }

    private var isTodaysActiveSplitPlan: Bool {
        guard let activeSplit = splits.first(where: { $0.isActive }),
              let todaysPlan = activeSplit.todaysSplitDay?.workoutPlan else {
            return false
        }
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

    var body: some View {
        List {
            if !plan.notes.isEmpty {
                Section("Plan Notes") {
                    Text(plan.notes)
                        .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanDetailNotesText)
                }
            }

            ForEach(plan.sortedExercises) { exercise in
                Section {
                    Grid(verticalSpacing: 8) {
                        GridRow {
                            Text("Set")
                            Spacer()
                            Text("Reps")
                            Spacer()
                            Text("Weight")
                            Spacer()
                            Text("Rest")
                        }
                        .font(.title3)
                        .bold()
                        .accessibilityHidden(true)

                        ForEach(exercise.sortedSets) { set in
                            GridRow {
                                setIndicator(for: set)
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
                            .font(.title3)
                            .accessibilityElement(children: .ignore)
                            .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanDetailSet(exercise, set: set))
                            .accessibilityLabel(AccessibilityText.exerciseSetLabel(for: set))
                            .accessibilityValue(AccessibilityText.exerciseSetValue(for: set, unit: weightUnit))
                        }
                    }
                } header: {
                    HStack {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(exercise.name)
                                .lineLimit(1)
                            if let repRange = exercise.repRange, repRange.activeMode != .notSet {
                                Text(repRange.displayText)
                                    .font(.subheadline)
                            }
                        }
                        Spacer()
                        if let pendingCount = pendingSuggestionCount(for: exercise), onSelect == nil {
                            Button {
                                openSuggestionsSheet(tab: .toReview, focusedExerciseID: exercise.id)
                            } label: {
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
                } footer: {
                    if !exercise.notes.isEmpty {
                        Text("Notes: \(exercise.notes)")
                            .multilineTextAlignment(.leading)
                            .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanDetailExerciseNotes(exercise))
                    }
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanDetailExercise(exercise))
            }
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
                        openSuggestionsSheet(
                            tab: toReviewSuggestionSections.isEmpty ? .awaitingOutcome : .toReview,
                            focusedExerciseID: nil
                        )
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

    @ViewBuilder
    private func setIndicator(for set: SetPrescription) -> some View {
        Text(set.type == .working ? String(set.index + 1) : set.type.shortLabel)
            .foregroundStyle(set.type.tintColor)
            .overlay(alignment: .topTrailing) {
                if let visibleTargetRPE = set.visibleTargetRPE {
                    RPEBadge(value: visibleTargetRPE, style: .target)
                        .offset(x: 7, y: -7)
                }
            }
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

#Preview {
    NavigationStack {
        WorkoutPlanDetailView(plan: sampleCompletedPlan())
    }
    .sampleDataContainer()
}
