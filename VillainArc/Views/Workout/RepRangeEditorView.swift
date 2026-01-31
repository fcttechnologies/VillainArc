import SwiftUI
import SwiftData

struct RepRangeEditorView: View {
    @Environment(\.modelContext) private var context
    @Bindable var repRange: RepRangePolicy
    let catalogID: String
    @State private var suggestion: RepRangeSuggestion?
    
    private var mode: RepRangeMode {
        repRange.activeMode
    }
    
    var body: some View {
        Form {
            Section {
                Picker("Type", selection: $repRange.activeMode) {
                    ForEach(RepRangeMode.allCases, id: \.self) { mode in
                        Text(mode.displayName)
                            .tag(mode)
                    }
                }
                .accessibilityIdentifier("repRangeModePicker")
            } footer: {
                Text(modeFooterText)
            }

            Section {
                if mode == .target {
                    Stepper("Target: \(repRange.targetReps)", value: $repRange.targetReps, in: 1...200)
                        .accessibilityIdentifier("repRangeTargetStepper")
                } else if mode == .range {
                    Stepper("Lower: \(repRange.lowerRange)", value: $repRange.lowerRange, in: 1...200)
                        .accessibilityIdentifier("repRangeLowerStepper")
                    Stepper("Upper: \(repRange.upperRange)", value: $repRange.upperRange, in: (repRange.lowerRange + 1)...200)
                        .accessibilityIdentifier("repRangeUpperStepper")
                }
            } footer: {
                if mode == .target || mode == .range {
                    Text(repGuidanceFooterText)
                }
            }
            
            if mode == .notSet, let suggestion {
                Section {
                    Button {
                        applySuggestion(suggestion)
                    } label: {
                        HStack {
                            Text(suggestion.title)
                            Spacer()
                            if let detail = suggestion.detailText {
                                Text(detail)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .fontWeight(.semibold)
                    }
                    .tint(.primary)
                    .buttonStyle(.borderless)
                    .listRowBackground(Color.blue.opacity(0.2))
                    .accessibilityIdentifier(AccessibilityIdentifiers.repRangeSuggestionButton(catalogID: catalogID, index: 0))
                    .accessibilityLabel("Rep range suggestion")
                    .accessibilityValue(suggestion.accessibilityValue)
                    .accessibilityHint("Applies this rep range.")
                } header: {
                    Text("Suggested")
                } footer: {
                    Text("This suggestion is based on previous times you logged this exercise or your usual rep goal.")
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.repRangeSuggestionsSection)
            }
        }
        .listSectionSpacing(20)
        .navBar(title: "Rep Range") {
            CloseButton()
        }
        .accessibilityIdentifier("repRangeForm")
        .onChange(of: mode) {
            Haptics.selection()
            saveContext(context: context)
        }
        .onChange(of: repRange.lowerRange) { _, newValue in
            if newValue > repRange.upperRange {
                repRange.upperRange = newValue
            }
            Haptics.selection()
            scheduleSave(context: context)
        }
        .onChange(of: repRange.upperRange) {
            Haptics.selection()
            scheduleSave(context: context)
        }
        .onChange(of: repRange.targetReps) {
            Haptics.selection()
            scheduleSave(context: context)
        }
        .onDisappear {
            saveContext(context: context)
        }
        .onAppear {
            suggestion = loadSuggestion()
        }
    }
    
    private var modeFooterText: String {
        switch mode {
        case .notSet:
            return "No rep goal is stored for this exercise."
        case .target:
            return "Set a single rep goal you want to acheive for each set."
        case .range:
            return "Set a rep range you want to aim for."
        case .untilFailure:
            return "Use when you plan on taking every set until failure."
        }
    }
    
    private var repGuidanceFooterText: String {
        switch mode {
        case .target:
            return "Pick one rep target that matches your goal: strength often uses a low target like 3 reps, hypertrophy is often around 10 reps, endurance is usually 15+ reps."
        case .range:
            return "Pick a rep range that matches your goal: strength usually sits around 1–3 reps, hypertrophy is often 8–12 reps, endurance is commonly 12–20+ reps."
        case .notSet, .untilFailure:
            return ""
        }
    }

    private func applySuggestion(_ suggestion: RepRangeSuggestion) {
        switch suggestion.kind {
        case .range(let lower, let upper):
            repRange.activeMode = .range
            repRange.lowerRange = lower
            repRange.upperRange = upper
        case .target(let reps):
            repRange.activeMode = .target
            repRange.targetReps = reps
        case .untilFailure:
            repRange.activeMode = .untilFailure
        }

        Haptics.selection()
        saveContext(context: context)
    }

    private func loadSuggestion() -> RepRangeSuggestion? {
        if let scoped = topSuggestion(from: collectCandidates(catalogID: catalogID)) {
            return scoped
        }
        return topSuggestion(from: collectCandidates(catalogID: nil))
    }

    private func collectCandidates(catalogID: String?) -> [RepRangeCandidate] {
        var candidates: [RepRangeCandidate] = []

        let workoutExercises = fetchWorkoutExercises(catalogID: catalogID)
        for exercise in workoutExercises {
            guard let kind = suggestionKind(from: exercise.repRange) else { continue }
            candidates.append(RepRangeCandidate(kind: kind, date: exercise.date))
        }

        return candidates
    }

    private func suggestionKind(from policy: RepRangePolicy) -> RepRangeSuggestion.Kind? {
        switch policy.activeMode {
        case .notSet:
            return nil
        case .range:
            return .range(policy.lowerRange, policy.upperRange)
        case .target:
            return .target(policy.targetReps)
        case .untilFailure:
            return .untilFailure
        }
    }

    private func topSuggestion(
        from candidates: [RepRangeCandidate],
        excluding excluded: Set<RepRangeSuggestion.Kind> = []
    ) -> RepRangeSuggestion? {
        var stats: [RepRangeSuggestion.Kind: RepRangeSuggestionStats] = [:]

        for candidate in candidates {
            guard !excluded.contains(candidate.kind) else { continue }
            if var existing = stats[candidate.kind] {
                existing.count += 1
                existing.mostRecent = max(existing.mostRecent, candidate.date)
                stats[candidate.kind] = existing
            } else {
                stats[candidate.kind] = RepRangeSuggestionStats(count: 1, mostRecent: candidate.date)
            }
        }

        return stats.map { kind, entry in
            RepRangeSuggestion(kind: kind, frequency: entry.count, mostRecent: entry.mostRecent)
        }
        .sorted {
            if $0.frequency != $1.frequency {
                return $0.frequency > $1.frequency
            }
            return $0.mostRecent > $1.mostRecent
        }
        .first
    }

    private func fetchWorkoutExercises(catalogID: String?) -> [WorkoutExercise] {
        if let catalogID {
            return (try? context.fetch(WorkoutExercise.matching(catalogID: catalogID))) ?? []
        }
        return (try? context.fetch(WorkoutExercise.completedAll)) ?? []
    }

}

private struct RepRangeCandidate {
    let kind: RepRangeSuggestion.Kind
    let date: Date
}

private struct RepRangeSuggestionStats {
    var count: Int
    var mostRecent: Date
}

private struct RepRangeSuggestion: Identifiable, Hashable {
    enum Kind: Hashable {
        case target(Int)
        case range(Int, Int)
        case untilFailure

        var id: String {
            switch self {
            case .target(let reps):
                return "target-\(reps)"
            case .range(let lower, let upper):
                return "range-\(lower)-\(upper)"
            case .untilFailure:
                return "until-failure"
            }
        }

        var title: String {
            switch self {
            case .target:
                return "Target"
            case .range:
                return "Range"
            case .untilFailure:
                return "Until Failure"
            }
        }

        var detailText: String? {
            switch self {
            case .target(let reps):
                return "\(reps) reps"
            case .range(let lower, let upper):
                return "\(lower)-\(upper) reps"
            case .untilFailure:
                return nil
            }
        }

        var accessibilityValue: String {
            switch self {
            case .target(let reps):
                return "Target \(reps) reps"
            case .range(let lower, let upper):
                return "Range \(lower) to \(upper) reps"
            case .untilFailure:
                return "Until failure"
            }
        }
    }

    let kind: Kind
    let frequency: Int
    let mostRecent: Date

    var id: String {
        kind.id
    }

    var title: String {
        kind.title
    }

    var detailText: String? {
        kind.detailText
    }

    var accessibilityValue: String {
        kind.accessibilityValue
    }
}

#Preview {
    @Previewable @State var showRestTimerSheet = false
    ExerciseView(exercise: sampleIncompleteSession().sortedExercises.first!, showRestTimerSheet: $showRestTimerSheet)
        .sampleDataContainerIncomplete()
}
