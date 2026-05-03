import SwiftUI
import SwiftData
import AppIntents
import CoreSpotlight

struct WorkoutPlanDetailView: View {
    struct SplitAssignmentActions {
        let canUsePlan: Bool
        let onChangePlan: () -> Void
        let onClearPlan: () -> Void
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var completedSessions: [WorkoutSession]
    @Bindable var plan: WorkoutPlan
    @Query(AppSettings.single) private var appSettings: [AppSettings]
    private let router = AppRouter.shared

    private var weightUnit: WeightUnit { appSettings.first?.weightUnit ?? .lbs }
    private let onSelect: (() -> Void)?
    private let showsUseOnly: Bool
    private let showSheetBackground: Bool
    private let showsCloseButton: Bool
    private let splitAssignmentActions: SplitAssignmentActions?

    @State private var showDeleteWorkoutPlanConfirmation = false
    @State private var deleteWorkoutPlanAssessment: WorkoutPlanDeletionCoordinator.Assessment?
    @State private var showSuggestionsSheet = false
    @State private var suggestionsInitialTab: WorkoutPlanSuggestionsSheet.Tab = .toReview
    @State private var focusedSuggestionExerciseID: UUID?
    @State private var isDeletingWorkoutPlan = false

    private var isSplitAssignmentPreview: Bool {
        splitAssignmentActions != nil
    }

    init(plan: WorkoutPlan, showsUseOnly: Bool = false, onSelect: (() -> Void)? = nil, showSheetBackground: Bool = false, showsCloseButton: Bool = false, splitAssignmentActions: SplitAssignmentActions? = nil) {
        self.plan = plan
        self.showsUseOnly = showsUseOnly
        self.onSelect = onSelect
        self.showSheetBackground = showSheetBackground
        self.showsCloseButton = showsCloseButton
        self.splitAssignmentActions = splitAssignmentActions
        _completedSessions = Query(WorkoutSession.completedSessions(forWorkoutPlanID: plan.id))
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
        Group {
            if isDeletingWorkoutPlan {
                Color.clear
                    .modifier(WorkoutPlanDetailBackgroundModifier(showSheetBackground: showSheetBackground))
            } else {
                detailContent
            }
        }
    }

    private var detailContent: some View {
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
            .quickActionContentBottomInset()
            .scrollIndicators(.hidden)
            .modifier(WorkoutPlanDetailBackgroundModifier(showSheetBackground: showSheetBackground))
            .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanDetailList)
            .navigationTitle(plan.title)
            .navigationSubtitle(Text(plan.musclesTargeted()))
            .toolbarTitleDisplayMode(.inline)
            .sheet(isPresented: $showSuggestionsSheet) {
                WorkoutPlanSuggestionsSheet(plan: plan, initialTab: suggestionsInitialTab, initialFocusedExerciseID: focusedSuggestionExerciseID)
                    .presentationBackground(Color.sheetBg)
            }
            .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if showsCloseButton {
                    Button("Close", systemImage: "xmark", role: .close) {
                        Haptics.selection()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if hasSuggestionsSheetContent && onSelect == nil && !isSplitAssignmentPreview {
                    Button {
                        Haptics.selection()
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
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if let splitAssignmentActions, splitAssignmentActions.canUsePlan {
                    Button("Use Plan", systemImage: "figure.strengthtraining.traditional") {
                        startWorkoutFromPlan()
                    }
                    .labelStyle(.iconOnly)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanDetailUseButton)
                    .accessibilityLabel("Use Plan")
                    .accessibilityHint(AccessibilityText.workoutPlanDetailStartWorkoutHint)
                } else if onSelect == nil, !isSplitAssignmentPreview {
                    Button("Use Plan", systemImage: "figure.strengthtraining.traditional") {
                        startWorkoutFromPlan()
                    }
                    .labelStyle(.iconOnly)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanDetailUseButton)
                    .accessibilityLabel("Use Plan")
                    .accessibilityHint(AccessibilityText.workoutPlanDetailStartWorkoutHint)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if let splitAssignmentActions {
                    Menu("Plan Actions", systemImage: "ellipsis") {
                        Button("Change Plan", systemImage: "arrow.triangle.2.circlepath") {
                            Haptics.selection()
                            splitAssignmentActions.onChangePlan()
                        }

                        Button("Clear Plan", systemImage: "xmark.circle", role: .destructive) {
                            Haptics.selection()
                            splitAssignmentActions.onClearPlan()
                        }
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if onSelect == nil, !showsUseOnly && !isSplitAssignmentPreview {
                    Menu("Options", systemImage: "ellipsis") {
                        Button(plan.favorite ? "Unfavorite" : "Favorite", systemImage: plan.favorite ? "star.fill" : "star") {
                            toggleFavorite()
                        }
                        .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanDetailFavoriteButton)
                        .accessibilityLabel(AccessibilityText.workoutPlanDetailFavoriteLabel(isFavorite: plan.favorite))
                        .accessibilityHint(AccessibilityText.workoutPlanDetailFavoriteHint)

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
                            confirmDeleteWorkoutPlan()
                        }
                        .accessibilityIdentifier(AccessibilityIdentifiers.workoutPlanDetailConfirmDeleteButton)
                    } message: {
                        Text("Are you sure you want to delete this workout plan?")
                    }
                    .alert(deleteWorkoutPlanAssessment?.confirmationTitle ?? "Delete Workout Plan?", isPresented: deleteWorkoutPlanAlertBinding) {
                        Button(deleteWorkoutPlanAssessment?.destructiveButtonTitle ?? "Delete", role: .destructive) {
                            guard let deleteWorkoutPlanAssessment else { return }
                            performDeleteWorkoutPlan(using: deleteWorkoutPlanAssessment)
                        }
                        Button("Cancel", role: .cancel) {
                            deleteWorkoutPlanAssessment = nil
                        }
                    } message: {
                        Text(deleteWorkoutPlanAssessment?.confirmationMessage ?? "")
                    }
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

private struct WorkoutPlanDetailBackgroundModifier: ViewModifier {
    let showSheetBackground: Bool

    func body(content: Content) -> some View {
        if showSheetBackground {
            content.sheetBackground()
        } else {
            content.appBackground()
        }
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
            .appCardStyle()
        }
    }

    private var muscleDistributionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Muscle Distribution")
                .font(.headline)

            MuscleDistributionView(slices: muscleDistributionSlices)
                .padding(16)
                .appCardStyle()
        }
    }

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Exercises")
                .font(.headline)

            ForEach(exerciseSnapshots) { exercise in
                WorkoutPlanDetailExerciseCard(
                    exercise: exercise,
                    weightUnit: weightUnit,
                    showsPendingCount: onSelect == nil,
                    onOpenSuggestions: { openSuggestionsSheet(tab: .toReview, focusedExerciseID: exercise.id) }
                )
            }
        }
    }

