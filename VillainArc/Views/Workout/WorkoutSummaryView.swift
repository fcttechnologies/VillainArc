import SwiftUI
import SwiftData

struct WorkoutSummaryView: View {
    private enum PRType: String, CaseIterable {
        case estimated1RM = "1RM"
        case maxWeight = "Max Weight"
        case maxReps = "Max Reps"
        case totalVolume = "Total Volume"
    }

    private struct PRItem: Identifiable {
        let id = UUID()
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var weightUnit: WeightUnit { appSettings.first?.weightUnit ?? .lbs }

    @State private var showTitleEditorSheet = false
    @State private var showNotesEditorSheet = false
    @State private var prEntries: [PRItem] = []
    @State private var isGeneratingSuggestions = false
    @State private var isSaving = false
    @State private var didSaveWorkoutAsPlan = false
    @State private var showPRSection = false

    private var totalExercises: Int {
        workout.exercises?.count ?? 0
    }

    private var totalSets: Int {
        var count: Int = 0
        for exercise in workout.exercises ?? [] {
            for _ in exercise.sets ?? [] {
                count += 1
            }
        }
        return count
    }

    private var totalVolume: Double {
        workout.exercises?.reduce(0) { $0 + $1.totalVolume } ?? 0
    }

    private var formattedTotalVolume: String {
        formattedWeightText(totalVolume, unit: weightUnit, fractionDigits: 0...1)
    }

    private var durationText: String {
        let endDate = workout.endedAt ?? .now
        let totalSeconds = max(0, Int(endDate.timeIntervalSince(workout.startedAt)))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
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
                        SummaryStatCard(title: "Exercises", value: "\(totalExercises)")
                        SummaryStatCard(title: "Sets", value: "\(totalSets)")
                        SummaryStatCard(title: "Duration", value: durationText)
                    }

