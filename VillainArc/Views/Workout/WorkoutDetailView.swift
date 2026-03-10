import SwiftUI
import SwiftData
import AppIntents

struct WorkoutDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    var router = AppRouter.shared
    let workout: WorkoutSession
    
    @State private var showDeleteWorkoutConfirmation: Bool = false
    @State private var newWorkoutPlan: WorkoutPlan?
    @State private var showPreWorkoutContextSheet = false

    private var preWorkoutFeelingText: String? {
        guard let preWorkoutContext = workout.preWorkoutContext, preWorkoutContext.feeling != .notSet else { return nil }
        return preWorkoutContext.feeling.displayName
    }

    private var hasPreWorkoutNotes: Bool {
        !(workout.preWorkoutContext?.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    private var preWorkoutNotesText: String? {
        let trimmed = workout.preWorkoutContext?.notes.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private var showsFeelingStatus: Bool {
        preWorkoutFeelingText != nil
    }

    private var postWorkoutEffortText: String? {
        guard (1...10).contains(workout.postEffort) else { return nil }
        return "\(workout.postEffort)/10 • \(workoutEffortDescription(workout.postEffort))"
    }
    
    var body: some View {
        List {
            if !workout.notes.isEmpty {
                Section("Workout Notes") {
                    Text(workout.notes)
                        .accessibilityIdentifier("workoutDetailNotesText")
                }
            }
            ForEach(workout.sortedExercises) { exercise in
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
                                Text(set.reps, format: .number)
                                    .gridColumnAlignment(.leading)
                                Spacer()
                                Text("\(set.weight, format: .number) lbs")
                                    .gridColumnAlignment(.leading)
                                Spacer()
                                Text(set.effectiveRestSeconds > 0 ? secondsToTime(set.effectiveRestSeconds) : "-")
                                    .gridColumnAlignment(.leading)
                            }
                            .font(.title3)
                            .accessibilityElement(children: .ignore)
                            .accessibilityIdentifier(AccessibilityIdentifiers.workoutDetailSet(exercise, set: set))
                            .accessibilityLabel(AccessibilityText.exerciseSetLabel(for: set))
                            .accessibilityValue(AccessibilityText.exerciseSetValue(for: set))
                        }
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(exercise.name)
                            .lineLimit(1)
                        if let repRange = exercise.repRange, repRange.activeMode != .notSet {
                            Text(repRange.displayText)
                                .font(.subheadline)
                        }
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutDetailExerciseHeader(exercise))
                } footer: {
                    if !exercise.notes.isEmpty {
                        Text("Notes: \(exercise.notes)")
                            .multilineTextAlignment(.leading)
                            .accessibilityIdentifier("workoutDetailExerciseNotes-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)")
                    }
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutDetailExercise(exercise))
            }
        }
        .accessibilityIdentifier("workoutDetailList")
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
                        .accessibilityIdentifier("workoutDetailOpenWorkoutPlanButton")
                        .accessibilityHint("Opens the linked workout plan.")
                    } else {
                        Button("Save as Workout Plan", systemImage: "list.clipboard") {
                            saveWorkoutAsPlan()
                        }
                        .accessibilityIdentifier("workoutDetailSaveWorkoutPlanButton")
                        .accessibilityHint("Saves this workout as a workout plan.")
                    }
                    Button("Delete Workout", systemImage: "trash", role: .destructive) {
                        showDeleteWorkoutConfirmation = true
                    }
                    .accessibilityIdentifier("workoutDetailDeleteButton")
                    .accessibilityHint("Deletes this workout.")
                }
                .accessibilityIdentifier("workoutDetailOptionsMenu")
                .accessibilityHint("Workout actions.")
                .confirmationDialog("Delete Workout", isPresented: $showDeleteWorkoutConfirmation) {
                    Button("Delete", role: .destructive) {
                        deleteWorkout()
                    }
                    .accessibilityIdentifier("workoutDetailConfirmDeleteButton")
                } message: {
                    Text("Are you sure you want to delete this workout?")
                }
            }
            ToolbarItemGroup(placement: .bottomBar) {
                if showsFeelingStatus {
                    preWorkoutStatusToolbarItem
                }
                if workout.preWorkoutContext?.tookPreWorkout == true {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(.yellow)
                        .accessibilityLabel("Pre-workout drink taken")
                }
            }
            ToolbarSpacer(.flexible, placement: .bottomBar)
            if postWorkoutEffortText != nil {
                ToolbarItem(placement: .bottomBar) {
                    effortRingLabel
                        .accessibilityElement(children: .ignore)
                        .accessibilityIdentifier("workoutDetailEffortDisplay")
                        .accessibilityLabel("Post workout effort")
                        .accessibilityValue(postWorkoutEffortText ?? "")
                }
            }
        }
        .fullScreenCover(item: $newWorkoutPlan) {
            WorkoutPlanView(plan: $0)
        }
        .sheet(isPresented: $showPreWorkoutContextSheet) {
            NavigationStack {
                List {
                    if let preWorkoutFeelingText {
                        LabeledContent("Pre Workout Feeling", value: preWorkoutFeelingText)
                    }
                    if workout.preWorkoutContext?.tookPreWorkout == true {
                        LabeledContent("Pre Workout", value: "Yes")
                    }
                    if let preWorkoutNotesText {
                        Section("Notes") {
                            Text(preWorkoutNotesText)
                                .multilineTextAlignment(.leading)
                        }
                    }
                }
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
            let entity = WorkoutSessionEntity(workoutSession: session)
            activity.appEntityIdentifier = .init(for: entity)
        }
    }

    private func deleteWorkout() {
        Haptics.selection()
        let deletedWorkout = workout
        SpotlightIndexer.deleteWorkoutSession(id: workout.id)
        // Collect all affected catalogIDs before deleting
        var affectedCatalogIDs = Set<String>()
        affectedCatalogIDs.formUnion((workout.exercises ?? []).map { $0.catalogID })
        context.delete(workout)
        
        // Update exercise histories for affected exercises
        // This will delete histories where no performances remain
        for catalogID in affectedCatalogIDs {
            ExerciseHistoryUpdater.updateHistory(for: catalogID, context: context)
        }

        Task { await IntentDonations.donateDeleteWorkout(workout: deletedWorkout) }
        
        dismiss()
    }

    private func saveWorkoutAsPlan() {
        guard workout.workoutPlan == nil else { return }
        Haptics.selection()
        let plan = WorkoutPlan(from: workout)
        context.insert(plan)
        workout.workoutPlan = plan
        saveContext(context: context)
        newWorkoutPlan = plan
    }

    private func openWorkoutPlan(_ plan: WorkoutPlan) {
        Haptics.selection()
        router.popToRoot()
        router.navigate(to: .workoutPlanDetail(plan, false))
        Task { await IntentDonations.donateOpenWorkoutPlan(workoutPlan: plan) }
    }

    @ViewBuilder
    private var preWorkoutStatusToolbarItem: some View {
        if hasPreWorkoutNotes {
            Button {
                showPreWorkoutContextSheet = true
            } label: {
                preWorkoutStatusLabel
            }
            .accessibilityIdentifier("workoutDetailPreWorkoutContextButton")
            .accessibilityLabel("Pre workout context")
            .accessibilityValue(preWorkoutAccessibilityValue)
            .accessibilityHint("Shows pre workout details.")
        } else {
            preWorkoutStatusLabel
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("workoutDetailPreWorkoutContextDisplay")
                .accessibilityLabel("Pre workout context")
                .accessibilityValue(preWorkoutAccessibilityValue)
        }
    }

    private var preWorkoutStatusLabel: some View {
        Group {
            if let feeling = workout.preWorkoutContext?.feeling, feeling != .notSet {
                Text(feeling.emoji)
                    .font(.title)
                    .frame(width: 28, height: 28)
            }
        }
    }

    private var effortRingLabel: some View {
        let effortColor = effortRingColor

        return ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 3)
            Circle()
                .trim(from: 0, to: CGFloat(workout.postEffort) / 10)
                .stroke(effortColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(workout.postEffort)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(effortColor)
        }
        .frame(width: 28, height: 28)
    }

    private var effortRingColor: Color {
        switch workout.postEffort {
        case 1...3: .green
        case 4...6: .yellow
        case 7...8: .orange
        case 9...10: .red
        default: .primary
        }
    }

    private var preWorkoutAccessibilityValue: String {
        let feeling = preWorkoutFeelingText ?? "Not set"
        let tookPreWorkout = workout.preWorkoutContext?.tookPreWorkout == true ? "Pre workout taken" : "No pre workout"
        return "\(feeling). \(tookPreWorkout)."
    }

    private func setIndicator(for set: SetPerformance) -> some View {
        Text(set.type == .working ? String(set.index + 1) : set.type.shortLabel)
            .foregroundStyle(set.type.tintColor)
            .overlay(alignment: .bottomTrailing) {
                if let visibleRPE = set.visibleRPE {
                    RPEBadge(value: visibleRPE)
                        .offset(x: 8, y: 5)
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
