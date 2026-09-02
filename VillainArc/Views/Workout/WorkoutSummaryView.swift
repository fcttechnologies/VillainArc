import FCTMetrics
import SwiftUI
import SwiftData
import StoreKit
import TipKit

struct WorkoutSummaryView: View {
    private enum PRType: String {
        case estimated1RM = "1RM"
        case maxWeight = "Max Weight"
        case maxReps = "Max Reps"
        case totalVolume = "Total Volume"
    }

    private struct PRItem: Identifiable {
        let id = UUID()
        let catalogID: String
        let exerciseName: String
        let types: [PRType]
        let values: [PRType: Double]
    }

    private struct WorkoutExercisePRSummary {
        let catalogID: String
        let exerciseName: String
        let bestEstimated1RM: Double?
        let bestWeight: Double?
        let bestReps: Int?
        let totalVolume: Double
    }

    @Bindable var workout: WorkoutSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var sessionSuggestionEvents: [SuggestionEvent]
    @Query(AppSettings.single) private var appSettings: [AppSettings]
    @Environment(\.requestReview) private var requestReview
    @State private var router = AppRouter.shared

    private var weightUnit: WeightUnit { appSettings.first?.weightUnit ?? .lbs }
    private var energyUnit: EnergyUnit { appSettings.first?.energyUnit ?? .systemDefault }

    @State private var showTitleEditorSheet = false
    @State private var showNotesEditorSheet = false
    @State private var prEntries: [PRItem] = []
    @State private var prItemsByCatalogID: [String: PRItem] = [:]
    @State private var workoutHealthSummaryItems: [SummaryStatItem] = []
    @State private var isGeneratingSuggestions = false
    @State private var isSaving = false
    @State private var didSaveWorkoutAsPlan = false
    @State private var sessionOutcomeSelection: SessionOutcome = .notSet
    @State private var hasRateableSuggestionEvents = false
    @State private var appliedFeedbackEventIDs: Set<UUID> = []
    private let suggestionDeferTip = SuggestionDeferTip()

    private var formattedTotalVolume: String {
        formattedWeightText(workout.totalVolume, unit: weightUnit, fractionDigits: 0...1)
    }