                    if prEntries.isEmpty {
                        SummaryStatCard(title: "Total Volume", value: formattedTotalVolume)
                    } else {
                        HStack(spacing: 12) {
                            SummaryStatCard(title: "Total Volume", value: formattedTotalVolume)
                            SummaryStatCard(title: "New PRs", value: "\(prCount)")
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
                    .accessibilityValue(AccessibilityText.workoutSummaryNotesValue(
                        hasNotes: !workout.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        notes: workout.notes
                    ))
                    .accessibilityHint(AccessibilityText.workoutSummaryNotesHint)

                    effortSection

                    planSaveSection

                    if shouldShowSuggestions {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Suggestions")
                                .font(.headline)
                            if isGeneratingSuggestions {
                                ProgressView("Generating suggestions...")
                                    .frame(maxWidth: .infinity, alignment: .center)
                            } else {
                                SuggestionReviewView(sections: suggestionSections, onAcceptGroup: { changes in
                                    guard !isSaving else { return }
                                    acceptGroup(changes, context: context)
                                }, onRejectGroup: { changes in
                                    guard !isSaving else { return }
                                    rejectGroup(changes, context: context)
                                }, onDeferGroup: { changes in
                                    guard !isSaving else { return }
                                    deferGroup(changes, context: context)
                                }, showDecisionState: true, emptyState: SuggestionEmptyState(title: "No Suggestions Yet", message: "Not enough data to create suggestions yet. Keep using this plan and we'll suggest changes once we have enough workout data."))
                            }
                        }
                    }

                    if !prEntries.isEmpty {
                        prDisclosureSection
                    }
                }
                .fontDesign(.rounded)
                .padding(.horizontal)
            }
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
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutSummaryDoneButton)
                    .accessibilityLabel(AccessibilityText.workoutSummaryDoneLabel)
                    .accessibilityHint(AccessibilityText.workoutSummaryDoneHint)
                }
            }
            .task(id: workout.id) {
                loadPRs()
                if workout.workoutPlan == nil {
                    FoundationModelPrewarmer.warmup()
                }
                await generateSuggestionsIfNeeded()
            }
            .sheet(isPresented: $showNotesEditorSheet) {
                TextEntryEditorView(title: "Notes", promptText: "Workout Notes", text: $workout.notes, accessibilityIdentifier: AccessibilityIdentifiers.workoutNotesEditorField)
                    .presentationDetents([.fraction(0.4)])
                    .onChange(of: workout.notes) {
                        scheduleSave(context: context)
                    }
                    .onDisappear {
                        workout.notes = workout.notes.trimmingCharacters(in: .whitespacesAndNewlines)
                        saveContext(context: context)
                    }
            }
            .sheet(isPresented: $showTitleEditorSheet) {
                TextEntryEditorView(title: "Title", promptText: "Workout Title", text: $workout.title, accessibilityIdentifier: AccessibilityIdentifiers.workoutTitleEditorField)
                    .presentationDetents([.fraction(0.2)])
                    .onChange(of: workout.title) {
                        scheduleSave(context: context)
                    }
                    .onDisappear {
                        if workout.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            workout.title = "New Workout"
                        }
                        saveContext(context: context)
                    }
            }
        }
    }

    private var effortSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Effort")
                .font(.headline)
            Text(workoutEffortDescription(workout.postEffort))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fontWeight(.semibold)
            HStack(spacing: 8) {
                ForEach(1...10, id: \.self) { value in
                    effortCard(for: value)
                }
            }
        }
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
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
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

    private var prDisclosureSection: some View {
        DisclosureGroup(isExpanded: $showPRSection) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(prEntries) { entry in
                    prRow(entry)
                }
            }
            .padding(.top, 10)
        } label: {
            HStack(spacing: 8) {
                Text("Personal Records")
                    .font(.headline)
                Spacer()
                Text("\(prCount)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier(AccessibilityIdentifiers.workoutSummaryPRSection)
        .accessibilityLabel(AccessibilityText.workoutSummaryPRSectionLabel)
        .accessibilityValue(AccessibilityText.workoutSummaryPRSectionValue(count: prCount))
    }

    private func effortCard(for value: Int) -> some View {
        let isSelected = workout.postEffort == value

        return Button {
            Haptics.selection()
            workout.postEffort = value
            saveContext(context: context)
        } label: {
            Text("\(value)")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10))
                .opacity(isSelected ? 1.0 : 0.6)
                .scaleEffect(isSelected ? 1.15 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? .none : .bouncy, value: isSelected)
        .accessibilityIdentifier(AccessibilityIdentifiers.workoutSummaryEffortCard(value))
        .accessibilityLabel(AccessibilityText.workoutSummaryEffortLabel(value: value))
        .accessibilityValue(AccessibilityText.workoutSummaryEffortValue(value: value, isSelected: isSelected))
    }

    private func prRow(_ entry: PRItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.exerciseName)
                .font(.headline)
                .lineLimit(1)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(entry.types, id: \.self) { type in
                    Text(prValueText(type: type, value: entry.values[type] ?? 0))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fontWeight(.semibold)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fontDesign(.rounded)
        .padding(10)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10))
    }

    private func loadPRs() {
        let exercises = workout.sortedExercises
        let catalogIDs = Set(exercises.map { $0.catalogID })

        // Single batch fetch instead of per-exercise queries
        let historyMap = ExerciseHistoryUpdater.batchFetchHistories(for: catalogIDs, context: context)
        let prSummaries = combinedPRSummaries(from: exercises)

        prEntries = prSummaries.compactMap { summary in
            prEntry(for: summary, history: historyMap[summary.catalogID])
        }
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

            return WorkoutExercisePRSummary(
                catalogID: catalogID,
                exerciseName: first.name,
                bestEstimated1RM: grouped.compactMap(\.bestEstimated1RM).max(),
                bestWeight: grouped.compactMap(\.bestWeight).max(),
                bestReps: grouped.compactMap(\.bestReps).max(),
                totalVolume: grouped.reduce(0) { $0 + $1.totalVolume }
            )
        }
    }

    private func prEntry(for summary: WorkoutExercisePRSummary, history: ExerciseHistory?) -> PRItem? {
        let (types, values) = prTypesAndValues(for: summary, history: history)
        guard !types.isEmpty else { return nil }
        return PRItem(exerciseName: summary.exerciseName, types: types.sorted { $0.rawValue < $1.rawValue }, values: values)
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
            return "New Estimated 1RM: \(formattedWeightText(value, unit: weightUnit))"
        case .maxWeight:
            return "Max Weight: \(formattedWeightText(value, unit: weightUnit))"
        case .maxReps:
            return "Max Reps: \(Int(value))"
        case .totalVolume:
            return "Total Volume: \(formattedWeightText(value, unit: weightUnit, fractionDigits: 0...0))"
        }
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
        dismiss()
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

    @MainActor
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

    @MainActor
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

#Preview {
    WorkoutSummaryView(workout: sampleSuggestionGenerationSession())
        .sampleDataContainerSuggestionGeneration()
}

#Preview {
    WorkoutSummaryView(workout: sampleIncompleteSession())
        .sampleDataContainerIncomplete()
}