    private func confirmDeleteWorkoutPlan() {
        let assessment = WorkoutPlanDeletionCoordinator.assess(plans: [plan], context: context)
        if assessment.requiresWarning {
            deleteWorkoutPlanAssessment = assessment
            return
        }
        performDeleteWorkoutPlan(using: assessment)
    }

    private func performDeleteWorkoutPlan(using assessment: WorkoutPlanDeletionCoordinator.Assessment) {
        deleteWorkoutPlanAssessment = nil
        Haptics.selection()
        let deletedPlan = WorkoutPlanEntity(workoutPlan: plan)
        isDeletingWorkoutPlan = true
        WorkoutPlanDeletionCoordinator.delete(assessment, context: context)
        Task { await IntentDonations.donateDeleteWorkoutPlan(workoutPlan: deletedPlan) }
        dismiss()
    }

    private var deleteWorkoutPlanAlertBinding: Binding<Bool> {
        Binding(
            get: { deleteWorkoutPlanAssessment != nil },
            set: { isPresented in
                if !isPresented {
                    deleteWorkoutPlanAssessment = nil
                }
            }
        )
    }

    private func startWorkoutFromPlan() {
        router.startWorkoutSession(from: plan)
        Task {
            await IntentDonations.donateStartWorkoutWithPlan(workoutPlan: plan)
            if router.isTodaysActiveSplitPlan(plan) {
                await IntentDonations.donateStartTodaysWorkout()
            }
        }
    }

    private func toggleFavorite() {
        Haptics.selection()
        plan.favorite.toggle()
        saveContext(context: context)
        Task { await IntentDonations.donateToggleWorkoutPlanFavorite(workoutPlan: plan) }
    }

    private var pendingSuggestionCountsByExerciseID: [UUID: Int] {
        Dictionary(uniqueKeysWithValues: toReviewSuggestionSections.compactMap { section in
            let count = section.groups.count
            return count > 0 ? (section.exercisePrescription.id, count) : nil
        })
    }

    private var exerciseSnapshots: [WorkoutPlanDetailExerciseSnapshot] {
        let pendingCounts = pendingSuggestionCountsByExerciseID
        let planID = plan.id
        return plan.sortedExercises.map { exercise in
            WorkoutPlanDetailExerciseSnapshot(exercise: exercise, planID: planID, pendingCount: pendingCounts[exercise.id])
        }
    }

    private func openSuggestionsSheet(tab: WorkoutPlanSuggestionsSheet.Tab, focusedExerciseID: UUID?) {
        suggestionsInitialTab = tab
        focusedSuggestionExerciseID = focusedExerciseID
        showSuggestionsSheet = true
    }
}

private struct WorkoutPlanDetailExerciseSnapshot: Identifiable {
    let id: UUID
    let planID: UUID
    let index: Int
    let catalogID: String
    let name: String
    let notes: String
    let repRangeText: String?
    let pendingCount: Int?
    let sets: [WorkoutPlanDetailSetSnapshot]