    private var durationText: String {
        let endDate = workout.endedAt ?? .now
        let totalSeconds = max(0, Int(endDate.timeIntervalSince(workout.startedAt)))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return String(localized: "\(hours)h \(minutes)m")
        }
        return String(localized: "\(minutes)m")
    }

    private var shouldShowSuggestions: Bool {
        workout.workoutPlan != nil
    }

    private var prCount: Int {
        prEntries.reduce(0) { $0 + $1.types.count }
    }

    private var suggestionSections: [ExerciseSuggestionSection] {
        groupSuggestions(sessionSuggestionEvents)
    }

    private var pendingSuggestionCount: Int {
        sessionSuggestionEvents.filter { $0.decision == .pending }.count
    }

    init(workout: WorkoutSession) {
        _workout = Bindable(wrappedValue: workout)
        let sessionID = workout.id
        _sessionSuggestionEvents = Query(filter: #Predicate<SuggestionEvent> { $0.sessionFrom?.id == sessionID }, sort: [SortDescriptor(\.createdAt, order: .reverse)])
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 0) {
                        Button {
                            showTitleEditorSheet = true
                        } label: {
                            HStack(spacing: 8) {
                                Text(workout.title)
                                    .font(.title)
                                    .bold()
                                    .lineLimit(1)
                                Image(systemName: "pencil")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                                    .accessibilityHidden(true)
                            }
                            .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(AccessibilityIdentifiers.workoutSummaryTitleButton)
                        .accessibilityLabel(workout.title)
                        .accessibilityHint(AccessibilityText.workoutSummaryTitleHint)

                        Text(formattedDateRange(start: workout.startedAt, end: workout.endedAt, includeTime: true))
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        SummaryStatCard(title: "Exercises", text: "\(workout.totalExercises)")
                        SummaryStatCard(title: "Sets", text: "\(workout.totalSets)")
                        SummaryStatCard(title: "Duration", text: durationText)
                    }

                    if prEntries.isEmpty {
                        SummaryStatCard(title: "Total Volume", text: formattedTotalVolume)
                    } else {
                        HStack(spacing: 12) {
                            SummaryStatCard(title: "Total Volume", text: formattedTotalVolume)
                            SummaryStatCard(title: "New PRs", text: "\(prCount)")
                        }
                    }

                    if !workoutHealthSummaryItems.isEmpty {
                        HStack(spacing: 12) {
                            ForEach(workoutHealthSummaryItems) { item in
                                SummaryStatCard(title: item.title, text: item.value)
                            }
                            .accessibilityIdentifier(AccessibilityIdentifiers.workoutSummaryHealthStatsSection)
                            .accessibilityLabel(AccessibilityText.workoutSummaryHealthStatsLabel)
                        }
                    }

                    Button {
                        showNotesEditorSheet = true
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.headline)
                            if workout.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("Add notes")
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(workout.notes)
                                    .lineLimit(4)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutSummaryNotesButton)
                    .accessibilityLabel(AccessibilityText.workoutSummaryNotesLabel)
                    .accessibilityValue(AccessibilityText.workoutSummaryNotesValue(hasNotes: !workout.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, notes: workout.notes))
                    .accessibilityHint(AccessibilityText.workoutSummaryNotesHint)

                    if (1...10).contains(workout.postEffort) {
                        effortSection
                    }

                    if let hardDayFeeling {
                        hardDaySection(feeling: hardDayFeeling)
                    }

                    if hasRateableSuggestionEvents {
                        outcomeSection
                    }

                    planSaveSection

                    if shouldShowSuggestions {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Suggestions")
                                .font(.headline)
                            if isGeneratingSuggestions {
                                ProgressView("Generating suggestions...")
                                    .frame(maxWidth: .infinity, alignment: .center)
                            } else {
                                SuggestionReviewView(sections: suggestionSections, onAcceptGroup: { changes, rank in
                                    guard !isSaving else { return }
                                    acceptGroup(changes, rank: rank, context: context)
                                }, onRejectGroup: { changes, rank in
                                    guard !isSaving else { return }
                                    rejectGroup(changes, rank: rank, context: context)
                                }, onDeferGroup: { changes in
                                    guard !isSaving else { return }
                                    deferGroup(changes, context: context)
                                }, showDecisionState: true, emptyState: SuggestionEmptyState(title: "No Suggestions Yet", message: "Not enough data to create suggestions yet. Keep using this plan and we'll suggest changes once we have enough workout data."))
                            }
                        }
                    }

                    exerciseRecapSection
                }
                .fontDesign(.rounded)
                .padding(.horizontal)
            }
            .scrollContentBackground(.hidden)
            .appBackground()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        finishSummary()
                    } label: {
                        if isGeneratingSuggestions || isSaving {
                            ProgressView()
                                .controlSize(.regular)
                        } else {
                            Label("Done", systemImage: "checkmark")
                        }
                    }
                    .disabled(isGeneratingSuggestions || isSaving)
                    .popoverTip(suggestionDeferTip)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutSummaryDoneButton)
                    .accessibilityLabel(AccessibilityText.workoutSummaryDoneLabel)
                    .accessibilityHint(AccessibilityText.workoutSummaryDoneHint)
                }
            }
            .onChange(of: pendingSuggestionCount, initial: true) { _, newValue in
                SuggestionDeferTip.hasPendingSuggestions = newValue > 0
            }
            .task(id: workout.id) {
                loadPRs()
                if workout.workoutPlan == nil {
                    FoundationModelPrewarmer.warmup()
                }
                refreshRateableSuggestionEvents()
                await generateSuggestionsIfNeeded()
            }
            .task(id: workout.healthWorkout?.healthWorkoutUUID) {
                await loadWorkoutHealthSummaryItems()
            }
            .sheet(isPresented: $showNotesEditorSheet) {
                TextEntryEditorView(title: "Notes", promptText: "Workout Notes", text: $workout.notes, accessibilityIdentifier: AccessibilityIdentifiers.workoutNotesEditorField)
                    .presentationDetents([.fraction(0.4)])
                    .presentationBackground(Color.sheetBg)
                    .onChange(of: workout.notes) {
                        scheduleSave(context: context)
                    }
                    .onDisappear {
                        workout.notes = workout.notes.trimmingCharacters(in: .whitespacesAndNewlines)
                        saveContext(context: context)
                    }
            }
            .sheet(isPresented: $showTitleEditorSheet) {
                TextEntryEditorView(title: "Title", promptText: "Workout Title", text: $workout.title, accessibilityIdentifier: AccessibilityIdentifiers.workoutTitleEditorField, initialSelectionBehavior: .whenTextMatches(["New Workout"]))
                    .presentationDetents([.fraction(0.2)])
                    .presentationBackground(Color.sheetBg)
                    .onChange(of: workout.title) {
                        scheduleSave(context: context)
                    }
                    .onDisappear {
                        if workout.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            workout.title = "New Workout"
                        }
                        saveContext(context: context)
                        WorkoutActivityManager.update(for: workout)
                    }
            }
        }
    }

    private var effortSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Effort")
                .font(.headline)
            WorkoutEffortCardView(model: .init(title: workoutEffortTitle(workout.postEffort), description: workoutEffortDescription(workout.postEffort), valueText: "\(workout.postEffort)", score: Double(workout.postEffort), caption: nil))
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutSummaryEffortCard(workout.postEffort))
                .accessibilityLabel(AccessibilityText.workoutSummaryEffortCardLabel)
                .accessibilityValue(AccessibilityText.workoutSummaryEffortCardValue(score: workout.postEffort, description: workoutEffortDescription(workout.postEffort)))
        }
    }

    private var exerciseRecapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercise Recap")
                .font(.headline)
            VStack(spacing: 10) {
                ForEach(workout.sortedExercises, id: \.id) { exercise in
                    exerciseRecapCard(exercise)
                }
            }
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.workoutSummaryExerciseRecapSection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(AccessibilityText.workoutSummaryExerciseRecapSectionLabel)
    }

    private func exerciseRecapCard(_ exercise: ExercisePerformance) -> some View {
        let prItem = prItemsByCatalogID[exercise.catalogID]
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Text(exercise.name)
                    .font(.headline)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let prItem, !prItem.types.isEmpty {
                    prCapsule(count: prItem.types.count)
                }
            }

            Divider()

            ExerciseSetTable(
                rows: exercise.sortedSets,
                repsText: { $0.reps > 0 ? "\($0.reps)" : "-" },
                weightText: { $0.weight > 0 ? formattedWeightText($0.weight, unit: weightUnit) : "-" },
                restText: { $0.effectiveRestSeconds > 0 ? secondsToTime($0.effectiveRestSeconds) : "-" }
            ) { set in
                ExerciseHistorySetIndicator(set: set)
            }

            if let prItem, !prItem.types.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(prItem.types, id: \.self) { type in
                        Text(prValueText(type: type, value: prItem.values[type] ?? 0))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardStyle()
        .accessibilityIdentifier(AccessibilityIdentifiers.workoutSummaryExerciseRecapCard(exercise.catalogID))
    }

    private func prCapsule(count: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "trophy.fill")
                .font(.caption)
            Text(count == 1 ? "PR" : "\(count) PRs")
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.yellow.opacity(0.25), in: Capsule())
        .foregroundStyle(.primary)
        .accessibilityLabel(count == 1 ? "1 personal record" : "\(count) personal records")
    }

    private var outcomeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How'd it go?")
                .font(.headline)
            Text("This rates the suggestions you used in this workout.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                ForEach(SessionOutcome.promptOptions, id: \.self) { option in
                    outcomeCard(option)
                }
            }
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.workoutSummaryOutcomeSection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(AccessibilityText.workoutSummaryOutcomeSectionLabel)
    }

    private func outcomeCard(_ outcome: SessionOutcome) -> some View {
        let isSelected = sessionOutcomeSelection == outcome
        return Button {
            Haptics.selection()
            sessionOutcomeSelection = outcome
            applyOutcomeToSuggestionEvents(outcome)
        } label: {
            VStack(spacing: 6) {
                Text(outcome.emoji)
                    .font(.title)
                Text(outcome.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .appCardStyle()
            .opacity(isSelected ? 1.0 : 0.6)
            .scaleEffect(isSelected ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.bouncy, value: sessionOutcomeSelection)
        .accessibilityIdentifier(AccessibilityIdentifiers.workoutSummaryOutcomeOption(outcome))
        .accessibilityLabel(outcome.displayName)
        .accessibilityHint(AccessibilityText.workoutSummaryOutcomeOptionHint)
    }

    private var hardDayFeeling: MoodLevel? {
        guard let feeling = workout.preWorkoutContext?.feeling, feeling.isHardDay else { return nil }
        return feeling
    }

    private func hardDaySection(feeling: MoodLevel) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.title2)
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Hard Day Logged")
                    .font(.headline)
                Text("You showed up while feeling \(feeling.displayName.lowercased()).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardStyle()
    }

    @ViewBuilder
    private var planSaveSection: some View {
        if didSaveWorkoutAsPlan, workout.workoutPlan != nil {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)

                Text("Saved as Workout Plan")
                    .font(.headline)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appCardStyle()
            .accessibilityIdentifier(AccessibilityIdentifiers.workoutSummaryPlanSavedRow)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(AccessibilityText.workoutSummaryPlanSavedLabel)
        } else if workout.workoutPlan == nil {
            Button {
                saveWorkoutAsPlan()
            } label: {
                Label("Save as Workout Plan", systemImage: "list.clipboard")
                    .padding(.vertical, 5)
                    .fontWeight(.semibold)
                    .font(.title3)
            }
            .buttonStyle(.glassProminent)
            .buttonSizing(.flexible)
            .accessibilityIdentifier(AccessibilityIdentifiers.workoutSummarySaveAsPlanButton)
            .accessibilityHint(AccessibilityText.workoutSummarySaveAsPlanHint)
        } else {
            EmptyView()
        }
    }

    private func loadPRs() {
        let exercises = workout.sortedExercises
        let catalogIDs = Set(exercises.map { $0.catalogID })

        // Single batch fetch instead of per-exercise queries
        let historyMap = ExerciseHistoryUpdater.batchFetchHistories(for: catalogIDs, context: context)
        let prSummaries = combinedPRSummaries(from: exercises)

        var entries: [PRItem] = []
        var itemsByCatalog: [String: PRItem] = [:]
        for summary in prSummaries {
            guard let entry = prEntry(for: summary, history: historyMap[summary.catalogID]) else { continue }
            entries.append(entry)
            itemsByCatalog[summary.catalogID] = entry
        }
        prEntries = entries
        prItemsByCatalogID = itemsByCatalog
    }

    private func refreshRateableSuggestionEvents() {
        hasRateableSuggestionEvents = !rateableSuggestionEvents().isEmpty
    }

    /// Suggestion events whose accepted prescription changes drove the planned
    /// work in this session. The session-level outcome rating is written to
    /// `userFeedback` on each of these.
    ///
    /// Eligibility:
    /// - decision == .accepted
    /// - userFeedback is nil (never rated) OR this summary already rated it
    ///   (so re-rating within the same summary stays in scope)
    /// - target prescription belongs to this session's plan
    /// - sessionFrom != this workout (events generated by this summary are
    ///   tested by a future workout, not this one)
    private func rateableSuggestionEvents() -> [SuggestionEvent] {
        guard let plan = workout.workoutPlan else { return [] }
        let workoutID = workout.id
        var result: [SuggestionEvent] = []
        for prescription in plan.sortedExercises {
            for event in prescription.suggestionEvents ?? [] {
                guard event.decision == .accepted else { continue }
                guard event.userFeedback == nil || appliedFeedbackEventIDs.contains(event.id) else { continue }
                guard event.sessionFrom?.id != workoutID else { continue }
                result.append(event)
            }
        }
        return result
    }

    private func applyOutcomeToSuggestionEvents(_ outcome: SessionOutcome) {
        guard let feedback = outcome.userFeedback else { return }
        let events = rateableSuggestionEvents()
        guard !events.isEmpty else { return }
        for event in events {
            event.userFeedback = feedback
            appliedFeedbackEventIDs.insert(event.id)
        }
        saveContext(context: context)
        refreshRateableSuggestionEvents()
    }

    private func combinedPRSummaries(from exercises: [ExercisePerformance]) -> [WorkoutExercisePRSummary] {
        var orderedCatalogIDs: [String] = []
        var groupedExercises: [String: [ExercisePerformance]] = [:]

        for exercise in exercises {
            if groupedExercises[exercise.catalogID] == nil {
                orderedCatalogIDs.append(exercise.catalogID)
            }
            groupedExercises[exercise.catalogID, default: []].append(exercise)
        }

        return orderedCatalogIDs.compactMap { catalogID in
            guard let grouped = groupedExercises[catalogID], let first = grouped.first else { return nil }

            return WorkoutExercisePRSummary(catalogID: catalogID, exerciseName: first.name, bestEstimated1RM: grouped.compactMap(\.bestEstimated1RM).max(), bestWeight: grouped.compactMap(\.bestWeight).max(), bestReps: grouped.compactMap(\.bestReps).max(), totalVolume: grouped.reduce(0) { $0 + $1.totalVolume })
        }
    }

    private func prEntry(for summary: WorkoutExercisePRSummary, history: ExerciseHistory?) -> PRItem? {
        let (types, values) = prTypesAndValues(for: summary, history: history)
        guard !types.isEmpty else { return nil }
        return PRItem(catalogID: summary.catalogID, exerciseName: summary.exerciseName, types: types.sorted { $0.rawValue < $1.rawValue }, values: values)
    }

    private func prTypesAndValues(for summary: WorkoutExercisePRSummary, history: ExerciseHistory?) -> (types: [PRType], values: [PRType: Double]) {
        var types: [PRType] = []
        var values: [PRType: Double] = [:]

        if let current1RM = summary.bestEstimated1RM {
            let historical1RM = history?.bestEstimated1RM ?? 0
            if historical1RM == 0 || current1RM > historical1RM {
                types.append(.estimated1RM)
                values[.estimated1RM] = current1RM
            }
        }

        if let currentWeight = summary.bestWeight {
            let historicalWeight = history?.bestWeight ?? 0
            if historicalWeight == 0 || currentWeight > historicalWeight {
                types.append(.maxWeight)
                values[.maxWeight] = currentWeight
            }
        }

        if let currentReps = summary.bestReps {
            let historicalReps = history?.bestReps ?? 0
            if historicalReps == 0 || currentReps > historicalReps {
                types.append(.maxReps)
                values[.maxReps] = Double(currentReps)
            }
        }

        let currentVolume = summary.totalVolume
        if currentVolume > 0 {
            let historicalVolume = history?.bestVolume ?? 0
            if historicalVolume == 0 || currentVolume > historicalVolume {
                types.append(.totalVolume)
                values[.totalVolume] = currentVolume
            }
        }

        return (types, values)
    }

    private func prValueText(type: PRType, value: Double) -> String {
        switch type {
        case .estimated1RM:
            return String(localized: "New Estimated 1RM: \(formattedWeightText(value, unit: weightUnit))")
        case .maxWeight:
            return String(localized: "Max Weight: \(formattedWeightText(value, unit: weightUnit))")
        case .maxReps:
            return String(localized: "Max Reps: \(Int(value))")
        case .totalVolume:
            return String(localized: "Total Volume: \(formattedWeightText(value, unit: weightUnit, fractionDigits: 0...0))")
        }
    }

    private func loadWorkoutHealthSummaryItems() async {
        guard let healthWorkout = workout.healthWorkout else {
            workoutHealthSummaryItems = []
            return
        }

        let healthStats = await HealthWorkoutSummaryStatsLoader.load(for: healthWorkout)
        var items: [SummaryStatItem] = []

        if let averageHeartRate = healthStats.averageHeartRate {
            items.append(SummaryStatItem(title: "Avg Heart Rate", value: String(localized: "\(Int(averageHeartRate.rounded())) bpm")))
        }

        if let totalEnergyBurned = healthStats.totalEnergyBurned {
            items.append(SummaryStatItem(title: "Total Energy", value: formattedEnergyText(totalEnergyBurned, unit: energyUnit)))
        }

        workoutHealthSummaryItems = items
    }

    private func finishSummary() {
        guard !isSaving else { return }
        isSaving = true
        Haptics.selection()
        deferRemainingSuggestions()
        cleanupHistoricalPrescriptionLinksIfNeeded()
        ExerciseHistoryUpdater.updateHistoriesForCompletedWorkout(workout, context: context)
        workout.status = SessionStatus.done.rawValue
        saveContext(context: context)
        Diag.breadcrumb(VACrumb.workoutFinished)
        Diag.funnel(VAFunnel.workoutSession, .completed)
        Diag.count(VACounter.workoutsCompleted)
        Diag.count(VACounter.setsLogged, by: workout.sortedExercises.reduce(0) { $0 + $1.sortedSets.filter(\.complete).count })
        Task {
            await HealthExportCoordinator.shared.exportIfEligible(sessionID: workout.id)
        }
        WorkoutActivityManager.end()
        SpotlightIndexer.index(workoutSession: workout)
        AppReviewPreferences.incrementCompletedSessionCount()
        if AppReviewPreferences.shouldRequestReview {
            AppReviewPreferences.hasRequestedReview = true
            requestReview()
        }
        if router.activeWorkoutSession?.id == workout.id {
            router.activeWorkoutSession = nil
        } else {
            dismiss()
        }
    }

    private func saveWorkoutAsPlan() {
        guard workout.workoutPlan == nil else { return }
        Haptics.selection()
        let plan = WorkoutPlan(from: workout, completed: true)
        context.insert(plan)
        for exercise in workout.sortedExercises {
            exercise.originalTargetSnapshot = ExerciseTargetSnapshot(performance: exercise)
        }
        workout.workoutPlan = plan
        didSaveWorkoutAsPlan = true
        saveContext(context: context)
        SpotlightIndexer.index(workoutPlan: plan)
        Task {
            await generateSuggestionsIfNeeded()
            await IntentDonations.donateSaveWorkoutAsPlan(workout: workout)
        }
    }

    private func generateSuggestionsIfNeeded() async {
        guard shouldShowSuggestions else { return }
        guard !isGeneratingSuggestions else { return }

        isGeneratingSuggestions = true
        defer {
            cleanupHistoricalPrescriptionLinksIfNeeded()
            isGeneratingSuggestions = false
        }

        if sessionSuggestionEvents.isEmpty {
            await OutcomeResolver.resolveOutcomes(for: workout, context: context)

            let generated = await SuggestionGenerator.generateSuggestions(for: workout, context: context)
            if !generated.isEmpty {
                for event in generated {
                    context.insert(event)
                }
                saveContext(context: context)
            }
        }
    }

    private func deferRemainingSuggestions() {
        guard !sessionSuggestionEvents.isEmpty else { return }
        for event in sessionSuggestionEvents where event.decision == .pending {
            event.decision = .deferred
        }
    }

    private func cleanupHistoricalPrescriptionLinksIfNeeded() {
        guard workout.workoutPlan != nil else { return }
        workout.clearPrescriptionLinksForHistoricalUse()
        saveContext(context: context)
    }
}

#Preview(traits: .sampleDataSuggestionGeneration) {
    WorkoutSummaryView(workout: sampleSuggestionGenerationSession())
}

#Preview(traits: .sampleDataIncomplete) {
    WorkoutSummaryView(workout: sampleIncompleteSession())
}
