import SwiftUI
import SwiftData

struct WorkoutSummaryView: View {
    private enum PRType: String, CaseIterable {
        case estimated1RM = "1RM"
        case maxWeight = "Max Weight"
        case totalVolume = "Total Volume"
    }

    private struct PRItem: Identifiable {
        let id = UUID()
        let exerciseName: String
        let types: [PRType]
        let values: [PRType: Double]
    }

    @Bindable var workout: WorkoutSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var sessionSuggestions: [PrescriptionChange]

    @State private var showTitleEditorSheet = false
    @State private var showNotesEditorSheet = false
    @State private var prEntries: [PRItem] = []
    @State private var isGeneratingSuggestions = false

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
        "\(totalVolume.formatted(.number.precision(.fractionLength(0...1)))) lbs"
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

    private var suggestionSections: [ExerciseSuggestionSection] {
        groupSuggestions(sessionSuggestions)
    }

    init(workout: WorkoutSession) {
        _workout = Bindable(wrappedValue: workout)
        let sessionID = workout.id
        _sessionSuggestions = Query(filter: #Predicate<PrescriptionChange> { $0.sessionFrom?.id == sessionID }, sort: [SortDescriptor(\.createdAt, order: .reverse)])
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
                                Image(systemName: "pencil")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)

                        Text(formattedDateRange(start: workout.startedAt, end: workout.endedAt, includeTime: true))
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        summaryStat(title: "Exercises", value: "\(totalExercises)")
                        summaryStat(title: "Sets", value: "\(totalSets)")
                        summaryStat(title: "Duration", value: durationText)
                    }

                    if prEntries.isEmpty {
                        summaryStat(title: "Total Volume", value: formattedTotalVolume)
                    } else {
                        HStack(spacing: 12) {
                            summaryStat(title: "Total Volume", value: formattedTotalVolume)
                            summaryStat(title: "New PRs", value: "\(prEntries.reduce(0) { $0 + $1.types.count })")
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

                    effortSection

                    if shouldShowSuggestions {
                        VStack(alignment: .leading, spacing: 12) {
                            if isGeneratingSuggestions {
                                ProgressView("Generating suggestions...")
                                    .frame(maxWidth: .infinity, alignment: .center)
                            } else {
                                Text("Suggestions")
                                    .font(.headline)
                                SuggestionReviewView(sections: suggestionSections, onAcceptGroup: { changes in acceptGroup(changes, context: context) }, onRejectGroup: { changes in rejectGroup(changes, context: context) }, onDeferGroup: { changes in deferGroup(changes, context: context) }, showDecisionState: true, emptyState: SuggestionEmptyState(title: "No Suggestions Yet", message: "Keep logging workouts so we have enough information to give you detailed suggestions."))
                            }
                        }
                    } else if !prEntries.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(prEntries) { entry in
                                prRow(entry)
                            }
                        }
                    }

                    if workout.workoutPlan == nil {
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
                    }
                }
                .fontDesign(.rounded)
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        finishSummary()
                    } label: {
                        if isGeneratingSuggestions {
                            ProgressView()
                                .controlSize(.regular)
                        } else {
                            Label("Done", systemImage: "checkmark")
                        }
                    }
                    .disabled(isGeneratingSuggestions)
                }
            }
            .task(id: workout.id) {
                loadPRs()
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

    private func summaryStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fontWeight(.semibold)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
        }
        .fontDesign(.rounded)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
    }

    private var effortSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Effort")
                .font(.headline)
            Text(effortDescription(workout.postEffort))
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
        .animation(.bouncy, value: isSelected)
    }

    private func effortDescription(_ value: Int) -> String {
        switch value {
        case 1...2: "Very easy, minimal exertion."
        case 3...4: "Light effort, could do much more."
        case 5...6: "Moderate effort, comfortable pace."
        case 7...8: "Hard effort, pushing your limits."
        case 9: "Near maximal, barely completed."
        case 10: "Absolute maximum effort."
        default: "How hard was this workout?"
        }
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
        let entries: [PRItem] = workout.sortedExercises.compactMap { exercise in
            ExerciseHistoryUpdater.createIfNeeded(for: exercise.catalogID, context: context)
            guard let history = ExerciseHistoryUpdater.fetchHistory(for: exercise.catalogID, context: context) else { return nil }
            return prEntry(for: exercise, history: history)
        }
        prEntries = entries
    }

    private func prEntry(for exercise: ExercisePerformance, history: ExerciseHistory) -> PRItem? {
        let (types, values) = prTypesAndValues(for: exercise, history: history)
        guard !types.isEmpty else { return nil }
        return PRItem(exerciseName: exercise.name, types: types.sorted { $0.rawValue < $1.rawValue }, values: values)
    }

    private func prTypesAndValues(for exercise: ExercisePerformance, history: ExerciseHistory) -> (types: [PRType], values: [PRType: Double]) {
        var types: [PRType] = []
        var values: [PRType: Double] = [:]

        if let current1RM = exercise.bestEstimated1RM {
            let historical1RM = history.bestEstimated1RM
            if historical1RM == 0 || current1RM > historical1RM {
                types.append(.estimated1RM)
                values[.estimated1RM] = current1RM
            }
        }

        if let currentWeight = exercise.bestWeight {
            let historicalWeight = history.bestWeight
            if historicalWeight == 0 || currentWeight > historicalWeight {
                types.append(.maxWeight)
                values[.maxWeight] = currentWeight
            }
        }

        let currentVolume = exercise.totalVolume
        if currentVolume > 0 {
            let historicalVolume = history.bestVolume
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
            return "New Estimated 1RM: \(formatWeight(value))"
        case .maxWeight:
            return "Max Weight: \(formatWeight(value))"
        case .totalVolume:
            return "Total Volume: \(formatWeight(value, allowFraction: false))"
        }
    }

    private func formatWeight(_ value: Double, allowFraction: Bool = true) -> String {
        let precision = allowFraction ? 0...1 : 0...0
        let formatted = value.formatted(.number.precision(.fractionLength(precision)))
        return "\(formatted) lbs"
    }

    private func finishSummary() {
        Haptics.selection()
        deferRemainingSuggestions()
        workout.status = SessionStatus.done.rawValue
        saveContext(context: context)
        
        ExerciseHistoryUpdater.updateHistoriesForCompletedWorkout(workout, context: context)
        
        dismiss()
    }

    private func saveWorkoutAsPlan() {
        Haptics.selection()
        let plan = WorkoutPlan(from: workout, completed: true)
        context.insert(plan)
        workout.workoutPlan = plan
        saveContext(context: context)
        SpotlightIndexer.index(workoutPlan: plan)
        Task { await IntentDonations.donateSaveWorkoutAsPlan(workout: workout) }
    }

    @MainActor
    private func generateSuggestionsIfNeeded() async {
        guard shouldShowSuggestions else { return }
        guard !isGeneratingSuggestions else { return }

        guard sessionSuggestions.isEmpty else { return }

        isGeneratingSuggestions = true
        defer { isGeneratingSuggestions = false }

        await OutcomeResolver.resolveOutcomes(for: workout, context: context)

        let generated = await SuggestionGenerator.generateSuggestions(for: workout, context: context)
        if !generated.isEmpty {
            for change in generated {
                context.insert(change)
            }
            saveContext(context: context)
        }
    }

    @MainActor
    private func deferRemainingSuggestions() {
        guard !sessionSuggestions.isEmpty else { return }
        for change in sessionSuggestions where change.decision == .pending {
            change.decision = .deferred
        }
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