    init(exercise: ExercisePrescription, planID: UUID, pendingCount: Int?) {
        id = exercise.id
        self.planID = planID
        index = exercise.index
        catalogID = exercise.catalogID
        name = exercise.name
        notes = exercise.notes
        if let repRange = exercise.repRange, repRange.activeMode != .notSet {
            repRangeText = repRange.displayText
        } else {
            repRangeText = nil
        }
        self.pendingCount = pendingCount
        sets = exercise.sortedSets.map(WorkoutPlanDetailSetSnapshot.init(set:))
    }

    var accessibilityIdentifier: String {
        "workoutPlanDetailExercise-Optional(\"\(planID.uuidString)\")-\(catalogID)-\(index)"
    }

    var headerAccessibilityIdentifier: String {
        "workoutPlanDetailExerciseHeader-Optional(\"\(planID.uuidString)\")-\(catalogID)-\(index)"
    }

    var notesAccessibilityIdentifier: String {
        "workoutPlanDetailExerciseNotes-Optional(\"\(planID.uuidString)\")-\(catalogID)-\(index)"
    }

    var suggestionCountAccessibilityIdentifier: String {
        "workoutPlanDetailSuggestionCount-\(id.uuidString)"
    }

    func setAccessibilityIdentifier(_ set: WorkoutPlanDetailSetSnapshot) -> String {
        "workoutPlanDetailSet-Optional(\"\(planID.uuidString)\")-\(catalogID)-\(index)-\(set.index)"
    }
}

private struct WorkoutPlanDetailSetSnapshot: Identifiable {
    let id: UUID
    let index: Int
    let type: ExerciseSetType
    let targetWeight: Double
    let targetReps: Int
    let targetRest: Int
    let targetRPE: Int

    init(set: SetPrescription) {
        id = set.id
        index = set.index
        type = set.type
        targetWeight = set.targetWeight
        targetReps = set.targetReps
        targetRest = set.targetRest
        targetRPE = set.targetRPE
    }

    var visibleTargetRPE: Int? {
        guard type != .warmup, targetRPE > 0 else { return nil }
        return targetRPE
    }

    var accessibilityLabel: String {
        type == .working ? String(localized: "Set \(index + 1)") : type.displayName
    }

    func accessibilityValue(unit: WeightUnit) -> String {
        let hasReps = targetReps > 0
        let hasWeight = targetWeight > 0
        let hasTargetRPE = visibleTargetRPE != nil
        guard hasReps || hasWeight || hasTargetRPE else { return String(localized: "No target set") }

        let repsText = hasReps ? (targetReps == 1 ? String(localized: "1 rep") : String(localized: "\(targetReps) reps")) : String(localized: "No reps target")
        let weightText = hasWeight ? unit.display(targetWeight) : String(localized: "No weight target")
        if let visibleTargetRPE { return String(localized: "\(repsText), \(weightText), target RPE \(visibleTargetRPE)") }
        return String(localized: "\(repsText), \(weightText)")
    }
}

private struct WorkoutPlanDetailExerciseCard: View {
    let exercise: WorkoutPlanDetailExerciseSnapshot
    let weightUnit: WeightUnit
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
                    if let repRangeText = exercise.repRangeText {
                        Text(repRangeText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if showsPendingCount, let pendingCount = exercise.pendingCount {
                    Button(action: onOpenSuggestions) {
                        Text("\(pendingCount)")
                            .bold()
                            .padding(1)
                    }
                    .buttonBorderShape(.circle)
                    .buttonStyle(.glass)
                    .accessibilityIdentifier(exercise.suggestionCountAccessibilityIdentifier)
                    .accessibilityLabel(AccessibilityText.workoutPlanDetailSuggestionCountLabel(count: pendingCount))
                }
            }
            .accessibilityIdentifier(exercise.headerAccessibilityIdentifier)

            if !exercise.notes.isEmpty {
                Text(exercise.notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .accessibilityIdentifier(exercise.notesAccessibilityIdentifier)
            }

            Divider()

            ExerciseSetTable(rows: exercise.sets, repsText: { $0.targetReps > 0 ? "\($0.targetReps)" : "-" }, weightText: { $0.targetWeight > 0 ? formattedWeightText($0.targetWeight, unit: weightUnit) : "-" }, restText: { $0.targetRest > 0 ? secondsToTime($0.targetRest) : "-" }, rowAccessibilityIdentifier: { exercise.setAccessibilityIdentifier($0) }, rowAccessibilityLabel: { $0.accessibilityLabel }, rowAccessibilityValue: { $0.accessibilityValue(unit: weightUnit) }) { set in
                WorkoutPlanDetailSetIndicator(set: set)
            }
        }
        .padding(16)
        .appCardStyle()
        .accessibilityIdentifier(exercise.accessibilityIdentifier)
    }
}

private struct WorkoutPlanDetailSetIndicator: View {
    let set: WorkoutPlanDetailSetSnapshot

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
