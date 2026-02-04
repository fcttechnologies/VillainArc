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

    @State private var showTitleEditorSheet = false
    @State private var showNotesEditorSheet = false
    @State private var prEntries: [PRItem] = []

    private var totalExercises: Int {
        workout.exercises.count
    }

    private var totalSets: Int {
        workout.exercises.reduce(0) { $0 + $1.sets.count }
    }

    private var totalVolume: Double {
        workout.exercises.reduce(0) { total, exercise in
            total + exercise.sets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
        }
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
                        summaryStat(title: "Total Volume", value: "\(totalVolume.formatted(.number.precision(.fractionLength(0...1)))) lbs")
                    } else {
                        HStack(spacing: 12) {
                            summaryStat(title: "Total Volume", value: "\(totalVolume.formatted(.number.precision(.fractionLength(0...1)))) lbs")
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

                    if !prEntries.isEmpty {
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
                    Button("Done", systemImage: "checkmark") {
                        finishSummary()
                    }
                }
            }
            .task {
                loadPRs()
            }
            .sheet(isPresented: $showNotesEditorSheet) {
                TextEntryEditorView(title: "Notes", placeholder: "Workout Notes", text: $workout.notes, accessibilityIdentifier: AccessibilityIdentifiers.workoutNotesEditorField, axis: .vertical)
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
                TextEntryEditorView(title: "Title", placeholder: "Workout Title", text: $workout.title, accessibilityIdentifier: AccessibilityIdentifiers.workoutTitleEditorField)
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
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
        }
        .fontDesign(.rounded)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
    }

    private func prRow(_ entry: PRItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.exerciseName)
                .fontWeight(.semibold)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(entry.types, id: \.self) { type in
                    Text(prValueText(type: type, value: entry.values[type] ?? 0))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10))
    }

    private func loadPRs() {
        var entries: [PRItem] = []
        for exercise in workout.sortedExercises {
            let history = (try? context.fetch(ExercisePerformance.matching(catalogID: exercise.catalogID))) ?? []

            var types: [PRType] = []
            var values: [PRType: Double] = [:]

            if let current1RM = exercise.bestEstimated1RM {
                let historical1RM = ExercisePerformance.historicalBestEstimated1RM(in: history)
                if historical1RM == nil || current1RM > (historical1RM ?? 0) {
                    types.append(.estimated1RM)
                    values[.estimated1RM] = current1RM
                }
            }

            if let currentWeight = exercise.bestWeight {
                let historicalWeight = ExercisePerformance.historicalBestWeight(in: history)
                if historicalWeight == nil || currentWeight > (historicalWeight ?? 0) {
                    types.append(.maxWeight)
                    values[.maxWeight] = currentWeight
                }
            }

            let currentVolume = exercise.totalVolume
            if currentVolume > 0 {
                let historicalVolume = ExercisePerformance.historicalBestVolume(in: history)
                if historicalVolume == nil || currentVolume > (historicalVolume ?? 0) {
                    types.append(.totalVolume)
                    values[.totalVolume] = currentVolume
                }
            }

            if !types.isEmpty {
                entries.append(PRItem(
                    exerciseName: exercise.name,
                    types: types.sorted { $0.rawValue < $1.rawValue },
                    values: values
                ))
            }
        }
        prEntries = entries
    }

    private func prValueText(type: PRType, value: Double) -> String {
        switch type {
        case .estimated1RM:
            return "Estimated 1RM: \(formatWeight(value))"
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
        workout.status = SessionStatus.done.rawValue
        saveContext(context: context)
        dismiss()
    }

    private func saveWorkoutAsPlan() {
        Haptics.selection()
        let plan = WorkoutPlan(from: workout, completed: true)
        context.insert(plan)
        workout.workoutPlan = plan
        saveContext(context: context)
    }
}

#Preview {
    WorkoutSummaryView(workout: sampleIncompleteSession())
        .sampleDataContainerIncomplete()
}
